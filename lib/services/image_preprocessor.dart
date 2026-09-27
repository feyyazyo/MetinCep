import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../core/constants/app_constants.dart';
import '../core/utils/image_decoding.dart';
import '../core/utils/image_enhancement.dart';
import '../models/ocr_mode.dart';

/// El yazısı ve zor ışık koşulları için görüntü ön işleme.
///
/// **Basılı metin yolu hiç değişmez:** [prepare] `printed` modunda ilk satırda
/// `null` döner, çağıran orijinal dosyayı kullanır. İki boru hattı ayrıdır.
///
/// El yazısı boru hattı (kapı/duvar/kâğıt senaryosu):
/// ```
/// EXIF yönü → ölçekleme → (varsa) PERSPEKTİF DÜZELTME → gri tonlama
/// → AYDINLATMA NORMALİZASYONU → KONTRAST GERME → EĞİKLİK DÜZELTME
/// ```
/// İkinci geçiş (ilk OCR zayıf kalırsa): `GÜRÜLTÜ AZALTMA → UYARLAMALI EŞİKLEME`.
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
      return await compute(runHandwritingProfile, <String, String>{
        'source': sourcePath,
        'target': targetPath,
      });
    } catch (error) {
      debugPrint('El yazısı ön işlemesi başarısız, orijinal kullanılacak: $error');
      return null;
    }
  }

  /// İkinci geçiş: ilk OCR zayıf kaldıysa ikili (siyah-beyaz) sürüm denenir.
  /// Başarısızsa `null` döner ve ilk sonuç korunur.
  ///
  /// [alreadyEnhanced] true ise kaynak el yazısı profilinden geçmiştir ve
  /// yalnızca gürültü azaltma + eşikleme uygulanır.
  Future<String?> prepareBinary({
    required String sourcePath,
    required String targetPath,
    bool alreadyEnhanced = false,
  }) async {
    try {
      return await compute(runBinaryProfile, <String, String>{
        'source': sourcePath,
        'target': targetPath,
        'enhanced': alreadyEnhanced ? '1' : '0',
      });
    } catch (error) {
      debugPrint('İkili el yazısı geçişi başarısız: $error');
      return null;
    }
  }

  /// El yazısı profili: perspektif → gri → aydınlatma → kontrast → eğiklik.
  static img.Image enhanceForHandwriting(img.Image source) {
    var image = img.bakeOrientation(source);
    image = _downscale(image);

    // Perspektif: yalnızca güvenilir bir belge dörtgeni bulunursa uygulanır.
    // Yanlış kırpma, perspektifi hiç düzeltmemekten kötüdür.
    final rectified = ImageEnhancement.rectifyDocument(image);
    if (rectified != null) {
      image = _downscale(rectified);
    }

    image = img.grayscale(image);
    image = ImageEnhancement.normalizeIllumination(image);
    image = ImageEnhancement.stretchContrast(image);

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

  /// İkili profil: el yazısı profilinin üzerine gürültü azaltma + eşikleme.
  /// (Kaynak ham fotoğrafsa kullanılır.)
  static img.Image binarizeForHandwriting(img.Image source) =>
      binarizeEnhanced(enhanceForHandwriting(source));

  /// Zaten iyileştirilmiş görüntüyü ikili hâle getirir: gürültü azaltma +
  /// uyarlamalı eşikleme. İyileştirme adımları ikinci kez çalıştırılmaz.
  static img.Image binarizeEnhanced(img.Image enhanced) =>
      ImageEnhancement.adaptiveThreshold(ImageEnhancement.denoise(enhanced));

  static img.Image _downscale(img.Image image) {
    final longest = math.max(image.width, image.height);
    if (longest <= AppConstants.imageMaxDimension) {
      return image;
    }
    final scale = AppConstants.imageMaxDimension / longest;
    return img.copyResize(
      image,
      width: math.max(1, (image.width * scale).round()),
      interpolation: img.Interpolation.average,
    );
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

    final bucketCount =
        height + (width * math.tan(_radians(maxSkewDegrees))).ceil() * 2 + 2;
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
String? runHandwritingProfile(Map<String, String> payload) => _run(
      payload,
      ImagePreprocessor.enhanceForHandwriting,
    );

/// Isolate içinde çalışan ikili (siyah-beyaz) profil.
/// `enhanced` alanı '1' ise kaynak zaten iyileştirilmiştir.
String? runBinaryProfile(Map<String, String> payload) => _run(
      payload,
      payload['enhanced'] == '1'
          ? ImagePreprocessor.binarizeEnhanced
          : ImagePreprocessor.binarizeForHandwriting,
    );

String? _run(
  Map<String, String> payload,
  img.Image Function(img.Image source) transform,
) {
  final sourcePath = payload['source']!;
  final targetPath = payload['target']!;

  final decoded = decodeImageFileSafely(sourcePath);
  if (decoded == null) {
    return null;
  }

  final processed = transform(decoded);
  final encoded = img.encodeJpg(processed, quality: AppConstants.imageQuality);
  File(targetPath).writeAsBytesSync(encoded, flush: true);
  return targetPath;
}
