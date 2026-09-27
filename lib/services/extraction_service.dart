import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../core/errors/app_exception.dart';
import '../core/utils/cancellation_token.dart';
import '../core/utils/text_layout_formatter.dart';
import '../models/extraction_models.dart';
import '../models/ocr_mode.dart';
import '../models/ocr_table.dart';
import 'image_preprocessor.dart';
import 'ocr_pipeline.dart';
import 'ocr_service.dart';
import 'pdf_service.dart';

/// Tüm metin çıkarma işlerinin tek giriş noktası.
///
/// Boru hattı:
/// GÖRÜNTÜ → (el yazısı modunda) ÖN İŞLEME → OCR → KARAKTER NORMALİZASYONU
/// → TABLO ALGILAMA → SONUÇ
///
/// Bu servis Free/Pro kurallarını bilmez; sınırlar akışın başında uygulanır.
class ExtractionService {
  ExtractionService({
    required OcrService ocr,
    required PdfService pdf,
    OcrPipeline pipeline = const OcrPipeline(),
    ImagePreprocessor preprocessor = const ImagePreprocessor(),
    Future<Directory> Function()? temporaryDirectoryProvider,
  })  : _ocr = ocr,
        _pdf = pdf,
        _pipeline = pipeline,
        _preprocessor = preprocessor,
        _temporaryDirectoryProvider =
            temporaryDirectoryProvider ?? getTemporaryDirectory;

  final OcrService _ocr;
  final PdfService _pdf;
  final OcrPipeline _pipeline;
  final ImagePreprocessor _preprocessor;
  final Future<Directory> Function() _temporaryDirectoryProvider;

  Future<ExtractionResult> run(
    ExtractionRequest request, {
    required CancellationToken cancellationToken,
    required void Function(ExtractionProgress progress) onProgress,
    PageLimitResolver? onPageLimitExceeded,
  }) async {
    if (request is PdfExtractionRequest) {
      return _pdf.extract(
        request: request,
        cancellationToken: cancellationToken,
        onProgress: onProgress,
        onPageLimitExceeded: onPageLimitExceeded,
      );
    }
    if (request is ImageExtractionRequest) {
      return _extractImages(request, cancellationToken, onProgress);
    }
    throw const AppException(ErrorMessages.noTextInImage);
  }

  Future<ExtractionResult> _extractImages(
    ImageExtractionRequest request,
    CancellationToken cancellationToken,
    void Function(ExtractionProgress progress) onProgress,
  ) async {
    final paths = request.imagePaths;
    if (paths.isEmpty) {
      throw const AppException(ErrorMessages.noTextInImage);
    }

    final total = paths.length;
    final sections = <String>[];
    final rawSections = <String>[];
    final tables = <OcrTable>[];
    var normalizationCount = 0;

    onProgress(ExtractionProgress(completed: 0, total: total, unit: ProgressUnit.image));

    for (var index = 0; index < total; index++) {
      cancellationToken.throwIfCancelled();
      if (request.mode == OcrMode.handwriting) {
        onProgress(
          ExtractionProgress(
            completed: index,
            total: total,
            unit: ProgressUnit.image,
            detail: 'El yazısı için görüntü hazırlanıyor…',
          ),
        );
      }

      var recognizedPath = paths[index];
      File? preparedFile;
      try {
        final prepared = await _prepare(paths[index], index, request.mode);
        if (prepared != null) {
          preparedFile = File(prepared);
          recognizedPath = prepared;
        }
        cancellationToken.throwIfCancelled();

        final page = await _ocr.recognizeFile(recognizedPath);
        final processed = _pipeline.process(page);
        sections.add(processed.text);
        rawSections.add(processed.rawText);
        normalizationCount += processed.normalizationCount;
        final table = processed.table;
        if (table != null) {
          tables.add(table);
        }
      } on OperationCancelledException {
        rethrow;
      } catch (error) {
        debugPrint('Görsel ${index + 1} okunamadı: $error');
        sections.add('');
        rawSections.add('');
      } finally {
        // Ön işleme çıktısı geçicidir; OCR bittiğinde hemen silinir.
        await _deleteQuietly(preparedFile);
      }

      onProgress(
        ExtractionProgress(completed: index + 1, total: total, unit: ProgressUnit.image),
      );
    }

    cancellationToken.throwIfCancelled();
    if (sections.every((section) => section.trim().isEmpty)) {
      throw const AppException(ErrorMessages.noTextInImage);
    }

    return ExtractionResult(
      text: TextLayoutFormatter.joinSections(sections: sections, label: 'Görsel'),
      rawText: TextLayoutFormatter.joinSections(sections: rawSections, label: 'Görsel'),
      source: request.source,
      unitCount: total,
      ocrUnitCount: total,
      tables: tables,
      normalizationCount: normalizationCount,
    );
  }

  /// El yazısı modunda görüntüyü hazırlar. Hata olursa null döner ve orijinal kullanılır.
  Future<String?> _prepare(String sourcePath, int index, OcrMode mode) async {
    if (mode != OcrMode.handwriting) {
      return null;
    }
    try {
      final directory = await _temporaryDirectoryProvider();
      final target = '${directory.path}${Platform.pathSeparator}'
          'metincep_pre_${DateTime.now().microsecondsSinceEpoch}_$index.jpg';
      return await _preprocessor.prepare(
        sourcePath: sourcePath,
        targetPath: target,
        mode: mode,
      );
    } catch (error) {
      debugPrint('Ön işleme atlandı: $error');
      return null;
    }
  }

  Future<void> _deleteQuietly(File? file) async {
    if (file == null) {
      return;
    }
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (error) {
      debugPrint('Geçici ön işleme dosyası silinemedi: $error');
    }
  }
}
