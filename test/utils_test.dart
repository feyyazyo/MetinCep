import 'package:flutter_test/flutter_test.dart';
import 'package:metincep/core/utils/date_formatter.dart';
import 'package:metincep/core/utils/file_name_utils.dart';
import 'package:metincep/core/utils/pdf_render_sizing.dart';
import 'package:metincep/core/utils/search_utils.dart';
import 'package:metincep/core/utils/text_stats.dart';

void main() {
  group('DateFormatter', () {
    final date = DateTime(2026, 9, 11, 14, 5);

    test('Türkçe tarih biçimleri', () {
      expect(DateFormatter.long(date), '11 Eylül 2026');
      expect(DateFormatter.longWithTime(date), '11 Eylül 2026, 14:05');
      expect(DateFormatter.short(date), '11.09.2026');
      expect(DateFormatter.fileStamp(date), '20260911_1405');
    });

    test('varsayılan belge başlığı', () {
      expect(DateFormatter.defaultDocumentTitle(date), 'Belge - 11.09.2026');
    });
  });

  group('FileNameUtils', () {
    test('geçersiz karakterleri temizler', () {
      expect(FileNameUtils.sanitize('Fatura: 12/2026?'), 'Fatura_ 12_2026_');
      expect(FileNameUtils.sanitize('rapor...'), 'rapor');
      expect(FileNameUtils.sanitize('  Çok   boşluklu  ad '), 'Çok boşluklu ad');
    });

    test('boş ad için yedek ad kullanır', () {
      expect(FileNameUtils.sanitize('   '), 'MetinCep');
    });

    test('çok uzun adı kısaltır', () {
      expect(FileNameUtils.sanitize('a' * 200).length, 80);
    });

    test('uzantıyı kaldırır', () {
      expect(FileNameUtils.withoutExtension('fatura.pdf'), 'fatura');
      expect(FileNameUtils.withoutExtension('arsiv.tar.gz'), 'arsiv.tar');
      expect(FileNameUtils.withoutExtension('.gizli'), '.gizli');
      expect(FileNameUtils.withoutExtension('belge'), 'belge');
    });
  });

  group('PdfRenderSizing', () {
    test('A4 sayfa 200 DPI civarında çizilir', () {
      final size = PdfRenderSizing.forPage(595, 842);
      expect(size.width, 1653);
      expect(size.height, 2339);
    });

    test('büyük sayfa RAM için sınırlandırılır', () {
      final size = PdfRenderSizing.forPage(2000, 3000);
      expect(size.width, 1600);
      expect(size.height, 2400);
    });

    test('küçük sayfa OCR için büyütülür', () {
      final size = PdfRenderSizing.forPage(100, 200);
      expect(size.width, 700);
      expect(size.height, 1400);
    });

    test('geçersiz boyutta A4 varsayılır', () {
      final size = PdfRenderSizing.forPage(0, 0);
      expect(size.width, 1653);
      expect(size.height, 2339);
    });
  });

  group('SearchUtils', () {
    test('Türkçe harfleri ve büyük/küçük harfi eşitler', () {
      expect(SearchUtils.fold('ŞİRKET'), 'sirket');
      expect(SearchUtils.fold('Şirket'), 'sirket');
      expect(SearchUtils.fold('İSTANBUL'), 'istanbul');
      expect(SearchUtils.fold('IŞIK'), SearchUtils.fold('ışık'));
      expect(SearchUtils.fold('ÖDEME Ürün Çğ'), 'odeme urun cg');
      expect(SearchUtils.fold('  Çok   boşluk '), 'cok bosluk');
    });

    test('tüm kelimeler geçiyorsa eşleşir', () {
      expect(SearchUtils.matches('sirket fatura', ['ABC Şirketi', 'FATURA No 12']), isTrue);
      expect(SearchUtils.matches('mermer', ['Fatura']), isFalse);
      expect(SearchUtils.matches('   ', ['Fatura']), isTrue);
    });
  });

  group('TextStats', () {
    test('karakter ve kelime sayar', () {
      expect(TextStats.of('').characters, 0);
      expect(TextStats.of('').words, 0);
      expect(TextStats.of('Merhaba dünya').characters, 13);
      expect(TextStats.of('Merhaba dünya').words, 2);
      expect(TextStats.of('  a\n\nb  ').words, 2);
      expect(TextStats.of('Çalışma\nŞirket').characters, 14);
    });

    test('emoji tek karakter sayılır', () {
      final stats = TextStats.of('😀 ok');
      expect(stats.characters, 4);
      expect(stats.words, 2);
    });

    test('binlik ayırıcı ile biçimlendirir', () {
      expect(TextStats.formatCount(0), '0');
      expect(TextStats.formatCount(999), '999');
      expect(TextStats.formatCount(1000), '1.000');
      expect(TextStats.formatCount(12500), '12.500');
      expect(TextStats.formatCount(1234567), '1.234.567');
    });
  });
}
