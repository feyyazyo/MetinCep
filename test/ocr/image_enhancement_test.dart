import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:metincep/core/utils/image_enhancement.dart';

double gray(img.Image image, int x, int y) =>
    image.getPixel(x, y).luminanceNormalized.toDouble();

/// Soldan sağa aydınlanan (yarısı gölgede) bir yüzeye yazılmış metin taklidi.
/// Mürekkep her yerde arka planın 0.40 katı: gerçek fotoğrafta olduğu gibi
/// koyuluğu MUTLAK değil, yerel arka plana GÖRELİdir. Tek bir global eşik
/// böyle bir görüntüde çalışmaz.
img.Image unevenLighting({int width = 400, int height = 300}) {
  final image = img.Image(width: width, height: height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final background = 60 + (180 * x / (width - 1));
      final inText = (y % 40 >= 10 && y % 40 < 20) && x >= 30 && x < width - 30;
      final value = (inText ? background * 0.40 : background).round().clamp(0, 255);
      image.setPixelRgb(x, y, value, value, value);
    }
  }
  return image;
}

/// Koyu zeminde, verilen dörtgene oturan aydınlık "belge".
img.Image perspectivePage({
  int width = 480,
  int height = 640,
  List<List<int>> corners = const [
    [90, 60],
    [430, 120],
    [400, 580],
    [60, 520],
  ],
}) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(60, 60, 60));
  img.fillPolygon(
    image,
    vertices: corners.map((point) => img.Point(point[0], point[1])).toList(),
    color: img.ColorRgb8(235, 235, 235),
  );
  // Sayfa içinde metin satırları.
  for (var y = 160; y < 500; y += 60) {
    img.fillRect(image, x1: 140, y1: y, x2: 350, y2: y + 16,
        color: img.ColorRgb8(45, 45, 45));
  }
  return image;
}

/// Dokulu duvar: belge kenarı yoktur, perspektif düzeltme yapılmamalı.
img.Image texturedWall({int width = 600, int height = 400}) {
  final image = img.Image(width: width, height: height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final noise = 140 + ((x * 7 + y * 13) % 25);
      final inText = y >= 150 && y < 168 && x >= 120 && x < 480;
      final value = inText ? 50 : noise;
      image.setPixelRgb(x, y, value, value, value);
    }
  }
  return image;
}

