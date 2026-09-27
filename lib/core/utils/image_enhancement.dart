import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'integral_image.dart';

/// El yazısı ve zor ışık koşulları için görüntü iyileştirme adımları.
///
/// Tamamı saf (platformsuz) fonksiyonlardır: `compute` içinde çalışır ve
/// birim testlerle doğrulanabilir. Hiçbiri basılı metin yolunda kullanılmaz.
class ImageEnhancement {
  ImageEnhancement._();

  /// Yerel ortalama haritası bu genişlikte hesaplanır. Aydınlatma yavaş
  /// değiştiği için küçük ızgara yeterlidir ve bellek kullanımı düşük kalır.
  static const int meanMapWidth = 640;

  /// Yerel ortalama penceresi (kısa kenarın oranı).
  static const double meanRadiusRatio = 0.06;

  /// Uyarlamalı eşiklemede yerel ortalamanın altına inme payı.
  static const double thresholdBias = 0.90;

  /// Kontrast germede kırpılan alt/üst yüzdelik.
  static const double clipPercentile = 0.02;

  /// Belge dörtgeni aranırken kullanılan analiz genişliği.
  static const int quadAnalysisWidth = 480;

  /// Dörtgenin görüntünün en az bu kadarını kaplaması gerekir.
  /// Yüksek tutulur: fotoğrafta belge küçük bir parçaysa kırpmak risklidir.
  static const double quadMinAreaRatio = 0.35;

  /// Belge en/boy oranı bu aralıkta olmalı. Çizgili bir sayfada aydınlık alan
  /// yatay şeritlere bölünür; bu şeritler çok uzun-ince olduğu için belge
  /// sayılmaz ve yanlış kırpma önlenir.
  static const double quadMinAspect = 0.35;
  static const double quadMaxAspect = 3.0;

  /// Bundan büyükse zaten tüm kare belgedir; düzeltme gereksiz sayılır.
  static const double quadMaxAreaRatio = 0.97;

