import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:metincep/core/errors/app_exception.dart';
import 'package:metincep/models/ocr_table.dart';
import 'package:metincep/services/pdf_export_service.dart';

import '../helpers/temp_dir.dart';
import '../helpers/test_font.dart';

/// A4 dikey ve yatay sayfa kutuları (pdf paketinin yazdığı biçim).
const String portraitBox = '0 0 595.27559 841.88976';
const String landscapeBox = '0 0 841.88976 595.27559';

String asLatin(List<int> bytes) => String.fromCharCodes(bytes);

int countPages(List<int> bytes) => '/MediaBox'.allMatches(asLatin(bytes)).length;

OcrTable buildTable(int columns, int rows, {bool hasHeader = true}) {
  return OcrTable(
    hasHeader: hasHeader,
    confidence: 0.95,
    rows: [
      for (var row = 0; row < rows; row++)
        OcrTableRow([
          for (var column = 0; column < columns; column++)
            OcrTableCell(
              text: row == 0 ? 'Başlık $column' : 'Şirket $row-$column',
            ),
        ]),
    ],
  );
}

void main() {
  late Directory directory;
  late PdfExportService service;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('metincep_pdf_test_');
    service = PdfExportService(
      fontLoader: testFontLoader,
      temporaryDirectoryProvider: () async => directory,
    );
  });

  tearDown(() async {
    await deleteTempDirectory(directory);
  });

  group('Metin → PDF', () {
    test('geçerli PDF üretir ve Türkçe yazı tipini gömer', () async {
      final bytes = await service.buildTextPdf(
        title: 'Fatura 12',
        text: 'Çalışma\nŞirket İstanbul\nÜrün: 2.500,50 TL\nİşçilik %20',
      );

      final text = asLatin(bytes);
      expect(text.startsWith('%PDF-'), isTrue);
      expect(text.trimRight().endsWith('%%EOF'), isTrue);
      // Gömülü TrueType yazı tipi: Türkçe ş/ğ/İ/ı karakterleri için şart.
      expect(text, contains('/FontFile2'));
      expect(countPages(bytes), 1);
      expect(text, contains(portraitBox));
    });

    test('uzun metin birden fazla sayfaya bölünür', () async {
      final longText = List.generate(400, (index) => 'Satır $index: Şirket ödeme kaydı.')
          .join('\n');
      final bytes = await service.buildTextPdf(title: 'Uzun', text: longText);

      expect(countPages(bytes), greaterThan(1));
    });

    test('boş metin PDF üretmez', () async {
      await expectLater(
        service.buildTextPdf(title: 'Boş', text: '   \n  '),
        throwsA(
          isA<AppException>().having(
            (error) => error.message,
            'mesaj',
            ErrorMessages.pdfEmptyContent,
          ),
        ),
      );
    });

    test('başlık boşsa da PDF üretilir', () async {
      final bytes = await service.buildTextPdf(title: '', text: 'İçerik');
      expect(countPages(bytes), 1);
    });
  });

  group('Tablo → PDF', () {
    test('3 kolonlu tablo dikey sayfaya basılır', () async {
      final bytes = await service.buildTablePdf(
        title: 'Tablo',
        table: buildTable(3, 4),
      );

      final text = asLatin(bytes);
      expect(text.startsWith('%PDF-'), isTrue);
      expect(text, contains(portraitBox));
      expect(countPages(bytes), 1);
    });

    test('geniş tablo yatay sayfaya basılır', () async {
      final bytes = await service.buildTablePdf(
        title: 'Geniş tablo',
        table: buildTable(6, 4),
      );

      expect(asLatin(bytes), contains(landscapeBox));
    });

    test('uzun tablo birden fazla sayfaya bölünür', () async {
      final bytes = await service.buildTablePdf(
        title: 'Uzun tablo',
        table: buildTable(3, 120),
      );

      expect(countPages(bytes), greaterThan(1));
    });

    test('boş tablo PDF üretmez', () async {
      await expectLater(
        service.buildTablePdf(
          title: 'Boş',
          table: const OcrTable(rows: [], confidence: 0.9),
        ),
        throwsA(isA<AppException>()),
      );
    });
  });

  group('Fotoğraf → PDF', () {
    String writeImage(String name, {required int width, required int height}) {
      final image = img.Image(width: width, height: height);
      img.fill(image, color: img.ColorRgb8(200, 200, 200));
      final path = '${directory.path}${Platform.pathSeparator}$name';
      File(path).writeAsBytesSync(img.encodeJpg(image, quality: 85));
      return path;
    }

    test('tek fotoğraf tek sayfa olur, dikey oran korunur', () async {
      final path = writeImage('dikey.jpg', width: 600, height: 900);
      final bytes = await service.buildImagesPdf(imagePaths: [path]);

      expect(countPages(bytes), 1);
      expect(asLatin(bytes), contains(portraitBox));
    });

    test('yatay fotoğraf yatay sayfaya basılır', () async {
      final path = writeImage('yatay.jpg', width: 900, height: 600);
      final bytes = await service.buildImagesPdf(imagePaths: [path]);

      expect(asLatin(bytes), contains(landscapeBox));
    });

    test('çoklu fotoğraf tek PDF içinde sırayla sayfalanır', () async {
      final paths = [
        writeImage('bir.jpg', width: 600, height: 900),
        writeImage('iki.jpg', width: 600, height: 900),
        writeImage('uc.jpg', width: 900, height: 600),
      ];
      final bytes = await service.buildImagesPdf(imagePaths: paths);

      expect(countPages(bytes), 3);
      final text = asLatin(bytes);
      expect(text, contains(portraitBox));
      expect(text, contains(landscapeBox));
    });

    test('büyük fotoğraf küçültülür (dosya makul kalır)', () async {
      final path = writeImage('buyuk.jpg', width: 4000, height: 3000);
      final bytes = await service.buildImagesPdf(imagePaths: [path]);

      expect(countPages(bytes), 1);
      expect(bytes.length, lessThan(3 * 1024 * 1024));
    });

    test('fotoğraf listesi boşsa PDF üretilmez', () async {
      await expectLater(
        service.buildImagesPdf(imagePaths: const []),
        throwsA(isA<AppException>()),
      );
    });

    test('okunamayan fotoğrafta anlaşılır hata verir', () async {
      final broken = '${directory.path}${Platform.pathSeparator}bozuk.jpg';
      File(broken).writeAsBytesSync(const [9, 9, 9]);

      await expectLater(
        service.buildImagesPdf(imagePaths: [broken]),
        throwsA(
          isA<AppException>().having(
            (error) => error.message,
            'mesaj',
            ErrorMessages.pdfImageReadFailed,
          ),
        ),
      );
    });
  });

  group('Dosya yazma', () {
    test('geçici PDF dosyası yazılır', () async {
      final bytes = await service.buildTextPdf(title: 'Kayıt', text: 'İçerik');
      final file = await service.writeTemporaryFile(bytes, fileName: 'Fatura 12');

      expect(file.existsSync(), isTrue);
      expect(file.path.endsWith('.pdf'), isTrue);
      expect(file.lengthSync(), bytes.length);
    });

    test('dosya adı güvenli hale getirilir', () {
      final name = PdfExportService.suggestedFileName('Fatura: 12/2026');
      expect(name, contains('Fatura_ 12_2026'));
      expect(name.contains('/'), isFalse);
    });
  });
}
