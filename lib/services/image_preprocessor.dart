import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../core/constants/app_constants.dart';
import '../core/utils/image_decoding.dart';
import '../models/ocr_mode.dart';

/// El yazısı için görüntü ön işleme. Saf (platformsuz) olduğu için test edilebilir.
class ImagePreprocessor {
  const ImagePreprocessor();

  /// Eğiklik taramasında denenen en büyük açı (derece).
  static const double maxSkewDegrees = 4;

  /// Eğiklik taraması adımı (derece).
  static const double skewStepDegrees = 0.5;

  /// Bu açının altındaki eğiklik için döndürme yapılmaz (gereksiz kalite kaybı).
  static const double minSkewToRotate = 0.75;

  /// Eğiklik hesabı bu genişliğe küçültülmüş kopya üzerinde yapılır (hız).
  static const int skewAnalysisWidth = 500;

  /// [mode] handwriting ise işlenmiş dosyanın yolunu döndürür.
  /// printed modunda veya hata durumunda `null` döner; çağıran orijinali kullanır.
  Future<String?> prepare({
    required String sourcePath,
    required String targetPath,
    required OcrMode mode,
  }) async {
    if (mode != OcrMode.handwriting) {
      return null;
    }
    try {
      // Ağır piksel işi arka plan isolate'inde: arayüz donmaz.
      final result = await compute(_runHandwritingProfile, <String, String>{
        'source': sourcePath,
        'target': targetPath,
      });
      return result;
    } catch (error) {
      debugPrint('El yazısı ön işlemesi başarısız, orijinal kullanılacak: $error');
      return null;
    }
  }

  /// El yazısı profili: gri tonlama + kontrast + eğiklik düzeltmesi.
  static img.Image enhanceForHandwriting(img.Image source) {
    var image = img.bakeOrientation(source);

    final longest = math.max(image.width, image.height);
    if (longest > AppConstants.imageMaxDimension) {
      final scale = AppConstants.imageMaxDimension / longest;
      image = img.copyResize(
        image,
        width: math.max(1, (image.width * scale).round()),
        interpolation: img.Interpolation.average,
      );
    }

    image = img.grayscale(image);
    image = img.adjustColor(image, contrast: 1.4);

    final skew = estimateSkewDegrees(image);
    if (skew.abs() >= minSkewToRotate) {
      // Döndürmede açıkta kalan köşeler beyazla doldurulur; siyah köşeler
      // hem OCR'ı yanıltır hem sonraki eğiklik hesabını bozar.
      image.backgroundColor = img.ColorRgb8(255, 255, 255);
      // Pozitif açı satırları aşağı eğer; düzeltmek için ters yöne döndürülür.
      image = img.copyRotate(
        image,
        angle: -skew,
        interpolation: img.Interpolation.linear,
      );
    }
    return image;
  }

  /// Metin satırlarının eğikliğini derece cinsinden tahmin eder.
  ///
  /// Yöntem: koyu pikseller, farklı açılar için yatay izdüşüm kovalarına
  /// dağıtılır. Satırlar düzeldiğinde kovalar yoğunlaşır, bu da kare toplamını
  /// büyütür. En yüksek puanlı açı eğiklik kabul edilir.
  /// Görüntü döndürülmediği için işlem hızlıdır ve kalite kaybı olmaz.
  static double estimateSkewDegrees(img.Image source) {
    final analysis = source.width > skewAnalysisWidth
        ? img.copyResize(source, width: skewAnalysisWidth)
        : source;

    final width = analysis.width;
    final height = analysis.height;
    if (width < 8 || height < 8) {
      return 0;
    }

    // Ortalama parlaklığa göre eşik: koyu pikseller metin kabul edilir.
    var luminanceSum = 0.0;
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        luminanceSum += analysis.getPixel(x, y).luminanceNormalized;
      }
    }
    final threshold = (luminanceSum / (width * height)) * 0.8;

    final darkX = <int>[];
    final darkY = <int>[];
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        if (analysis.getPixel(x, y).luminanceNormalized < threshold) {
          darkX.add(x);
          darkY.add(y);
        }
      }
    }
    if (darkX.length < 50) {
      return 0; // Yeterli metin yok.
    }

    final bucketCount = height + (width * math.tan(_radians(maxSkewDegrees))).ceil() * 2 + 2;
    final offset = bucketCount ~/ 2 - height ~/ 2;

    var bestAngle = 0.0;
    var bestScore = -1.0;
    for (var angle = -maxSkewDegrees;
        angle <= maxSkewDegrees + 0.0001;
        angle += skewStepDegrees) {
      final slope = math.tan(_radians(angle));
      final buckets = List<int>.filled(bucketCount, 0);
      for (var index = 0; index < darkX.length; index++) {
        final bucket = (darkY[index] - darkX[index] * slope).round() + offset;
        if (bucket >= 0 && bucket < bucketCount) {
          buckets[bucket]++;
        }
      }
      var score = 0.0;
      for (final count in buckets) {
        score += count * count;
      }
      if (score > bestScore) {
        bestScore = score;
        bestAngle = angle;
      }
    }
    return bestAngle;
  }

  static double _radians(double degrees) => degrees * math.pi / 180.0;
}

/// Isolate içinde çalışan üst düzey fonksiyon (compute için zorunlu).
String? _runHandwritingProfile(Map<String, String> payload) {
  final sourcePath = payload['source']!;
  final targetPath = payload['target']!;

  final decoded = decodeImageFileSafely(sourcePath);
  if (decoded == null) {
    return null;
  }

  final processed = ImagePreprocessor.enhanceForHandwriting(decoded);
  final encoded = img.encodeJpg(processed, quality: AppConstants.imageQuality);
  File(targetPath).writeAsBytesSync(encoded, flush: true);
  return targetPath;
}
