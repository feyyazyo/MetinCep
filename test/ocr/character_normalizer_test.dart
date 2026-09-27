import 'package:flutter_test/flutter_test.dart';
import 'package:metincep/core/utils/character_normalizer.dart';

void main() {
  String fix(String input, {double? confidence}) =>
      CharacterNormalizer.normalizeText(input, confidence: confidence).text;

  group('Kelime içi rakam/harf hatası düzeltilir', () {
    test('ME2AR → MEZAR', () => expect(fix('ME2AR'), 'MEZAR'));

    test('5ELAM → SELAM', () => expect(fix('5ELAM'), 'SELAM'));

    test('İ5TANBUL → İSTANBUL', () => expect(fix('İ5TANBUL'), 'İSTANBUL'));

    test('küçük harfli kelimede küçük harf kullanılır', () {
      expect(fix('me2ar'), 'mezar');
      expect(fix('se5lam'), 'seslam');
    });

    test('cümle içinde yalnızca kelime düzeltilir, sayı korunur', () {
      expect(fix('ME2AR TAŞI 2500 TL'), 'MEZAR TAŞI 2500 TL');
    });

    test('noktalama ve satır yapısı korunur', () {
      expect(fix('ME2AR.'), 'MEZAR.');
      expect(fix('(5ELAM)'), '(SELAM)');
      expect(fix('ME2AR\n5ELAM'), 'MEZAR\nSELAM');
      expect(fix('  ME2AR   5ELAM  '), '  MEZAR   SELAM  ');
    });

    test('düzeltme raporu doğru', () {
      final result = CharacterNormalizer.normalizeText('ME2AR ve 5ELAM');
      expect(result.changeCount, 2);
      expect(result.hasChanges, isTrue);
      expect(result.changes.first.before, 'ME2AR');
      expect(result.changes.first.after, 'MEZAR');
      expect(result.text, 'MEZAR ve SELAM');
    });
  });

  group('Sayı, tarih, telefon, para ve kod KORUNUR', () {
    const protected = <String>[
      '2025',
      '1250',
      '2500',
      '02.05.2026',
      '11/09/2026',
      '15:25',
      '5551234567',
      '0555 123 45 67',
      '2500 TL',
      '12.500,50',
      '%20',
      '3,25',
      'A2B5C9',
      'ABC-2025-5',
      'TR520006',
      'info@site5.com',
      'PLAKA25ABC',
      'Z2',
      '25',
    ];

    for (final input in protected) {
      test('"$input" değişmez', () => expect(fix(input), input));
    }

    test('Türkçe harfler hiç değişmez', () {
      const turkish = 'ÇALIŞMA Şirket İstanbul Ürün Ödeme İşçilik çğıöşü';
      expect(fix(turkish), turkish);
    });

    test('rakam kümesi kelimeye dönüştürülmez', () {
      // "2" ve "5" yan yana: komşusu harf olmadığı için dokunulmaz.
      expect(fix('KOD25'), 'KOD25');
      expect(fix('25KOD'), '25KOD');
    });
  });

  group('Güven değeri', () {
    test('düşük güvende ham metin korunur', () {
      expect(fix('ME2AR', confidence: 0.2), 'ME2AR');
      expect(
        CharacterNormalizer.normalizeText('ME2AR', confidence: 0.2).changeCount,
        0,
      );
    });

    test('yüksek güvende düzeltme yapılır', () {
      expect(fix('ME2AR', confidence: 0.95), 'MEZAR');
    });

    test('güven bilinmiyorsa düzeltme yapılır', () {
      expect(fix('ME2AR'), 'MEZAR');
    });
  });

  group('Sınır durumları', () {
    test('boş metin', () {
      expect(fix(''), '');
      expect(CharacterNormalizer.normalizeText('').changeCount, 0);
    });

    test('yalnızca boşluk', () => expect(fix('   \n  '), '   \n  '));

    test('düzeltilecek rakam yoksa metin aynı nesne değeriyle döner', () {
      const text = 'Normal bir cümle.';
      final result = CharacterNormalizer.normalizeText(text);
      expect(result.text, text);
      expect(result.hasChanges, isFalse);
    });

    test('harf/rakam sınıflandırması', () {
      expect(CharacterNormalizer.isLetter('ş'), isTrue);
      expect(CharacterNormalizer.isLetter('İ'), isTrue);
      expect(CharacterNormalizer.isLetter('5'), isFalse);
      expect(CharacterNormalizer.isDigit('5'), isTrue);
      expect(CharacterNormalizer.isDigit('S'), isFalse);
    });
  });
}
