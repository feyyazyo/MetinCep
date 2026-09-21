import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/errors/app_exception.dart';
import '../../core/utils/ui_helpers.dart';
import '../../models/document_model.dart';
import '../../models/extraction_models.dart';
import '../../services/feature_access_service.dart';
import '../../services/source_picker_service.dart';
import '../pro/limit_dialog.dart';
import '../pro/pro_screen.dart';
import '../result/result_screen.dart';
import 'processing_screen.dart';

/// Kamera / galeri / PDF akışlarını başlatan yardımcı.
///
/// Free / Pro sınırları YALNIZCA burada (işlem başlamadan önce) uygulanır:
/// - kamera veya seçici açılmadan önce günlük hak kontrol edilir,
/// - seçimden sonra fotoğraf sayısı ve PDF boyutu kontrol edilir,
/// - PDF sayfa sınırı işlem ekranına nötr bir parametre olarak geçirilir.
/// OCR ve PDF servisleri Free / Pro kavramını bilmez.
class ExtractionFlow {
  ExtractionFlow._();

  /// Hızlı çift dokunuşta iki akışın (iki pencere / iki seçici) birden açılmasını engeller.
  static bool _flowBusy = false;

  static Future<void> startCamera(BuildContext context) async {
    if (_flowBusy) {
      return;
    }
    _flowBusy = true;
    String? path;
    try {
      if (!await _ensureAllowed(
        context,
        isAllowed: (access) => access.canUseOcr(),
        prompt: (_) => LimitPrompt.dailyOcr(),
      )) {
        return;
      }
      if (!context.mounted) {
        return;
      }
      path = await AppScope.of(context).picker.captureFromCamera();
    } on AppException catch (error) {
      if (context.mounted) {
        showAppSnackBar(context, error.message);
      }
    } finally {
      _flowBusy = false;
    }

    if (path != null && context.mounted) {
      await _pushImages(context, [path], DocumentSource.camera);
    }
  }

  static Future<void> startGallery(BuildContext context) async {
    if (_flowBusy) {
      return;
    }
    _flowBusy = true;
    List<String>? paths;
    try {
      if (!await _ensureAllowed(
        context,
        isAllowed: (access) => access.canUseOcr(),
        prompt: (_) => LimitPrompt.dailyOcr(),
      )) {
        return;
      }
      if (!context.mounted) {
        return;
      }
      final picked = await AppScope.of(context).picker.pickFromGallery();
      if (picked.isEmpty || !context.mounted) {
        return;
      }
      paths = await _applyBatchLimit(context, picked);
    } on AppException catch (error) {
      if (context.mounted) {
        showAppSnackBar(context, error.message);
      }
    } finally {
      _flowBusy = false;
    }

    if (paths != null && paths.isNotEmpty && context.mounted) {
      await _pushImages(context, paths, DocumentSource.gallery);
    }
  }

  static Future<void> startPdf(BuildContext context) async {
    if (_flowBusy) {
      return;
    }
    _flowBusy = true;
    PickedPdf? picked;
    try {
      if (!await _ensureAllowed(
        context,
        isAllowed: (access) => access.canProcessPdf(),
        prompt: (_) => LimitPrompt.dailyPdf(),
      )) {
        return;
      }
      if (!context.mounted) {
        return;
      }
      final services = AppScope.of(context);
      final candidate = await services.picker.pickPdf();
      if (candidate == null || !context.mounted) {
        return;
      }
      final sizeAllowed = await _ensureAllowed(
        context,
        isAllowed: (access) => access.canOpenPdfFile(candidate.sizeBytes),
        prompt: (access) => LimitPrompt.pdfFileSize(
          sizeBytes: candidate.sizeBytes,
          maxBytes: access.limits.maxPdfFileSizeBytes ?? candidate.sizeBytes,
        ),
      );
      if (sizeAllowed) {
        picked = candidate;
      } else {
        await services.picker.discardTemporaryCopies([candidate.path]);
      }
    } on AppException catch (error) {
      if (context.mounted) {
        showAppSnackBar(context, error.message);
      }
    } finally {
      _flowBusy = false;
    }

    if (picked == null || !context.mounted) {
      return;
    }
    // Sayfa sınırı o anki plana göre verilir; aşılırsa işlem ekranı kullanıcıya sorar.
    final maxPages = AppScope.of(context).access.limits.maxPdfPages;
    await _push(
      context,
      ProcessingScreen(
        request: PdfExtractionRequest(
          pdfPath: picked.path,
          fileName: picked.name,
          maxPages: maxPages,
        ),
      ),
    );
  }

