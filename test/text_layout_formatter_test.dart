import 'package:flutter_test/flutter_test.dart';
import 'package:metincep/core/utils/text_layout_formatter.dart';

void main() {
  group('TextLayoutFormatter.formatBlocks', () {
    test('satırları korur, yakın blokları tek satırla, uzak blokları paragrafla ayırır', () {
      const blocks = [
        OcrBlock([
          OcrLine(text: 'Fatura No: 12', top: 0, bottom: 20),
          OcrLine(text: 'Tarih: 11/09/2026', top: 24, bottom: 44),
        ]),
        OcrBlock([OcrLine(text: 'Toplam: 12.500 TL', top: 50, bottom: 70)]),
        OcrBlock([OcrLine(text: 'Teşekkürler', top: 120, bottom: 140)]),
      ];

      expect(
        TextLayoutFormatter.formatBlocks(blocks),
        'Fatura No: 12\nTarih: 11/09/2026\nToplam: 12.500 TL\n\nTeşekkürler',
      );
    });

    test('Türkçe karakterlere, sayılara ve noktalamaya dokunmaz', () {
      const lines = ['Çalışma', 'Şirket', 'İstanbul', 'Ürün', 'Ödeme', 'İşçilik',
          '12.500 TL', '%20', '11/09/2026', '3,25 m²'];
      final blocks = [
        OcrBlock([
          for (var i = 0; i < lines.length; i++)
            OcrLine(text: lines[i], top: i * 22.0, bottom: i * 22.0 + 20),
        ]),
      ];

      expect(TextLayoutFormatter.formatBlocks(blocks), lines.join('\n'));
    });

    test('boş satırları ve boş blokları atlar', () {
      const blocks = [
        OcrBlock([OcrLine(text: '   ', top: 0, bottom: 10)]),
        OcrBlock([]),
        OcrBlock([OcrLine(text: ' Merhaba ', top: 12, bottom: 30)]),
      ];

      expect(TextLayoutFormatter.formatBlocks(blocks), 'Merhaba');
    });

    test('blok yoksa boş metin döner', () {
      expect(TextLayoutFormatter.formatBlocks(const []), '');
    });
  });

  group('TextLayoutFormatter.normalize', () {
    test('satır sonlarını birleştirir ve fazla boş satırları azaltır', () {
      expect(
        TextLayoutFormatter.normalize('Çalışma  \r\nŞirket\n\n\n\nİstanbul\n'),
        'Çalışma\nŞirket\n\nİstanbul',
      );
    });
  });

  group('TextLayoutFormatter.joinSections', () {
    test('tek bölümde başlık eklemez', () {
      expect(
        TextLayoutFormatter.joinSections(sections: const [' Metin '], label: 'Sayfa'),
        'Metin',
      );
    });

    test('çok sayfada "Sayfa N" başlıkları ekler, boş sayfayı belirtir', () {
      expect(
        TextLayoutFormatter.joinSections(sections: const ['A', '', 'C'], label: 'Sayfa'),
        'Sayfa 1\nA\n\nSayfa 2\n(Bu bölümde metin bulunamadı)\n\nSayfa 3\nC',
      );
    });

    test('bölüm yoksa boş döner', () {
      expect(TextLayoutFormatter.joinSections(sections: const [], label: 'Sayfa'), '');
    });
  });

  test('visibleCharCount boşlukları saymaz', () {
    expect(TextLayoutFormatter.visibleCharCount('a b\n\tç'), 3);
  });
}
