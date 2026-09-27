import 'dart:math' as math;

import 'package:image/image.dart' as img;

import '../../models/table_grid_lines.dart';
import 'image_decoding.dart';
import 'integral_image.dart';

/// Fotoğraftaki tablo çizgilerini bulur (çizgili/kenarlıklı tablolar için).
///
/// Ağır bir bağımlılık (OpenCV gibi) eklenmez; yalnızca `image` paketiyle:
/// gri tonlama → uyarlamalı eşikleme → yatay/dikey koşu (run) analizi.
///
/// Analiz **yalnızca OCR kelimelerinin kapladığı bölgede** yapılır. Böylece
/// sayfa kenarı, masa kenarı veya gölge sınırı çizgi sanılmaz.
///
/// Çizgi bulunamazsa boş sonuç döner: çizgisiz tablolar geometriyle algılanır.
class TableLineFinder {
  TableLineFinder._();

  /// Analiz bu genişliğe küçültülmüş kopya üzerinde yapılır (hız).
  static const int analysisWidth = 900;

  /// Bir yatay çizginin bölge genişliğinin en az bu kadarını kaplaması gerekir.
  static const double horizontalCoverage = 0.55;

  /// Bir dikey çizginin bölge yüksekliğinin en az bu kadarını kaplaması gerekir.
  static const double verticalCoverage = 0.55;

  /// Uyarlamalı eşiklemede pencere yarıçapı (bölge kısa kenarının oranı).
  static const double windowRatio = 0.06;

  /// Eşiğin altına inme payı: yalnızca belirgin koyu pikseller çizgi sayılır.
  static const double thresholdBias = 0.92;

  /// Birbirine bu kadar yakın çizgiler (piksel, analiz ölçeğinde) tek çizgi sayılır.
  static const int mergeDistance = 6;

  /// En fazla bu kadar çizgi döndürülür (gürültü koruması).
  static const int maxLines = 40;

  /// [imagePath] içindeki tablo çizgilerini, **özgün görüntü koordinatlarında**
  /// döndürür. [region] OCR kelimelerinin kapladığı alandır (özgün koordinat).
  static TableGridLines find({
    required String imagePath,
    required double regionLeft,
    required double regionTop,
    required double regionRight,
    required double regionBottom,
  }) {
    final decoded = decodeImageFileSafely(imagePath);
    if (decoded == null) {
      return TableGridLines.none;
    }
    return findInImage(
      img.bakeOrientation(decoded),
      regionLeft: regionLeft,
      regionTop: regionTop,
      regionRight: regionRight,
      regionBottom: regionBottom,
    );
  }

  /// Çözülmüş görüntü üzerinde çalışır (test edilebilir saf bölüm).
  static TableGridLines findInImage(
    img.Image source, {
    required double regionLeft,
    required double regionTop,
    required double regionRight,
    required double regionBottom,
  }) {
    // Bölge, kenarlıkları da kapsaması için bir miktar genişletilir.
    final marginX = (regionRight - regionLeft) * 0.06;
    final marginY = (regionBottom - regionTop) * 0.10;
    final left = math.max(0, (regionLeft - marginX).floor());
    final top = math.max(0, (regionTop - marginY).floor());
    final right = math.min(source.width, (regionRight + marginX).ceil());
    final bottom = math.min(source.height, (regionBottom + marginY).ceil());
    final width = right - left;
    final height = bottom - top;
    if (width < 40 || height < 40) {
      return TableGridLines.none;
    }

    var region = img.copyCrop(
      source,
      x: left,
      y: top,
      width: width,
      height: height,
    );
    var scale = 1.0;
    if (region.width > analysisWidth) {
      scale = analysisWidth / region.width;
      region = img.copyResize(
        region,
        width: analysisWidth,
        interpolation: img.Interpolation.average,
      );
    }
    region = img.grayscale(region);

    final mask = _darkMask(region);
    final horizontal = _horizontalLines(mask, region.width, region.height);
    final vertical = _verticalLines(mask, region.width, region.height);

    if (horizontal.length > maxLines || vertical.length > maxLines) {
      // Dokulu arka plan (tuğla duvar, ahşap) çizgi gibi görünür: güvenilmez.
      return TableGridLines.none;
    }

    return TableGridLines(
      horizontal: horizontal
          .map((y) => top + y / scale)
          .toList(growable: false),
      vertical: vertical
          .map((x) => left + x / scale)
          .toList(growable: false),
    );
  }

  /// Uyarlamalı (yerel ortalama) eşikleme: gölgeli/eşit olmayan aydınlatmada
  /// tek bir global eşik çalışmaz.
  static List<bool> _darkMask(img.Image gray) {
    final width = gray.width;
    final height = gray.height;
    final luminance = List<double>.filled(width * height, 0);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        // luminanceNormalized `num` döner; listeye yazmak için double gerekir.
        luminance[y * width + x] =
            gray.getPixel(x, y).luminanceNormalized.toDouble();
      }
    }
    final mean = IntegralImage(luminance, width, height);
    final radius = math.max(
      4,
      (math.min(width, height) * windowRatio).round(),
    );

    final mask = List<bool>.filled(width * height, false);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final local = mean.average(x, y, radius);
        mask[y * width + x] = luminance[y * width + x] < local * thresholdBias;
      }
    }
    return mask;
  }

  static List<double> _horizontalLines(List<bool> mask, int width, int height) {
    final minRun = (width * horizontalCoverage).round();
    final candidates = <int>[];
    for (var y = 0; y < height; y++) {
      var run = 0;
      var best = 0;
      final rowOffset = y * width;
      for (var x = 0; x < width; x++) {
        if (mask[rowOffset + x]) {
          run++;
          if (run > best) {
            best = run;
          }
        } else {
          run = 0;
        }
      }
      if (best >= minRun) {
        candidates.add(y);
      }
    }
    return _mergeRuns(candidates);
  }

  static List<double> _verticalLines(List<bool> mask, int width, int height) {
    final minRun = (height * verticalCoverage).round();
    final candidates = <int>[];
    for (var x = 0; x < width; x++) {
      var run = 0;
      var best = 0;
      for (var y = 0; y < height; y++) {
        if (mask[y * width + x]) {
          run++;
          if (run > best) {
            best = run;
          }
        } else {
          run = 0;
        }
      }
      if (best >= minRun) {
        candidates.add(x);
      }
    }
    return _mergeRuns(candidates);
  }

  /// Kalın bir çizgi birden çok komşu satır/kolon üretir; tek çizgiye indirilir.
  static List<double> _mergeRuns(List<int> positions) {
    if (positions.isEmpty) {
      return const [];
    }
    final merged = <double>[];
    var previous = positions.first;
    var sum = positions.first;
    var count = 1;
    for (final position in positions.skip(1)) {
      if (position - previous <= mergeDistance) {
        sum += position;
        count++;
      } else {
        merged.add(sum / count);
        sum = position;
        count = 1;
      }
      previous = position;
    }
    merged.add(sum / count);
    return merged;
  }
}