  /// Uygulama dışından gelen fotoğraflar için (ör. düşük RAM'de kamera sonrası kurtarma).
  static Future<void> processImages(
    BuildContext context,
    List<String> paths,
    DocumentSource source,
  ) async {
    if (paths.isEmpty || _flowBusy) {
      return;
    }
    _flowBusy = true;
    List<String>? allowed;
    try {
      final picker = AppScope.of(context).picker;
      final canStart = await _ensureAllowed(
        context,
        isAllowed: (access) => access.canUseOcr(),
        prompt: (_) => LimitPrompt.dailyOcr(),
      );
      if (!canStart) {
        await picker.discardTemporaryCopies(paths);
        return;
      }
      if (!context.mounted) {
        return;
      }
      allowed = await _applyBatchLimit(context, paths);
    } finally {
      _flowBusy = false;
    }

    if (allowed != null && allowed.isNotEmpty && context.mounted) {
      await _pushImages(context, allowed, source);
    }
  }

  static Future<void> openDocument(BuildContext context, DocumentModel document) {
    return _push(context, ResultScreen.fromDocument(document: document));
  }

  static Future<void> _pushImages(
    BuildContext context,
    List<String> paths,
    DocumentSource source,
  ) {
    return _push(
      context,
      ProcessingScreen(
        request: ImageExtractionRequest(imagePaths: paths, source: source),
      ),
    );
  }

  static Future<void> _push(BuildContext context, Widget screen) {
    return Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  /// Erişim yoksa sınır penceresini gösterir. Kullanıcı Pro ekranından döndüğünde
  /// erişim yeniden kontrol edilir (ör. Pro olduysa işlem devam eder).
  static Future<bool> _ensureAllowed(
    BuildContext context, {
    required bool Function(FeatureAccessService access) isAllowed,
    required LimitPrompt Function(FeatureAccessService access) prompt,
  }) async {
    final access = AppScope.of(context).access;
    if (isAllowed(access)) {
      return true;
    }
    final choice = await showLimitDialog(context, prompt(access));
    if (choice != LimitChoice.viewPro || !context.mounted) {
      return false;
    }
    await ProScreen.open(context);
    return context.mounted && isAllowed(access);
  }

  /// Seçilen fotoğraf sayısı plan sınırını aşıyorsa kullanıcıya sorar.
  /// İptalde null döner; işlenmeyecek fotoğrafların geçici kopyaları silinir.
  static Future<List<String>?> _applyBatchLimit(
    BuildContext context,
    List<String> paths,
  ) async {
    final services = AppScope.of(context);
    final access = services.access;
    if (access.canUseBatchOcr(paths.length)) {
      return paths;
    }

    final maxImages = access.limits.maxImagesPerBatch ?? paths.length;
    final choice = await showLimitDialog(
      context,
      LimitPrompt.batch(selectedCount: paths.length, maxImages: maxImages),
    );

    switch (choice) {
      case LimitChoice.continueWithinLimit:
        await services.picker.discardTemporaryCopies(paths.sublist(maxImages));
        return paths.sublist(0, maxImages);
      case LimitChoice.viewPro:
        if (context.mounted) {
          await ProScreen.open(context);
          if (context.mounted && access.canUseBatchOcr(paths.length)) {
            return paths;
          }
        }
      case LimitChoice.cancel:
        break;
    }
    await services.picker.discardTemporaryCopies(paths);
    return null;
  }
}