void main() {
  group('Aydınlatma normalizasyonu', () {
    test('gölgeli yüzey düzleşir, metin koyu kalır', () {
      final source = unevenLighting();
      final left = gray(source, 5, 5);
      final right = gray(source, 394, 5);
      expect(right - left, greaterThan(0.5),
          reason: 'başlangıçta sol/sağ parlaklık farkı büyük olmalı');

      final normalized = ImageEnhancement.normalizeIllumination(source);
      final normalizedLeft = gray(normalized, 5, 5);
      final normalizedRight = gray(normalized, 394, 5);

      expect(normalizedLeft, greaterThan(0.8), reason: 'sol arka plan beyaza gitmeli');
      expect(normalizedRight, greaterThan(0.8), reason: 'sağ arka plan beyaza gitmeli');
      expect((normalizedRight - normalizedLeft).abs(), lessThan(0.2),
          reason: 'aydınlatma farkı düzleşmeli');

      // Metin her iki uçta da arka plandan belirgin şekilde koyu kalmalı.
      expect(gray(normalized, 60, 15), lessThan(normalizedLeft - 0.15));
      expect(gray(normalized, 340, 15), lessThan(normalizedRight - 0.15));
    });

    test('çok küçük görüntü olduğu gibi döner', () {
      final tiny = img.Image(width: 4, height: 4);
      img.fill(tiny, color: img.ColorRgb8(120, 120, 120));
      expect(ImageEnhancement.normalizeIllumination(tiny).width, 4);
    });
  });

  group('Kontrast germe', () {
    test('dar histogram geniş aralığa yayılır', () {
      final image = img.Image(width: 100, height: 100);
      for (var y = 0; y < 100; y++) {
        for (var x = 0; x < 100; x++) {
          final value = 100 + (x % 40);
          image.setPixelRgb(x, y, value, value, value);
        }
      }

      final stretched = ImageEnhancement.stretchContrast(image);
      var minimum = 1.0;
      var maximum = 0.0;
      for (var y = 0; y < 100; y += 3) {
        for (var x = 0; x < 100; x++) {
          final value = gray(stretched, x, y);
          minimum = value < minimum ? value : minimum;
          maximum = value > maximum ? value : maximum;
        }
      }
      expect(maximum - minimum, greaterThan(0.7));
    });

    test('tek renk görüntüde germe uygulanmaz', () {
      final image = img.Image(width: 50, height: 50);
      img.fill(image, color: img.ColorRgb8(128, 128, 128));
      final stretched = ImageEnhancement.stretchContrast(image);
      expect((gray(stretched, 25, 25) - 0.5).abs(), lessThan(0.1));
    });
  });

  group('Gürültü azaltma', () {
    test('tek piksellik gürültü silinir, kalın çizgi korunur', () {
      final image = img.Image(width: 60, height: 60);
      img.fill(image, color: img.ColorRgb8(255, 255, 255));
      image.setPixelRgb(10, 10, 0, 0, 0);
      image.setPixelRgb(30, 40, 0, 0, 0);
      img.fillRect(image, x1: 5, y1: 25, x2: 55, y2: 29,
          color: img.ColorRgb8(0, 0, 0));

      final clean = ImageEnhancement.denoise(image);

      expect(gray(clean, 10, 10), greaterThan(0.8), reason: 'gürültü silinmeli');
      expect(gray(clean, 30, 40), greaterThan(0.8));
      expect(gray(clean, 30, 27), lessThan(0.2), reason: 'çizgi korunmalı');
    });
  });

  group('Uyarlamalı eşikleme', () {
    test('yarısı gölgede olan görüntüde metin iki tarafta da ayrışır', () {
      final binary = ImageEnhancement.adaptiveThreshold(unevenLighting());

      expect(gray(binary, 60, 15), lessThan(0.5), reason: 'sol metin siyah olmalı');
      expect(gray(binary, 340, 15), lessThan(0.5), reason: 'sağ metin siyah olmalı');
      expect(gray(binary, 60, 25), greaterThan(0.5), reason: 'sol arka plan beyaz');
      expect(gray(binary, 340, 25), greaterThan(0.5), reason: 'sağ arka plan beyaz');
    });

    test('çıktı yalnızca siyah ve beyaz içerir', () {
      final binary = ImageEnhancement.adaptiveThreshold(unevenLighting());
      for (var y = 0; y < binary.height; y += 17) {
        for (var x = 0; x < binary.width; x += 19) {
          final value = gray(binary, x, y);
          expect(value < 0.01 || value > 0.99, isTrue,
              reason: '($x,$y) ikili değil: $value');
        }
      }
    });
  });

  group('Perspektif (belge dörtgeni)', () {
    test('eğik çekilmiş belgenin köşeleri bulunur', () {
      final quad = ImageEnhancement.detectDocumentQuad(perspectivePage());

      expect(quad, isNotNull, reason: 'belge dörtgeni bulunmalı');
      void near(double value, double expected, String label) {
        expect((value - expected).abs(), lessThan(14),
            reason: '$label: $value, beklenen $expected');
      }

      near(quad!.topLeft.x, 90, 'sol üst x');
      near(quad.topLeft.y, 60, 'sol üst y');
      near(quad.topRight.x, 430, 'sağ üst x');
      near(quad.topRight.y, 120, 'sağ üst y');
      near(quad.bottomRight.x, 400, 'sağ alt x');
      near(quad.bottomRight.y, 580, 'sağ alt y');
      near(quad.bottomLeft.x, 60, 'sol alt x');
      near(quad.bottomLeft.y, 520, 'sol alt y');
    });

    test('düzeltme, dörtgenin oranına uygun bir görüntü üretir', () {
      final rectified = ImageEnhancement.rectifyDocument(perspectivePage());

      expect(rectified, isNotNull);
      // Dörtgen dikeydir: çıktı da dikey olmalı.
      expect(rectified!.height, greaterThan(rectified.width));
    });

    test('dokulu duvarda düzeltme YAPILMAZ (orijinale düşülür)', () {
      // Kapı/duvar yazısında belge kenarı yoktur. Yanlış kırpma, perspektifi
      // hiç düzeltmemekten kötüdür: bu yüzden null dönmeli.
      expect(ImageEnhancement.rectifyDocument(texturedWall()), isNull);
    });

    test('çizgili sayfa şeritlere bölünse de KIRPILMAZ', () {
      // Tam genişlikte koyu çizgiler aydınlık alanı yatay şeritlere böler.
      // Bir şerit "belge" sanılıp kırpılırsa metnin çoğu kaybolur; bu yüzden
      // çok uzun-ince dörtgenler reddedilir.
      final lined = img.Image(width: 600, height: 400);
      img.fill(lined, color: img.ColorRgb8(250, 250, 250));
      for (var y = 60; y < 400; y += 60) {
        img.fillRect(lined, x1: 0, y1: y, x2: 599, y2: y + 3,
            color: img.ColorRgb8(20, 20, 20));
      }

      expect(ImageEnhancement.rectifyDocument(lined), isNull);
    });

    test('tamamen düz (tam kare) belgede düzeltme yapılmaz', () {
      final flat = img.Image(width: 300, height: 400);
      img.fill(flat, color: img.ColorRgb8(240, 240, 240));
      img.fillRect(flat, x1: 40, y1: 60, x2: 260, y2: 80,
          color: img.ColorRgb8(40, 40, 40));

      expect(ImageEnhancement.rectifyDocument(flat), isNull);
    });
  });
}