  /// **Aydınlatma normalizasyonu.** Her pikseli yerel arka plan ortalamasına
  /// bölerek gölgeyi, sararmayı ve eşit olmayan ışığı düzleştirir.
  ///
  /// Kapıya/duvara yazılmış yazıda tek bir global eşik çalışmaz: bir köşe
  /// gölgede, diğeri güneşte olur. Bu adım metni arka plandan ayırır.
  ///
  /// Gauss bulanıklığı yerine integral görüntü kullanılır: yarıçap ne olursa
  /// olsun piksel başına sabit maliyet, telefonda da hızlı.
  static img.Image normalizeIllumination(img.Image gray) {
    final width = gray.width;
    final height = gray.height;
    if (width < 8 || height < 8) {
      return gray;
    }

    final background = _LocalMeanMap.fromImage(gray);
    final output = img.Image(width: width, height: height);

    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final value = gray.getPixel(x, y).luminanceNormalized.toDouble();
        final local = math.max(background.at(x, y), 0.02);
        // Düz alanlarda value == local olur ve piksel beyaza gider;
        // mürekkep arka planından koyu olduğu için oranı küçük kalır.
        final normalized = (value / local * 255).clamp(0.0, 255.0);
        final level = normalized.round();
        output.setPixelRgb(x, y, level, level, level);
      }
    }
    return output;
  }

  /// **Kontrast germe.** Alt/üst yüzdelikleri kırpıp histogramı 0..255'e yayar.
  /// Soluk kurşun kalem yazısı bu adımdan sonra belirginleşir.
  static img.Image stretchContrast(img.Image gray) {
    final width = gray.width;
    final height = gray.height;
    final histogram = List<int>.filled(256, 0);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final level =
            (gray.getPixel(x, y).luminanceNormalized.toDouble() * 255)
                .round()
                .clamp(0, 255)
                .toInt();
        histogram[level]++;
      }
    }

    final total = width * height;
    final clip = (total * clipPercentile).floor();
    var low = 0;
    var high = 255;
    var counted = 0;
    for (var level = 0; level < 256; level++) {
      counted += histogram[level];
      if (counted > clip) {
        low = level;
        break;
      }
    }
    counted = 0;
    for (var level = 255; level >= 0; level--) {
      counted += histogram[level];
      if (counted > clip) {
        high = level;
        break;
      }
    }
    if (high - low < 16) {
      return gray; // Neredeyse tek renk: germek yalnızca gürültüyü büyütür.
    }

    final scale = 255.0 / (high - low);
    final output = img.Image(width: width, height: height);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final value =
            gray.getPixel(x, y).luminanceNormalized.toDouble() * 255;
        final level = ((value - low) * scale).clamp(0.0, 255.0).round();
        output.setPixelRgb(x, y, level, level, level);
      }
    }
    return output;
  }

  /// **3×3 medyan süzgeç.** Tuz-biber gürültüsünü ve duvar dokusunu azaltır,
  /// harf kenarlarını bulanıklaştırmaz (ortalama süzgecin aksine).
  static img.Image denoise(img.Image gray) {
    final width = gray.width;
    final height = gray.height;
    if (width < 3 || height < 3) {
      return gray;
    }
    // Uint8List: tam çözünürlükte List<int> yerine 8 kat az bellek.
    final source = Uint8List(width * height);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        source[y * width + x] =
            (gray.getPixel(x, y).luminanceNormalized.toDouble() * 255).round();
      }
    }

    final output = img.Image(width: width, height: height);
    final window = Uint8List(9);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        var count = 0;
        for (var dy = -1; dy <= 1; dy++) {
          final yy = y + dy;
          if (yy < 0 || yy >= height) {
            continue;
          }
          for (var dx = -1; dx <= 1; dx++) {
            final xx = x + dx;
            if (xx < 0 || xx >= width) {
              continue;
            }
            // Eklemeli sıralama: pencere 9 elemanlı, yeni liste ayrılmaz.
            final value = source[yy * width + xx];
            var index = count;
            while (index > 0 && window[index - 1] > value) {
              window[index] = window[index - 1];
              index--;
            }
            window[index] = value;
            count++;
          }
        }
        final level = window[count ~/ 2];
        output.setPixelRgb(x, y, level, level, level);
      }
    }
    return output;
  }

  /// **Uyarlamalı eşikleme.** Piksel, kendi çevresinin ortalamasından belirgin
  /// şekilde koyuysa siyah, değilse beyaz olur. Gölgeli fotoğrafta global
  /// eşiğin yaptığı "yarısı tamamen siyah" hatasını yapmaz.
  static img.Image adaptiveThreshold(img.Image gray) {
    final width = gray.width;
    final height = gray.height;
    if (width < 8 || height < 8) {
      return gray;
    }
    final mean = _LocalMeanMap.fromImage(gray);
    final output = img.Image(width: width, height: height);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final value = gray.getPixel(x, y).luminanceNormalized.toDouble();
        final dark = value < mean.at(x, y) * thresholdBias;
        final level = dark ? 0 : 255;
        output.setPixelRgb(x, y, level, level, level);
      }
    }
    return output;
  }

  /// Belge dörtgenini (kâğıt/pano kenarları) arar.
  ///
  /// Bulunamazsa veya doğrulamayı geçemezse `null` döner ve çağıran orijinali
  /// kullanır: **yanlış kırpma, perspektifi hiç düzeltmemekten kötüdür.**
  static DocumentQuad? detectDocumentQuad(img.Image source) {
    var analysis = source;
    var scale = 1.0;
    if (analysis.width > quadAnalysisWidth) {
      scale = quadAnalysisWidth / analysis.width;
      analysis = img.copyResize(
        analysis,
        width: quadAnalysisWidth,
        interpolation: img.Interpolation.average,
      );
    }
    analysis = img.grayscale(analysis);

    final width = analysis.width;
    final height = analysis.height;
    if (width < 32 || height < 32) {
      return null;
    }

    final values = List<double>.filled(width * height, 0);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        values[y * width + x] =
            analysis.getPixel(x, y).luminanceNormalized.toDouble();
      }
    }
    final threshold = _otsuThreshold(values);

    // Belge, arka plandan daha aydınlık olan büyük bir bölgedir.
    final bright = List<bool>.filled(width * height, false);
    var brightCount = 0;
    for (var index = 0; index < values.length; index++) {
      if (values[index] >= threshold) {
        bright[index] = true;
        brightCount++;
      }
    }
    final area = width * height;
    if (brightCount < area * quadMinAreaRatio ||
        brightCount > area * quadMaxAreaRatio) {
      return null;
    }

    final component = _largestComponent(bright, width, height);
    if (component == null || component.count < area * quadMinAreaRatio) {
      return null;
    }

    final quad = DocumentQuad(
      topLeft: component.topLeft / scale,
      topRight: component.topRight / scale,
      bottomRight: component.bottomRight / scale,
      bottomLeft: component.bottomLeft / scale,
    );
    if (!quad.isPlausible(source.width, source.height)) {
      return null;
    }
    return quad;
  }

  /// Dörtgeni dikdörtgene açar. Dörtgen yoksa/geçersizse `null` döner.
  static img.Image? rectifyDocument(img.Image source) {
    final quad = detectDocumentQuad(source);
    if (quad == null) {
      return null;
    }
    if (quad.isNearlyFullFrame(source.width, source.height)) {
      return null; // Zaten düz: yeniden örneklemek kaliteyi düşürür.
    }
    final targetWidth = quad.averageWidth.round().clamp(32, source.width).toInt();
    final targetHeight = quad.averageHeight.round().clamp(32, source.height).toInt();
    return img.copyRectify(
      source,
      topLeft: img.Point(quad.topLeft.x, quad.topLeft.y),
      topRight: img.Point(quad.topRight.x, quad.topRight.y),
      bottomLeft: img.Point(quad.bottomLeft.x, quad.bottomLeft.y),
      bottomRight: img.Point(quad.bottomRight.x, quad.bottomRight.y),
      interpolation: img.Interpolation.linear,
      toImage: img.Image(width: targetWidth, height: targetHeight),
    );
  }

  /// Otsu eşiği (0..1): iki sınıf arası varyansı en büyük yapan değer.
  static double _otsuThreshold(List<double> values) {
    final histogram = List<int>.filled(256, 0);
    for (final value in values) {
      histogram[(value * 255).round().clamp(0, 255).toInt()]++;
    }
    final total = values.length;
    var sum = 0.0;
    for (var level = 0; level < 256; level++) {
      sum += level * histogram[level];
    }
    var sumB = 0.0;
    var weightB = 0;
    var best = 0.0;
    var bestLevel = 127;
    for (var level = 0; level < 256; level++) {
      weightB += histogram[level];
      if (weightB == 0) {
        continue;
      }
      final weightF = total - weightB;
      if (weightF == 0) {
        break;
      }
      sumB += level * histogram[level];
      final meanB = sumB / weightB;
      final meanF = (sum - sumB) / weightF;
      final between = weightB * weightF * (meanB - meanF) * (meanB - meanF);
      if (between > best) {
        best = between;
        bestLevel = level;
      }
    }
    return bestLevel / 255.0;
  }

  /// En büyük bağlı bileşeni tarar ve **noktaları biriktirmeden** köşe
  /// adaylarını döndürür (bellek: 300 bin nesne yerine dört nokta).
  static _Component? _largestComponent(List<bool> mask, int width, int height) {
    final visited = List<bool>.filled(mask.length, false);
    _Component? best;
    final queue = <int>[];
    for (var start = 0; start < mask.length; start++) {
      if (!mask[start] || visited[start]) {
        continue;
      }
      queue
        ..clear()
        ..add(start);
      visited[start] = true;
      final component = _Component();
      while (queue.isNotEmpty) {
        final index = queue.removeLast();
        final x = index % width;
        final y = index ~/ width;
        component.add(x.toDouble(), y.toDouble());
        if (x > 0) {
          _visit(mask, visited, queue, index - 1);
        }
        if (x < width - 1) {
          _visit(mask, visited, queue, index + 1);
        }
        if (y > 0) {
          _visit(mask, visited, queue, index - width);
        }
        if (y < height - 1) {
          _visit(mask, visited, queue, index + width);
        }
      }
      if (best == null || component.count > best.count) {
        best = component;
      }
    }
    return best;
  }

  static void _visit(
    List<bool> mask,
    List<bool> visited,
    List<int> queue,
    int index,
  ) {
    if (mask[index] && !visited[index]) {
      visited[index] = true;
      queue.add(index);
    }
  }
}

