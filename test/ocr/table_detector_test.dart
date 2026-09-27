import 'package:flutter_test/flutter_test.dart';
import 'package:metincep/core/utils/table_detector.dart';
import 'package:metincep/core/utils/text_layout_formatter.dart';

/// Test yardımcısı: her satır (metin, sol, sağ) üçlülerinden OcrLine üretir.
/// Satır yüksekliği 20, satır aralığı 40 piksel varsayılır.
OcrLine line(List<(String, double, double)> words, {required double top}) {
  final ocrWords = words
      .map(
        (word) => OcrWord(
          text: word.$1,
          left: word.$2,
          right: word.$3,
          top: top,
          bottom: top + 20,
        ),
      )
      .toList();
  return OcrLine(
    text: ocrWords.map((word) => word.text).join(' '),
    top: top,
    bottom: top + 20,
    left: ocrWords.first.left,
    right: ocrWords.last.right,
    words: ocrWords,
  );
}

void main() {
  group('Tablo algılanır', () {
    test('3 kolonlu tablo: "2500 TL" tek hücre kalır', () {
      final table = TableDetector.detect([
        line([('Ürün', 0, 60), ('Adet', 200, 260), ('Fiyat', 400, 470)], top: 0),
        line([
          ('Mermer', 0, 90),
          ('10', 200, 225),
          ('2500', 400, 450),
          ('TL', 460, 480),
        ], top: 40),
        line([
          ('Granit', 0, 80),
          ('5', 200, 212),
          ('3200', 400, 450),
          ('TL', 460, 480),
        ], top: 80),
      ]);

      expect(table, isNotNull);
      expect(table!.rowCount, 3);
      expect(table.columnCount, 3);
      expect(table.hasHeader, isTrue);
      expect(table.values, [
        ['Ürün', 'Adet', 'Fiyat'],
        ['Mermer', '10', '2500 TL'],
        ['Granit', '5', '3200 TL'],
      ]);
      expect(table.confidence, greaterThan(0.9));
      expect(table.headerValues, ['Ürün', 'Adet', 'Fiyat']);
      expect(table.bodyValues, hasLength(2));
    });

    test('2 kolonlu tablo', () {
      final table = TableDetector.detect([
        line([('Ad', 0, 40), ('Değer', 200, 260)], top: 0),
        line([('Mermer', 0, 90), ('2500', 200, 250)], top: 40),
        line([('Granit', 0, 85), ('3200', 200, 250)], top: 80),
      ]);

      expect(table, isNotNull);
      expect(table!.columnCount, 2);
      expect(table.values[1], ['Mermer', '2500']);
    });

    test('eksik hücreli tablo: boş hücre korunur, veri kaybolmaz', () {
      final table = TableDetector.detect([
        line([('Ürün', 0, 60), ('Adet', 200, 260), ('Fiyat', 400, 470)], top: 0),
        line([('Mermer', 0, 90), ('10', 200, 225), ('2500', 400, 450)], top: 40),
        line([('Granit', 0, 85), ('3200', 400, 450)], top: 80),
        line([('Kum', 0, 50), ('7', 200, 212), ('900', 400, 445)], top: 120),
      ]);

      expect(table, isNotNull);
      expect(table!.rowCount, 4);
      expect(table.columnCount, 3);
      expect(table.values[2], ['Granit', '', '3200']);
      expect(table.confidence, greaterThan(0.9));
    });

    test('Türkçe, tarih ve para içeren hücreler bozulmaz', () {
      final table = TableDetector.detect([
        line([('Açıklama', 0, 90), ('Tarih', 250, 310), ('Tutar', 450, 520)], top: 0),
        line([
          ('İşçilik', 0, 70),
          ('02.05.2026', 250, 370),
          ('2.500,50', 450, 545),
        ], top: 40),
        line([
          ('Şirket', 0, 70),
          ('11.09.2026', 250, 370),
          ('12.500', 450, 530),
        ], top: 80),
      ]);

      expect(table, isNotNull);
      expect(table!.values[1], ['İşçilik', '02.05.2026', '2.500,50']);
      expect(table.values[2], ['Şirket', '11.09.2026', '12.500']);
    });

    test('çok kolonlu büyük tablo', () {
      final rows = <OcrLine>[
        line([
          ('Ad', 0, 40),
          ('Tür', 150, 190),
          ('Adet', 300, 345),
          ('Fiyat', 450, 500),
          ('Toplam', 600, 670),
        ], top: 0),
      ];
      for (var index = 1; index <= 7; index++) {
        rows.add(
          line([
            ('Satır$index', 0, 60),
            ('Tür$index', 150, 200),
            ('$index', 300, 315),
            ('${index}00', 450, 490),
            ('${index}000', 600, 650),
          ], top: index * 40),
        );
      }

      final table = TableDetector.detect(rows);
      expect(table, isNotNull);
      expect(table!.rowCount, 8);
      expect(table.columnCount, 5);
    });
  });

  group('Tablo DEĞİL: düz metne fallback (null)', () {
    test('normal paragraf tablo sayılmaz', () {
      final table = TableDetector.detect([
        line([
          ('Bu', 0, 30),
          ('bir', 35, 65),
          ('paragraf', 70, 150),
          ('cümlesidir', 155, 250),
        ], top: 0),
        line([('ikinci', 0, 50), ('satır', 55, 100)], top: 40),
        line([('üçüncü', 0, 60), ('satır', 65, 110), ('burada', 115, 180)], top: 80),
      ]);

      expect(table, isNull);
    });

    test('tek kolonlu liste tablo sayılmaz', () {
      final table = TableDetector.detect([
        line([('Bir', 0, 40)], top: 0),
        line([('İki', 0, 40)], top: 40),
        line([('Üç', 0, 40)], top: 80),
      ]);

      expect(table, isNull);
    });

    test('dağınık/gürültülü yerleşim tablo sayılmaz', () {
      final table = TableDetector.detect([
        line([('A', 0, 20), ('B', 300, 320)], top: 0),
        line([('C', 150, 170)], top: 40),
        line([('D', 0, 20)], top: 80),
        line([('E', 400, 420)], top: 120),
      ]);

      expect(table, isNull);
    });

    test('koordinat yoksa (kelime bilgisi yok) tablo algılanmaz', () {
      final table = TableDetector.detect([
        const OcrLine(text: 'Ürün Adet Fiyat', top: 0, bottom: 20),
        const OcrLine(text: 'Mermer 10 2500', top: 40, bottom: 60),
      ]);

      expect(table, isNull);
    });

    test('boş liste', () => expect(TableDetector.detect(const []), isNull));
  });

  group('Tablo → hizalı metin', () {
    test('kolonlar boşlukla hizalanır', () {
      final table = TableDetector.detect([
        line([('Ürün', 0, 60), ('Adet', 200, 260), ('Fiyat', 400, 470)], top: 0),
        line([
          ('Mermer', 0, 90),
          ('10', 200, 225),
          ('2500', 400, 450),
          ('TL', 460, 480),
        ], top: 40),
        line([
          ('Granit', 0, 80),
          ('5', 200, 212),
          ('3200', 400, 450),
          ('TL', 460, 480),
        ], top: 80),
      ])!;

      expect(table.toAlignedText(), [
        'Ürün    Adet  Fiyat',
        'Mermer  10    2500 TL',
        'Granit  5     3200 TL',
      ].join('\n'));
    });

    test('hücre düzenlemesi tabloyu günceller', () {
      final table = TableDetector.detect([
        line([('Ad', 0, 40), ('Değer', 200, 260)], top: 0),
        line([('Mermer', 0, 90), ('2500', 200, 250)], top: 40),
        line([('Granit', 0, 85), ('3200', 200, 250)], top: 80),
      ])!;

      final edited = table.copyWithCell(1, 1, '9999');
      expect(edited.values[1], ['Mermer', '9999']);
      // Özgün tablo değişmez (değiştirilemez model).
      expect(table.values[1], ['Mermer', '2500']);
    });
  });
}
