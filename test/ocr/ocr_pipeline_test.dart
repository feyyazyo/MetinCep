import 'package:flutter_test/flutter_test.dart';
import 'package:metincep/core/utils/text_layout_formatter.dart';
import 'package:metincep/services/ocr_pipeline.dart';
import 'package:metincep/services/ocr_service.dart';

OcrLine line(
  List<(String, double, double)> words, {
  required double top,
  double? confidence,
}) {
  final ocrWords = words
      .map(
        (word) => OcrWord(
          text: word.$1,
          left: word.$2,
          right: word.$3,
          top: top,
          bottom: top + 20,
          confidence: confidence,
        ),
      )
      .toList();
  return OcrLine(
    text: ocrWords.map((word) => word.text).join(' '),
    top: top,
    bottom: top + 20,
    left: ocrWords.first.left,
    right: ocrWords.last.right,
    confidence: confidence,
    words: ocrWords,
  );
}

OcrPage page(List<OcrLine> lines, {double? averageConfidence}) => OcrPage(
      blocks: [OcrBlock(lines)],
      rawText: lines.map((line) => line.text).join('\n'),
      averageConfidence: averageConfidence,
    );

void main() {
  const pipeline = OcrPipeline();

  test('ham metin ve düzeltilmiş metin ayrı tutulur', () {
    final result = pipeline.process(
      page([
        line([('ME2AR', 0, 80), ('TAŞI', 90, 160)], top: 0),
        line([('2500', 0, 60), ('TL', 70, 100)], top: 40),
      ]),
    );

    expect(result.rawText, 'ME2AR TAŞI\n2500 TL');
    expect(result.text, 'MEZAR TAŞI\n2500 TL');
    expect(result.normalizationCount, 1);
    expect(result.changes.single.before, 'ME2AR');
  });

  test('tablo algılanır ve hücreler de düzeltilmiş metni içerir', () {
    final result = pipeline.process(
      page([
        line([('Ürün', 0, 60), ('Adet', 200, 260), ('Fiyat', 400, 470)], top: 0),
        line([('ME2AR', 0, 90), ('10', 200, 225), ('2500', 400, 450)], top: 40),
        line([('Granit', 0, 85), ('5', 200, 212), ('3200', 400, 450)], top: 80),
      ]),
    );

    final table = result.table;
    expect(table, isNotNull);
    expect(table!.columnCount, 3);
    // Hücre metni ile düzenleyicideki metin tutarlı olmalı.
    expect(table.values[1], ['MEZAR', '10', '2500']);
    expect(result.text, contains('MEZAR'));
    expect(result.rawText, contains('ME2AR'));
  });

  test('tablo yoksa table null kalır, metin yine üretilir', () {
    final result = pipeline.process(
      page([
        line([('Bu', 0, 30), ('bir', 35, 70), ('cümledir', 75, 160)], top: 0),
        line([('ikinci', 0, 60), ('satır', 65, 120)], top: 40),
      ]),
    );

    expect(result.table, isNull);
    expect(result.text, 'Bu bir cümledir\nikinci satır');
  });

  test('düşük güvenli satırda ham metin korunur', () {
    final result = pipeline.process(
      page([
        line([('ME2AR', 0, 80)], top: 0, confidence: 0.1),
        line([('5ELAM', 0, 80)], top: 40, confidence: 0.9),
      ]),
    );

    expect(result.text, 'ME2AR\nSELAM');
    expect(result.normalizationCount, 1);
  });

  test('koordinatsız sayfada yalnızca metin normalizasyonu yapılır', () {
    final result = pipeline.process(
      const OcrPage(blocks: [], rawText: 'ME2AR TAŞI'),
    );

    expect(result.text, 'MEZAR TAŞI');
    expect(result.rawText, 'ME2AR TAŞI');
    expect(result.table, isNull);
  });

  test('boş sayfa boş sonuç verir', () {
    final result = pipeline.process(OcrPage.empty);
    expect(result.isEmpty, isTrue);
    expect(result.text, '');
    expect(result.table, isNull);
  });
}
