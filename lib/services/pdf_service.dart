import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';

import '../core/constants/app_constants.dart';
import '../core/errors/app_exception.dart';
import '../core/utils/cancellation_token.dart';
import '../core/utils/file_name_utils.dart';
import '../core/utils/pdf_render_sizing.dart';
import '../core/utils/text_layout_formatter.dart';
import '../models/document_model.dart';
import '../models/extraction_models.dart';
import 'ocr_service.dart';

/// PDF'den metin çıkarma:
/// 1) Her sayfada önce metin katmanı okunur (hızlı, OCR'suz, birebir doğru).
/// 2) Metin katmanı yoksa/yetersizse sayfa görüntüye çevrilip OCR'dan geçirilir.
/// Sayfalar tek tek işlenir; bütün sayfalar aynı anda RAM'e alınmaz.
class PdfService {
  PdfService({required OcrService ocr}) : _ocr = ocr;

  final OcrService _ocr;

  Future<ExtractionResult> extract({
    required PdfExtractionRequest request,
    required CancellationToken cancellationToken,
    required void Function(ExtractionProgress progress) onProgress,
    PageLimitResolver? onPageLimitExceeded,
  }) async {
    if (!await _looksLikePdf(request.pdfPath)) {
      throw const AppException(ErrorMessages.pdfOpenFailed);
    }

    final document = await _openDocument(request.pdfPath);
    try {
      final pages = document.pages;
      final pageCount = pages.length;
      if (pageCount == 0) {
        throw const AppException(ErrorMessages.pdfOpenFailed);
      }

      var total = pageCount;
      final maxPages = request.maxPages;
      if (maxPages != null && pageCount > maxPages) {
        final decision = onPageLimitExceeded == null
            ? PageLimitDecision.processFirstPages
            : await onPageLimitExceeded(pageCount, maxPages);
        cancellationToken.throwIfCancelled();
        switch (decision) {
          case PageLimitDecision.cancel:
            throw const OperationCancelledException();
          case PageLimitDecision.processFirstPages:
            total = maxPages;
          case PageLimitDecision.processAll:
            total = pageCount;
        }
      }

      onProgress(ExtractionProgress(completed: 0, total: total, unit: ProgressUnit.page));
      final tempDirectory = await getTemporaryDirectory();
      final sections = <String>[];
      var ocrPageCount = 0;

      for (var index = 0; index < total; index++) {
        cancellationToken.throwIfCancelled();
        final page = pages[index];

        var pageText = TextLayoutFormatter.normalize(await _readTextLayer(page));

        if (TextLayoutFormatter.visibleCharCount(pageText) <
            AppConstants.minTextLayerChars) {
          onProgress(
            ExtractionProgress(
              completed: index,
              total: total,
              unit: ProgressUnit.page,
              detail: 'Sayfa ${index + 1} görüntü olarak okunuyor…',
            ),
          );
          final ocrText = await _recognizePage(
            page: page,
            pageIndex: index,
            tempDirectory: tempDirectory,
            cancellationToken: cancellationToken,
          );
          ocrPageCount++;
          if (TextLayoutFormatter.visibleCharCount(ocrText) >
              TextLayoutFormatter.visibleCharCount(pageText)) {
            pageText = ocrText;
          }
        }

        sections.add(pageText);
        onProgress(
          ExtractionProgress(completed: index + 1, total: total, unit: ProgressUnit.page),
        );
      }

      cancellationToken.throwIfCancelled();
      if (sections.every((section) => section.trim().isEmpty)) {
        throw const AppException(ErrorMessages.noTextInPdf);
      }

      return ExtractionResult(
        text: TextLayoutFormatter.joinSections(sections: sections, label: 'Sayfa'),
        source: DocumentSource.pdf,
        suggestedTitle: FileNameUtils.withoutExtension(request.fileName),
        unitCount: total,
        ocrUnitCount: ocrPageCount,
        sourcePageCount: pageCount,
      );
    } finally {
      try {
        await document.dispose();
      } catch (error) {
        debugPrint('PDF kapatılırken hata: $error');
      }
    }
  }

  Future<PdfDocument> _openDocument(String path) async {
    try {
      return await PdfDocument.openFile(path);
    } on PdfPasswordException catch (error) {
      debugPrint('Şifreli PDF: $error');
      throw const AppException(ErrorMessages.pdfPasswordProtected);
    } catch (error) {
      debugPrint('PDF açılamadı: $error');
      throw const AppException(ErrorMessages.pdfOpenFailed);
    }
  }

  Future<String> _readTextLayer(PdfPage page) async {
    try {
      final pageText = await page.loadText();
      return pageText.fullText;
    } catch (error) {
      debugPrint('Sayfa ${page.pageNumber} metin katmanı okunamadı: $error');
      return '';
    }
  }

  Future<String> _recognizePage({
    required PdfPage page,
    required int pageIndex,
    required Directory tempDirectory,
    required CancellationToken cancellationToken,
  }) async {
    final imageFile = File(
      '${tempDirectory.path}${Platform.pathSeparator}'
      'metincep_page_${DateTime.now().microsecondsSinceEpoch}_$pageIndex.png',
    );
    try {
      final pngBytes = await _renderPageToPng(page);
      if (pngBytes == null) {
        return '';
      }
      cancellationToken.throwIfCancelled();
      await imageFile.writeAsBytes(pngBytes);
      return await _ocr.recognizeFile(imageFile.path);
    } on OperationCancelledException {
      rethrow;
    } catch (error) {
      debugPrint('Sayfa ${pageIndex + 1} OCR hatası: $error');
      return '';
    } finally {
      await _deleteQuietly(imageFile);
    }
  }

  Future<Uint8List?> _renderPageToPng(PdfPage page) async {
    final size = PdfRenderSizing.forPage(page.width, page.height);
    final PdfImage? rendered = await page.render(
      width: size.width,
      height: size.height,
      fullWidth: size.width.toDouble(),
      fullHeight: size.height.toDouble(),
      backgroundColor: const ui.Color(0xFFFFFFFF),
    );
    if (rendered == null) {
      return null;
    }
    try {
      return await _encodePng(
        rendered.pixels,
        rendered.width,
        rendered.height,
        rendered.format,
      );
    } finally {
      rendered.dispose();
    }
  }

  /// PDFium ham piksel verisini PNG'ye çevirir (ML Kit dosya yolundan okur).
  /// Piksel formatı (Android'de BGRA) pdfrx'in bildirdiği değerden alınır.
  Future<Uint8List> _encodePng(
    Uint8List pixels,
    int width,
    int height,
    ui.PixelFormat format,
  ) async {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      pixels,
      width,
      height,
      format,
      (image) => completer.complete(image),
    );
    final image = await completer.future;
    try {
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw const AppException(ErrorMessages.noTextInPdf);
      }
      return byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes);
    } finally {
      image.dispose();
    }
  }

  Future<bool> _looksLikePdf(String path) async {
    RandomAccessFile? handle;
    try {
      final file = File(path);
      if (!await file.exists()) {
        return false;
      }
      handle = await file.open();
      final header = await handle.read(1024);
      return String.fromCharCodes(header).contains('%PDF');
    } catch (error) {
      debugPrint('PDF başlığı okunamadı: $error');
      return false;
    } finally {
      await handle?.close();
    }
  }

  Future<void> _deleteQuietly(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (error) {
      debugPrint('Geçici dosya silinemedi: $error');
    }
  }
}
