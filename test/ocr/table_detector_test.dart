import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:metincep/core/utils/table_detector.dart';
import 'package:metincep/core/utils/text_layout_formatter.dart';
import 'package:metincep/models/table_grid_lines.dart';

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

/// Eğik çekilmiş fotoğraf benzetimi: her kelimenin dikey konumu
/// yatay konumuna bağlı olarak kayar (skew = tan(açı)).
OcrLine skewedLine(
  List<(String, double, double)> words, {
  required double top,
  required double skew,
  double height = 20,
}) {
  final ocrWords = words.map((word) {
    final shift = skew * word.$2;
    return OcrWord(
      text: word.$1,
      left: word.$2,
      right: word.$3,
      top: top + shift,
      bottom: top + shift + height,
    );
  }).toList();
  return OcrLine(
    text: ocrWords.map((word) => word.text).join(' '),
    top: ocrWords.first.top,
    bottom: ocrWords.first.bottom,
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

  group('Gerçek fotoğraf koşulları', () {
    test('eğik çekilmiş tablo (2.5°) satırlara doğru bölünür', () {
      final skew = math.tan(2.5 * math.pi / 180);
      final table = TableDetector.detect([
        skewedLine([('Ürün', 0, 60), ('Adet', 200, 260), ('Fiyat', 400, 470)],
            top: 0, skew: skew),
        skewedLine([('Mermer', 0, 90), ('10', 200, 225), ('2500', 400, 450)],
            top: 40, skew: skew),
        skewedLine([('Granit', 0, 85), ('5', 200, 212), ('3200', 400, 450)],
            top: 80, skew: skew),
        skewedLine([('Kum', 0, 50), ('7', 200, 212), ('900', 400, 445)],
            top: 120, skew: skew),
      ]);

      expect(table, isNotNull, reason: 'eğik fotoğrafta da tablo bulunmalı');
      // Eğim düzeltmesi olmasa satırlar parçalanır ve 4'ten fazla satır çıkar.
      expect(table!.rowCount, 4);
      expect(table.columnCount, 3);
      expect(table.values[1], ['Mermer', '10', '2500']);
    });

    test('satır eğimi tahmini gerçek eğime yakın', () {
      final skew = math.tan(3 * math.pi / 180);
      final words = <OcrWord>[];
      for (var row = 0; row < 4; row++) {
        for (var column = 0; column < 4; column++) {
          final left = column * 200.0;
          final top = row * 45.0 + skew * left;
          words.add(
            OcrWord(text: 'x', left: left, right: left + 60, top: top, bottom: top + 20),
          );
        }
      }
      final estimated = TableDetector.estimateSlope(words, 20);
      expect((estimated - skew).abs(), lessThan(0.015),
          reason: 'eğim ±0.015 (≈0.9°) içinde bulunmalı');
    });

    test('sağa dayalı fiyat kolonu tek kolon sayılır', () {
      // Fişlerde tutarlar sağa dayalıdır: sol kenarlar satırdan satıra kayar.
      // Sol kenar kümelemesi bunu birden çok kolon sanardı.
      final table = TableDetector.detect([
        line([('Ürün', 0, 60), ('Tutar', 300, 380)], top: 0),
        line([('Ekmek', 0, 70), ('15', 340, 380)], top: 40),
        line([('Süt', 0, 45), ('42,50', 300, 380)], top: 80),
        line([('Peynir', 0, 75), ('128', 320, 380)], top: 120),
      ]);

      expect(table, isNotNull);
      expect(table!.columnCount, 2, reason: 'sağa dayalı kolon bölünmemeli');
      expect(table.values[1], ['Ekmek', '15']);
      expect(table.values[3], ['Peynir', '128']);
    });

    test('tam genişlikteki başlık satırı kolonlara bölünmez', () {
      final table = TableDetector.detect([
        line([('MERMER', 0, 100), ('FIYAT', 110, 190), ('LISTESI', 200, 300)], top: 0),
        line([('Ürün', 0, 60), ('Adet', 400, 460), ('Fiyat', 700, 770)], top: 40),
        line([('Mermer', 0, 90), ('10', 400, 425), ('2500', 700, 750)], top: 80),
        line([('Granit', 0, 85), ('5', 400, 412), ('3200', 700, 750)], top: 120),
        line([('Kum', 0, 50), ('7', 400, 412), ('900', 700, 745)], top: 160),
      ]);

      expect(table, isNotNull);
      expect(table!.columnCount, 3);
      // Başlık tek hücrede kalır: cümle kolonlara parçalanmaz.
      expect(table.values.first.first, 'MERMER FIYAT LISTESI');
      expect(table.values.first[1], isEmpty);
    });

    test('4 kolonlu tablo (Birim Fiyat gibi çok kelimeli başlık)', () {
      final table = TableDetector.detect([
        line([
          ('Ürün', 0, 60),
          ('Adet', 250, 310),
          ('Birim', 500, 560),
          ('Fiyat', 565, 625),
          ('Toplam', 800, 890),
        ], top: 0),
        line([
          ('Mermer', 0, 90),
          ('10', 250, 275),
          ('250', 500, 545),
          ('2500', 800, 860),
        ], top: 40),
        line([
          ('Granit', 0, 85),
          ('5', 250, 262),
          ('640', 500, 545),
          ('3200', 800, 860),
        ], top: 80),
      ]);

      expect(table, isNotNull);
      expect(table!.columnCount, 4);
      expect(table.values.first[2], 'Birim Fiyat');
      expect(table.values[1], ['Mermer', '10', '250', '2500']);
    });

    test('her iki kolonda çok kelimeli hücreler', () {
      final table = TableDetector.detect([
        line([('Ürün', 0, 60), ('Adı', 65, 105), ('Tutar', 400, 470)], top: 0),
        line([
          ('Beyaz', 0, 60),
          ('Mermer', 65, 140),
          ('2500', 400, 450),
          ('TL', 460, 480),
        ], top: 40),
        line([
          ('Siyah', 0, 55),
          ('Granit', 60, 130),
          ('3200', 400, 450),
          ('TL', 460, 480),
        ], top: 80),
      ]);

      expect(table, isNotNull);
      expect(table!.columnCount, 2);
      expect(table.values[1], ['Beyaz Mermer', '2500 TL']);
      expect(table.values[2], ['Siyah Granit', '3200 TL']);
    });

    test('uzun tablo (12 satır) tamamen okunur', () {
      final rows = <OcrLine>[
        line([('Ürün', 0, 60), ('Adet', 200, 260), ('Fiyat', 400, 470)], top: 0),
      ];
      for (var index = 1; index <= 11; index++) {
        rows.add(
          line([
            ('Kalem$index', 0, 90),
            ('$index', 200, 220),
            ('${index}00', 400, 450),
          ], top: index * 40),
        );
      }
      final table = TableDetector.detect(rows);
      expect(table, isNotNull);
      expect(table!.rowCount, 12);
      expect(table.columnCount, 3);
      expect(table.values.last, ['Kalem11', '11', '1100']);
    });
  });

  group('Çizgi ipuçları', () {
    List<OcrLine> borderedRows() => [
          line([('Ürün', 40, 130), ('Adet', 240, 320), ('Fiyat', 420, 500)], top: 0),
          line([('Mermer', 40, 150), ('10', 240, 265), ('2500', 420, 480)], top: 40),
          line([('Granit', 40, 145), ('5', 240, 252), ('3200', 420, 480)], top: 80),
        ];

    test('çizgiler kolon sınırlarını doğrular ve güveni artırır', () {
      final withoutLines = TableDetector.analyze(borderedRows());
      final withLines = TableDetector.analyze(
        borderedRows(),
        gridLines: const TableGridLines(
          horizontal: [-10, 30, 70, 110],
          vertical: [30, 200, 380, 520],
        ),
      );

      expect(withoutLines.isTable, isTrue);
      expect(withLines.isTable, isTrue);
      expect(withLines.table!.columnCount, 3);
      expect(withLines.confidence, greaterThan(withoutLines.confidence),
          reason: 'çizgi kanıtı güveni yükseltmeli');
    });

    test('kelime geometrisiyle çelişen çizgiler yok sayılır', () {
      // Dikey "çizgiler" kelimelerin tam üstünden geçiyor: güvenilmez.
      final result = TableDetector.analyze(
        borderedRows(),
        gridLines: const TableGridLines(vertical: [100, 260, 450]),
      );

      expect(result.isTable, isTrue);
      // Geometriden gelen 3 kolon korunur; çizgiler tabloyu bozmaz.
      expect(result.table!.columnCount, 3);
      expect(result.table!.values[1], ['Mermer', '10', '2500']);
    });
  });

  group('Tablo algılanamadı bilgisi', () {
    test('yapı tabloya benziyor ama eşiği geçmiyorsa yakın kaçırma bildirilir', () {
      // Üç satır, iki kolon; ama hücrelerin yarısı boş ve hizalama bozuk.
      final result = TableDetector.analyze([
        line([('A', 0, 30), ('123', 300, 350)], top: 0),
        line([('B', 60, 95)], top: 40),
        line([('C', 10, 45), ('456', 280, 330)], top: 80),
        line([('D', 90, 130)], top: 120),
      ]);

      expect(result.isTable, isFalse);
      expect(result.table, isNull);
      if (result.reason == TableRejectionReason.lowConfidence) {
        expect(result.confidence, lessThan(TableDetector.minConfidence));
      }
    });

    test('düz paragrafta yakın kaçırma bildirilmez', () {
      final result = TableDetector.analyze([
        line([('Bu', 0, 30), ('bir', 35, 65), ('paragraf', 70, 150)], top: 0),
        line([('ikinci', 0, 50), ('satır', 55, 100)], top: 40),
        line([('üçüncü', 0, 60), ('satır', 65, 110)], top: 80),
      ]);

      expect(result.isTable, isFalse);
      expect(result.isNearMiss, isFalse,
          reason: 'normal metinde kullanıcıya tablo mesajı gösterilmemeli');
    });

    test('kolon bulunamazsa neden kolon eksikliği olarak bildirilir', () {
      final result = TableDetector.analyze([
        line([('Tek', 0, 40), ('kolon', 45, 100)], top: 0),
        line([('ikinci', 0, 55), ('satır', 60, 110)], top: 40),
      ]);

      expect(result.reason, TableRejectionReason.tooFewColumns);
    });
  });

  group('OCR güveni', () {
    test('düşük OCR güveni tablo puanını düşürür', () {
      List<OcrLine> rows(double? confidence) => [
            OcrLine(
              text: 'Ürün Fiyat',
              top: 0,
              bottom: 20,
              words: [
                OcrWord(
                    text: 'Ürün',
                    left: 0,
                    right: 60,
                    top: 0,
                    bottom: 20,
                    confidence: confidence),
                OcrWord(
                    text: 'Fiyat',
                    left: 200,
                    right: 260,
                    top: 0,
                    bottom: 20,
                    confidence: confidence),
              ],
            ),
            OcrLine(
              text: 'Mermer 2500',
              top: 40,
              bottom: 60,
              words: [
                OcrWord(
                    text: 'Mermer',
                    left: 0,
                    right: 90,
                    top: 40,
                    bottom: 60,
                    confidence: confidence),
                OcrWord(
                    text: '2500',
                    left: 200,
                    right: 250,
                    top: 40,
                    bottom: 60,
                    confidence: confidence),
              ],
            ),
            OcrLine(
              text: 'Granit 3200',
              top: 80,
              bottom: 100,
              words: [
                OcrWord(
                    text: 'Granit',
                    left: 0,
                    right: 85,
                    top: 80,
                    bottom: 100,
                    confidence: confidence),
                OcrWord(
                    text: '3200',
                    left: 200,
                    right: 250,
                    top: 80,
                    bottom: 100,
                    confidence: confidence),
              ],
            ),
          ];

      final high = TableDetector.analyze(rows(1.0));
      final low = TableDetector.analyze(rows(0.2));
      final unknown = TableDetector.analyze(rows(null));

      expect(high.isTable, isTrue);
      expect(unknown.isTable, isTrue);
      expect(low.confidence, lessThan(high.confidence));
      // Güven tek başına tabloyu yok etmez: yapı sağlamsa yine tablo çıkar.
      expect(low.isTable, isTrue);
    });
  });
}