/// Bağlı bileşenin köşe adayları. Noktalar saklanmaz, yalnızca uç değerler
/// güncellenir: x+y en küçük -> sol üst, x-y en büyük -> sağ üst, vb.
class _Component {
  int count = 0;
  ImagePoint topLeft = const ImagePoint(0, 0);
  ImagePoint topRight = const ImagePoint(0, 0);
  ImagePoint bottomRight = const ImagePoint(0, 0);
  ImagePoint bottomLeft = const ImagePoint(0, 0);

  double _minSum = double.infinity;
  double _maxSum = -double.infinity;
  double _minDiff = double.infinity;
  double _maxDiff = -double.infinity;

  void add(double x, double y) {
    count++;
    final sum = x + y;
    final diff = x - y;
    if (sum < _minSum) {
      _minSum = sum;
      topLeft = ImagePoint(x, y);
    }
    if (sum > _maxSum) {
      _maxSum = sum;
      bottomRight = ImagePoint(x, y);
    }
    if (diff > _maxDiff) {
      _maxDiff = diff;
      topRight = ImagePoint(x, y);
    }
    if (diff < _minDiff) {
      _minDiff = diff;
      bottomLeft = ImagePoint(x, y);
    }
  }
}

/// Basit nokta (image paketinin Point'i yerine, saf hesap için).
class ImagePoint {
  const ImagePoint(this.x, this.y);

