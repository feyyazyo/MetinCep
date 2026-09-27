import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../core/errors/app_exception.dart';
import '../core/utils/cancellation_token.dart';
import '../core/utils/table_line_finder.dart';
import '../core/utils/text_layout_formatter.dart';
import '../models/extraction_models.dart';
import '../models/ocr_mode.dart';
import '../models/ocr_table.dart';
import '../models/table_grid_lines.dart';
import 'image_preprocessor.dart';
import 'ocr_pipeline.dart';
import 'ocr_service.dart';
import 'pdf_service.dart';

/// Tüm metin çıkarma işlerinin tek giriş noktası.
///
/// Boru hattı:
/// GÖRÜNTÜ → (el yazısı modunda) ÖN İŞLEME → OCR → (el yazısı zayıfsa ikinci
/// geçiş) → KARAKTER NORMALİZASYONU → TABLO ÇİZGİSİ ARAMA → TABLO ALGILAMA
/// → SONUÇ
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
    var tableNearMiss = false;

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

        var page = await _ocr.recognizeFile(recognizedPath);
        var usedSecondPass = false;

        // El yazısında ilk geçiş zayıf kaldıysa ikili (siyah-beyaz) sürümü dene.
        if (request.mode == OcrMode.handwriting && _isWeak(page)) {
          cancellationToken.throwIfCancelled();
          final second = await _secondPass(
            recognizedPath,
            index,
            alreadyEnhanced: preparedFile != null,
          );
          if (second != null) {
            try {
              final retry = await _ocr.recognizeFile(second.path);
              if (_isBetter(retry, page)) {
                page = retry;
                usedSecondPass = true;
              }
            } finally {
              await _deleteQuietly(second);
            }
          }
        }

        // Tablo çizgileri: yalnızca yeterli kelime varsa aranır (maliyet).
        // İkinci geçiş kullanıldıysa aranmaz: kelime koordinatları ikili
        // görüntüye aittir ve elimizdeki dosyayla birebir örtüştüğü garanti
        // değildir. Yanlış hizalanmış çizgi ipucu, hiç ipucu olmamasından kötüdür.
        final gridLines =
            usedSecondPass ? null : await _findGridLines(recognizedPath, page);
        cancellationToken.throwIfCancelled();

        final processed = _pipeline.process(page, gridLines: gridLines);
        sections.add(processed.text);
        rawSections.add(processed.rawText);
        normalizationCount += processed.normalizationCount;
        tableNearMiss = tableNearMiss || processed.tableNearMiss;
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
      tableNearMiss: tableNearMiss && tables.isEmpty,
    );
  }

  /// OCR sonucu zayıf mı (el yazısında ikinci geçişe değer mi).
  static bool _isWeak(OcrPage page) {
    if (page.rawText.trim().length < 12) {
      return true;
    }
    final confidence = page.averageConfidence;
    return confidence != null && confidence < 0.5;
  }

  /// İkinci geçiş daha iyi mi: belirgin şekilde daha çok metin ya da aynı
  /// uzunlukta daha yüksek güven. Eşitlikte ilk sonuç korunur.
  static bool _isBetter(OcrPage candidate, OcrPage current) {
    final candidateLength = candidate.rawText.trim().length;
    final currentLength = current.rawText.trim().length;
    if (candidateLength > currentLength * 1.2) {
      return true;
    }
    if (candidateLength < currentLength) {
      return false;
    }
    final candidateConfidence = candidate.averageConfidence;
    final currentConfidence = current.averageConfidence;
    if (candidateConfidence == null || currentConfidence == null) {
      return candidateLength > currentLength;
    }
    return candidateConfidence > currentConfidence;
  }

  /// İkili (siyah-beyaz) ikinci geçiş dosyası. Başarısızsa null.
  ///
  /// [alreadyEnhanced] true ise kaynak zaten el yazısı profilinden geçmiştir;
  /// yalnızca gürültü azaltma + eşikleme uygulanır (iyileştirme iki kez
  /// çalıştırılmaz).
  Future<File?> _secondPass(
    String sourcePath,
    int index, {
    required bool alreadyEnhanced,
  }) async {
    try {
      final directory = await _temporaryDirectoryProvider();
      final target = '${directory.path}${Platform.pathSeparator}'
          'metincep_bin_${DateTime.now().microsecondsSinceEpoch}_$index.jpg';
      final result = await _preprocessor.prepareBinary(
        sourcePath: sourcePath,
        targetPath: target,
        alreadyEnhanced: alreadyEnhanced,
      );
      return result == null ? null : File(result);
    } catch (error) {
      debugPrint('İkinci geçiş hazırlanamadı: $error');
      return null;
    }
  }

  /// Fotoğraftaki tablo çizgilerini arar (arka plan isolate'inde).
  /// Çizgi yoksa veya hata olursa null döner; tablo yine geometriyle aranır.
  Future<TableGridLines?> _findGridLines(String imagePath, OcrPage page) async {
    final words = page.lines.expand((line) => line.words).toList();
    if (words.length < 6) {
      return null; // Tablo için yeterli kelime yok: çizgi aramaya değmez.
    }
    var left = double.infinity;
    var top = double.infinity;
    var right = -double.infinity;
    var bottom = -double.infinity;
    for (final word in words) {
      left = math.min(left, word.left);
      top = math.min(top, word.top);
      right = math.max(right, word.right);
      bottom = math.max(bottom, word.bottom);
    }
    if (!left.isFinite || !top.isFinite || right - left <= 0 || bottom - top <= 0) {
      return null;
    }
    try {
      final lines = await compute(
        findGridLinesInIsolate,
        GridLineRequest(
          imagePath: imagePath,
          left: left,
          top: top,
          right: right,
          bottom: bottom,
        ),
      );
      return lines.isEmpty ? null : lines;
    } catch (error) {
      debugPrint('Tablo çizgileri aranamadı: $error');
      return null;
    }
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

/// Tablo çizgisi arama isteği (isolate'e kopyalanır: yalnızca ilkel alanlar).
class GridLineRequest {
  const GridLineRequest({
    required this.imagePath,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  final String imagePath;
  final double left;
  final double top;
  final double right;
  final double bottom;
}

/// Isolate içinde çalışan üst düzey fonksiyon (compute için zorunlu).
TableGridLines findGridLinesInIsolate(GridLineRequest request) =>
    TableLineFinder.find(
      imagePath: request.imagePath,
      regionLeft: request.left,
      regionTop: request.top,
      regionRight: request.right,
      regionBottom: request.bottom,
    );
