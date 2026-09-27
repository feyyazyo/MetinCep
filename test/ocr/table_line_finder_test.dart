import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:metincep/core/utils/table_line_finder.dart';

/// Beyaz zeminde gri metin lekeleri olan kenarlıklı tablo üretir.
img.Image borderedTable({
  bool withBorders = true,
  int width = 600,
  int height = 400,
}) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(255, 255, 255));

  const rowLines = [40, 130, 220, 310, 360];
  const columnLines = [40, 200, 380, 560];

  if (withBorders) {
    for (final y in rowLines) {
      img.fillRect(image, x1: 40, y1: y, x2: 560, y2: y + 2,
          color: img.ColorRgb8(25, 25, 25));
    }
    for (final x in columnLines) {
      img.fillRect(image, x1: x, y1: 40, x2: x + 2, y2: 362,
          color: img.ColorRgb8(25, 25, 25));
    }
  }

  // Hücre içi "metin" lekeleri (çizgi sayılmamalı: kısa kalırlar).
  for (final y in [40, 130, 220, 310]) {
    for (final x in [40, 200, 380]) {
      img.fillRect(image, x1: x + 20, y1: y + 30, x2: x + 120, y2: y + 55,
          color: img.ColorRgb8(60, 60, 60));
    }
  }
  return image;
}

void main() {
  group('Çizgili tablo', () {
    test('yatay ve dikey çizgiler bulunur', () {
      final lines = TableLineFinder.findInImage(
        borderedTable(),
        regionLeft: 60,
        regionTop: 70,
        regionRight: 540,
        regionBottom: 350,
      );

      expect(lines.horizontal.length, greaterThanOrEqualTo(4));
      expect(lines.vertical.length, greaterThanOrEqualTo(3));
      expect(lines.hasGrid, isTrue);

      // Kolon çizgileri beklenen konumların yakınında olmalı (±8 piksel).
      for (final expectedX in [40.0, 200.0, 380.0, 560.0]) {
        final found = lines.vertical.any((x) => (x - expectedX).abs() <= 8);
        expect(found, isTrue, reason: 'x=$expectedX yakınında dikey çizgi yok');
      }
      for (final expectedY in [40.0, 130.0, 220.0, 310.0]) {
        final found = lines.horizontal.any((y) => (y - expectedY).abs() <= 8);
        expect(found, isTrue, reason: 'y=$expectedY yakınında yatay çizgi yok');
      }
    });

    test('kalın çizgi tek çizgi olarak döner', () {
      final image = img.Image(width: 400, height: 300);
      img.fill(image, color: img.ColorRgb8(255, 255, 255));
      // 5 piksel kalınlığında tek yatay çizgi.
      img.fillRect(image, x1: 20, y1: 150, x2: 380, y2: 155,
          color: img.ColorRgb8(20, 20, 20));

      final lines = TableLineFinder.findInImage(
        image,
        regionLeft: 20,
        regionTop: 100,
        regionRight: 380,
        regionBottom: 200,
      );

      expect(lines.horizontal.length, 1);
    });
  });

  group('Çizgisiz / güvenilmez görüntüler', () {
    test('çizgisiz tabloda çizgi bulunmaz (geometriye düşülür)', () {
      final lines = TableLineFinder.findInImage(
        borderedTable(withBorders: false),
        regionLeft: 60,
        regionTop: 70,
        regionRight: 540,
        regionBottom: 350,
      );

      expect(lines.horizontal, isEmpty);
      expect(lines.vertical, isEmpty);
      expect(lines.isEmpty, isTrue);
    });

    test('düz beyaz görüntüde çizgi bulunmaz', () {
      final image = img.Image(width: 300, height: 200);
      img.fill(image, color: img.ColorRgb8(250, 250, 250));

      final lines = TableLineFinder.findInImage(
        image,
        regionLeft: 10,
        regionTop: 10,
        regionRight: 290,
        regionBottom: 190,
      );

      expect(lines.isEmpty, isTrue);
    });

    test('tamamen koyu görüntüde çizgi bulunmaz', () {
      // Uyarlamalı eşikleme, düz koyu yüzeyi metin/çizgi sanmamalı.
      final image = img.Image(width: 300, height: 200);
      img.fill(image, color: img.ColorRgb8(30, 30, 30));

      final lines = TableLineFinder.findInImage(
        image,
        regionLeft: 10,
        regionTop: 10,
        regionRight: 290,
        regionBottom: 190,
      );

      expect(lines.isEmpty, isTrue);
    });

    test('çok küçük bölge güvenle boş döner', () {
      final lines = TableLineFinder.findInImage(
        borderedTable(),
        regionLeft: 10,
        regionTop: 10,
        regionRight: 25,
        regionBottom: 25,
      );

      expect(lines.isEmpty, isTrue);
    });
  });
}
