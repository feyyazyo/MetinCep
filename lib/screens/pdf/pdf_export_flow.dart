import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/errors/app_exception.dart';
import '../../core/utils/ui_helpers.dart';
import '../../models/ocr_table.dart';
import '../../models/searchable_page.dart';
import '../../services/pdf_export_service.dart';
import '../../services/share_service.dart';
import '../pro/access_gate.dart';
import '../pro/limit_dialog.dart';

/// PDF çıktısı akışı: kota kontrolü → oluştur → kaydet / paylaş.
///
/// Kota YALNIZCA PDF başarıyla oluşturulduktan sonra harcanır; hata, boş içerik
/// veya kullanıcı iptalinde harcanmaz. Sınırlar burada uygulanır; PdfExportService
/// Free/Pro kavramını bilmez.
class PdfExportFlow {
  PdfExportFlow._();

  static bool _busy = false;

  /// Düzenlenmiş metni PDF'e aktarır.
  static Future<void> exportText(
    BuildContext context, {
    required String title,
    required String text,
  }) {
    if (text.trim().isEmpty) {
      showAppSnackBar(context, ErrorMessages.pdfEmptyContent);
      return Future<void>.value();
    }
    final service = AppScope.of(context).pdfExport;
    return _run(
      context,
      fileName: PdfExportService.suggestedFileName(title),
      build: () => service.buildTextPdf(title: title, text: text),
    );
  }

  /// Algılanan tabloyu gerçek PDF tablosu olarak aktarır.
  static Future<void> exportTable(
    BuildContext context, {
    required String title,
    required OcrTable table,
  }) {
    final service = AppScope.of(context).pdfExport;
    return _run(
      context,
      fileName: PdfExportService.suggestedFileName(title),
      build: () => service.buildTablePdf(title: title, table: table),
    );
  }

  /// **Aranabilir PDF:** fotoğraf olduğu gibi kalır, üzerine görünmez ama
  /// seçilebilir metin katmanı eklenir.
  static Future<void> exportSearchable(
    BuildContext context, {
    required String title,
    required List<SearchablePage> pages,
  }) {
    if (pages.isEmpty) {
      showAppSnackBar(context, ErrorMessages.pdfEmptyContent);
      return Future<void>.value();
    }
    final service = AppScope.of(context).pdfExport;
    return _run(
      context,
      fileName: PdfExportService.suggestedFileName(title),
      build: () => service.buildSearchablePdf(pages: pages, title: title),
    );
  }

  /// Galeriden seçilen fotoğrafları tek PDF'e aktarır (her fotoğraf bir sayfa).
  static Future<void> exportImagesFromGallery(BuildContext context) async {
    if (_busy) {
      return;
    }
    _busy = true;
    List<String> paths = const [];
    try {
      final allowed = await ensureAccess(
        context,
        isAllowed: (access) => access.canExportPdf(),
        prompt: (_) => LimitPrompt.dailyPdfExport(),
      );
      if (!allowed || !context.mounted) {
        return;
      }
      paths = await AppScope.of(context).picker.pickFromGallery();
    } on AppException catch (error) {
      if (context.mounted) {
        showAppSnackBar(context, error.message);
      }
      return;
    } finally {
      _busy = false;
    }

    if (paths.isEmpty || !context.mounted) {
      return;
    }

    final services = AppScope.of(context);
    await _run(
      context,
      fileName: PdfExportService.suggestedFileName('Fotoğraflar'),
      skipAccessCheck: true,
      build: () => services.pdfExport.buildImagesPdf(imagePaths: paths),
    );
    // Seçicinin önbelleğe aldığı kopyalar artık gerekmez.
    await services.picker.discardTemporaryCopies(paths);
  }

  static Future<void> _run(
    BuildContext context, {
    required String fileName,
    required Future<PdfBytes> Function() build,
    bool skipAccessCheck = false,
  }) async {
    if (_busy) {
      return;
    }
    _busy = true;
    try {
      if (!skipAccessCheck) {
        final allowed = await ensureAccess(
          context,
          isAllowed: (access) => access.canExportPdf(),
          prompt: (_) => LimitPrompt.dailyPdfExport(),
        );
        if (!allowed || !context.mounted) {
          return;
        }
      }

      _showProgress(context);
      // İçteki try yalnızca ilerleme penceresini kapatmak için; hata yukarıya
      // gider. Bu yüzden aşağıya ancak PDF gerçekten oluştuysa geçilir.
      final PdfBytes bytes;
      try {
        bytes = await build();
      } finally {
        if (context.mounted) {
          Navigator.of(context, rootNavigator: true).pop();
        }
      }

      if (!context.mounted) {
        return;
      }
      // PDF gerçekten oluştu: kota burada harcanır.
      final services = AppScope.of(context);
      await services.access.recordCompletedPdfExport();
      if (!context.mounted) {
        return;
      }
      await _offerSaveOrShare(context, bytes: bytes, fileName: fileName);
    } on AppException catch (error) {
      if (context.mounted) {
        showAppSnackBar(context, error.message);
      }
    } catch (error) {
      debugPrint('PDF oluşturulamadı: $error');
      if (context.mounted) {
        showAppSnackBar(context, ErrorMessages.pdfCreateFailed);
      }
    } finally {
      _busy = false;
    }
  }

  static void _showProgress(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
            SizedBox(width: 16),
            Expanded(child: Text('PDF oluşturuluyor…')),
          ],
        ),
      ),
    );
  }

  static Future<void> _offerSaveOrShare(
    BuildContext context, {
    required PdfBytes bytes,
    required String fileName,
  }) async {
    final action = await showModalBottomSheet<_PdfAction>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 18, 20, 6),
              child: Text('PDF hazır', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
            ListTile(
              leading: const Icon(Icons.save_alt),
              title: const Text('Cihaza kaydet'),
              onTap: () => Navigator.of(sheetContext).pop(_PdfAction.save),
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: const Text('Paylaş'),
              onTap: () => Navigator.of(sheetContext).pop(_PdfAction.share),
            ),
          ],
        ),
      ),
    );

    if (action == null || !context.mounted) {
      return;
    }

    final services = AppScope.of(context);
    try {
      switch (action) {
        case _PdfAction.save:
          final outcome = await services.share.saveBytes(
            bytes,
            fileName: fileName,
            extension: 'pdf',
            dialogTitle: 'PDF olarak kaydet',
          );
          if (context.mounted && outcome == TxtSaveOutcome.saved) {
            showAppSnackBar(context, 'PDF kaydedildi.');
          }
        case _PdfAction.share:
          final file = await services.pdfExport
              .writeTemporaryFile(bytes, fileName: fileName);
          await services.share.shareFile(
            File(file.path),
            mimeType: 'application/pdf',
            subject: fileName,
          );
      }
    } on AppException catch (error) {
      if (context.mounted) {
        showAppSnackBar(context, error.message);
      }
    } catch (error) {
      debugPrint('PDF kaydedilemedi/paylaşılamadı: $error');
      if (context.mounted) {
        showAppSnackBar(context, ErrorMessages.pdfCreateFailed);
      }
    }
  }
}

enum _PdfAction { save, share }
