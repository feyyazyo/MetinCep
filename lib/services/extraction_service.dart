import 'package:flutter/foundation.dart';

import '../core/errors/app_exception.dart';
import '../core/utils/cancellation_token.dart';
import '../core/utils/text_layout_formatter.dart';
import '../models/extraction_models.dart';
import 'ocr_service.dart';
import 'pdf_service.dart';

/// Tüm metin çıkarma işlerinin tek giriş noktası.
/// V2'de özetleme / çeviri / fatura bilgisi çıkarma gibi adımlar
/// sonucu işleyen ayrı servisler olarak buraya eklenebilir.
class ExtractionService {
  ExtractionService({required OcrService ocr, required PdfService pdf})
      : _ocr = ocr,
        _pdf = pdf;

  final OcrService _ocr;
  final PdfService _pdf;

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
    onProgress(ExtractionProgress(completed: 0, total: total, unit: ProgressUnit.image));

    for (var index = 0; index < total; index++) {
      cancellationToken.throwIfCancelled();
      try {
        sections.add(await _ocr.recognizeFile(paths[index]));
      } catch (error) {
        debugPrint('Görsel ${index + 1} okunamadı: $error');
        sections.add('');
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
      source: request.source,
      unitCount: total,
      ocrUnitCount: total,
    );
  }
}