  final double x;
  final double y;

  ImagePoint operator /(double scale) => ImagePoint(x / scale, y / scale);
}

/// Belge dörtgeni (perspektif düzeltme için dört köşe).
class DocumentQuad {
  const DocumentQuad({
    required this.topLeft,
    required this.topRight,
    required this.bottomRight,
    required this.bottomLeft,
  });

  final ImagePoint topLeft;
  final ImagePoint topRight;
  final ImagePoint bottomRight;
  final ImagePoint bottomLeft;

  double get averageWidth =>
      (_distance(topLeft, topRight) + _distance(bottomLeft, bottomRight)) / 2;

  double get averageHeight =>
      (_distance(topLeft, bottomLeft) + _distance(topRight, bottomRight)) / 2;

  /// Dörtgen makul mü: kenarlar yeterince uzun, karşıt kenarlar benzer,
  /// alan sınırlayıcı dikdörtgenin önemli bölümünü kaplıyor.
  bool isPlausible(int imageWidth, int imageHeight) {
    final top = _distance(topLeft, topRight);
    final bottom = _distance(bottomLeft, bottomRight);
    final left = _distance(topLeft, bottomLeft);
    final right = _distance(topRight, bottomRight);
    if (top < imageWidth * 0.3 || bottom < imageWidth * 0.3) {
      return false;
    }
    if (left < imageHeight * 0.3 || right < imageHeight * 0.3) {
      return false;
    }
    // Karşıt kenarlar birbirinden en çok 2 kat farklı olabilir.
    if (top / bottom > 2 || bottom / top > 2) {
      return false;
    }
    if (left / right > 2 || right / left > 2) {
      return false;
    }
    // Belge aşırı uzun-ince olamaz. Bu kural, çizgili sayfada oluşan yatay
    // şeritlerin (ör. 2560x168) belge sanılıp kırpılmasını engeller.
    final aspect = averageWidth / math.max(averageHeight, 1);
    if (aspect < ImageEnhancement.quadMinAspect ||
        aspect > ImageEnhancement.quadMaxAspect) {
      return false;
    }
    final boundsWidth = [topLeft.x, topRight.x, bottomLeft.x, bottomRight.x];
    final boundsHeight = [topLeft.y, topRight.y, bottomLeft.y, bottomRight.y];
    final boxWidth = boundsWidth.reduce(math.max) - boundsWidth.reduce(math.min);
    final boxHeight = boundsHeight.reduce(math.max) - boundsHeight.reduce(math.min);
    if (boxWidth <= 0 || boxHeight <= 0) {
      return false;
    }
    return _area() >= boxWidth * boxHeight * 0.55;
  }

  /// Dörtgen neredeyse tüm kareyi kaplıyor ve köşeleri dik: düzeltme gereksiz.
  bool isNearlyFullFrame(int imageWidth, int imageHeight) {
    final tolerance = math.min(imageWidth, imageHeight) * 0.02;
    bool near(double value, double target) => (value - target).abs() <= tolerance;
    return near(topLeft.x, 0) &&
        near(topLeft.y, 0) &&
        near(topRight.x, imageWidth - 1) &&
        near(topRight.y, 0) &&
        near(bottomLeft.x, 0) &&
        near(bottomLeft.y, imageHeight - 1) &&
        near(bottomRight.x, imageWidth - 1) &&
        near(bottomRight.y, imageHeight - 1);
  }

  double _area() {
    // Ayakkabı bağı (shoelace) formülü.
    final points = [topLeft, topRight, bottomRight, bottomLeft];
    var sum = 0.0;
    for (var index = 0; index < points.length; index++) {
      final a = points[index];
      final b = points[(index + 1) % points.length];
      sum += a.x * b.y - b.x * a.y;
    }
    return sum.abs() / 2;
  }

  static double _distance(ImagePoint a, ImagePoint b) =>
      math.sqrt((a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y));

  @override
  String toString() => 'DocumentQuad(${topLeft.x.round()},${topLeft.y.round()} '
      '${topRight.x.round()},${topRight.y.round()} '
      '${bottomRight.x.round()},${bottomRight.y.round()} '
      '${bottomLeft.x.round()},${bottomLeft.y.round()})';
}

/// Küçültülmüş ızgarada tutulan yerel ortalama haritası.
/// Tam çözünürlükte integral görüntü tutmak yerine bellek dostu bir yaklaşım.
class _LocalMeanMap {
  _LocalMeanMap._(this._integral, this._width, this._height, this._scale);

  factory _LocalMeanMap.fromImage(img.Image gray) {
    var analysis = gray;
    var scale = 1.0;
    if (analysis.width > ImageEnhancement.meanMapWidth) {
      scale = ImageEnhancement.meanMapWidth / analysis.width;
      analysis = img.copyResize(
        analysis,
        width: ImageEnhancement.meanMapWidth,
        interpolation: img.Interpolation.average,
      );
    }
    final width = analysis.width;
    final height = analysis.height;
    final values = List<double>.filled(width * height, 0);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        values[y * width + x] =
            analysis.getPixel(x, y).luminanceNormalized.toDouble();
      }
    }
    return _LocalMeanMap._(
      IntegralImage(values, width, height),
      width,
      height,
      scale,
    );
  }

  final IntegralImage _integral;
  final int _width;
  final int _height;
  final double _scale;

  int get _radius => math.max(
        3,
        (math.min(_width, _height) * ImageEnhancement.meanRadiusRatio).round(),
      );

  /// Tam çözünürlük koordinatı için yerel ortalama (0..1).
  double at(int x, int y) {
    final mx = (x * _scale).round().clamp(0, _width - 1).toInt();
    final my = (y * _scale).round().clamp(0, _height - 1).toInt();
    return _integral.average(mx, my, _radius);
  }
}
