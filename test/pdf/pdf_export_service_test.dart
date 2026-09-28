import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:metincep/core/errors/app_exception.dart';
import 'package:metincep/models/ocr_table.dart';
import 'package:metincep/models/searchable_page.dart';
import 'package:metincep/services/pdf_export_service.dart';

import '../helpers/pdf_inspect.dart';
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

  group('Metin PDF / Fotoğraf PDF ayrımı', () {
    String writeGrayImage(String name, {int width = 600, int height = 800}) {
      final image = img.Image(width: width, height: height);
      img.fill(image, color: img.ColorRgb8(210, 210, 210));
      final path = '${directory.path}${Platform.pathSeparator}$name';
      File(path).writeAsBytesSync(img.encodeJpg(image, quality: 85));
      return path;
    }

    test('metin PDF\'i gömülü FOTOĞRAF içermez (seçilebilir metin)', () async {
      final bytes = await service.buildTextPdf(
        title: 'Kapı Yazısı',
        text: 'AHMET\n12.05.2026\n3500 TL',
      );
      final content = asLatin(bytes);

      // Gömülü yazı tipi var: metin gerçek metin olarak yazılmış.
      expect(content, contains('/FontFile2'));
      // Görüntü nesnesi YOK: fotoğrafın kendisi PDF'e konmamış.
      // pdf paketi sayfa kaynaklarına /XObject sözlüğünü YALNIZCA görüntü
      // varsa yazar; metin PDF'inde hiç bulunmaz.
      expect(content.contains('/XObject'), isFalse);
      expect(content.contains('/Subtype/Image'), isFalse);
    });

    test('tablo PDF\'i de gömülü fotoğraf içermez', () async {
      final bytes = await service.buildTablePdf(
        title: 'Fiyat Listesi',
        table: buildTable(3, 4),
      );
      final content = asLatin(bytes);

      expect(content, contains('/FontFile2'));
      expect(content.contains('/XObject'), isFalse);
    });

    test('fotoğraf PDF\'i gömülü fotoğraf İÇERİR', () async {
      final bytes = await service.buildImagesPdf(
        imagePaths: [writeGrayImage('sayfa.jpg')],
      );
      final content = asLatin(bytes);

      // Bu akış bilinçli olarak fotoğrafın kendisini sayfaya koyar.
      // /XObject sözlüğü sayfa kaynaklarında düz metin olarak yazılır.
      expect(content.contains('/XObject'), isTrue);
      expect(countPages(bytes), 1);
    });

    test('aynı içerik iki modda farklı PDF üretir', () async {
      final imagePath = writeGrayImage('ayni.jpg');
      final imagePdf = await service.buildImagesPdf(imagePaths: [imagePath]);
      final textPdf = await service.buildTextPdf(
        title: 'Aynı belge',
        text: 'Fotoğraftan çıkarılan metin',
      );

      expect(asLatin(imagePdf).contains('/XObject'), isTrue);
      expect(asLatin(textPdf).contains('/XObject'), isFalse);
      expect(asLatin(textPdf), contains('/FontFile2'));
    });
  });

  group('Aranabilir PDF (fotoğraf + görünmez metin)', () {
    String writePhoto(String name, {int width = 600, int height = 800}) {
      final image = img.Image(width: width, height: height);
      img.fill(image, color: img.ColorRgb8(215, 215, 215));
      img.fillRect(image, x1: 60, y1: 100, x2: 540, y2: 140,
          color: img.ColorRgb8(30, 30, 30));
      final path = '${directory.path}${Platform.pathSeparator}$name';
      File(path).writeAsBytesSync(img.encodeJpg(image, quality: 85));
      return path;
    }

    SearchablePage pageFor(String path) => SearchablePage(
          imagePath: path,
          words: const [
            SearchableWord(
                text: 'MEZAR', left: 0.10, top: 0.125, right: 0.45, bottom: 0.175),
            SearchableWord(
                text: 'TAŞI', left: 0.50, top: 0.125, right: 0.75, bottom: 0.175),
            SearchableWord(
                text: '11', left: 0.10, top: 0.300, right: 0.20, bottom: 0.345),
            SearchableWord(
                text: 'Adet', left: 0.24, top: 0.300, right: 0.46, bottom: 0.345),
          ],
        );

    test('hem fotoğrafı hem gerçek metni içerir', () async {
      final bytes = await service.buildSearchablePdf(
        pages: [pageFor(writePhoto('not.jpg'))],
        title: 'El yazısı not',
      );
      final content = asLatin(bytes);

      // Fotoğraf sayfada: /XObject var.
      expect(content.contains('/XObject'), isTrue, reason: 'fotoğraf konmalı');
      // Metin de gerçek metin olarak var: gömülü yazı tipi.
      expect(content, contains('/FontFile2'));
      expect(countPages(bytes), 1);
    });

    test('metin görünmez çizilir (saydamlık durumu kullanılır)', () async {
      final bytes = await service.buildSearchablePdf(
        pages: [pageFor(writePhoto('gorunmez.jpg'))],
      );
      final content = asLatin(bytes);
      final stream = inflatedStreams(bytes);

      // Saydamlık, grafik durumu (ExtGState) ile verilir.
      expect(content.contains('/ExtGState'), isTrue);
      expect(RegExp(r'/[A-Za-z0-9]+ gs').hasMatch(stream), isTrue,
          reason: 'içerik akışında grafik durumu çağrılmalı');
      // Metin çizim komutları da bulunmalı.
      expect(stream.contains('Tj') || stream.contains('TJ'), isTrue);
    });

    test('fotoğraf sayfayı kenardan kenara kaplar (2 cm boşluk yok)', () async {
      final bytes = await service.buildSearchablePdf(
        pages: [pageFor(writePhoto('tam.jpg'))],
      );

      final widths = imagePlacementWidths(bytes);
      expect(widths, isNotEmpty, reason: 'görüntü yerleşimi bulunamadı');
      // Dikey fotoğraf A4'e genişlikten oturur: çizim genişliği = sayfa genişliği.
      expect(widths.first, closeTo(595.28, 1.0));
    });

    test('metni olmayan sayfa yine fotoğraf olarak eklenir', () async {
      final bytes = await service.buildSearchablePdf(
        pages: [
          SearchablePage(imagePath: writePhoto('bos.jpg'), words: const []),
        ],
      );

      expect(countPages(bytes), 1);
      expect(asLatin(bytes).contains('/XObject'), isTrue);
    });

    test('çoklu sayfa sırayla eklenir', () async {
      final bytes = await service.buildSearchablePdf(
        pages: [
          pageFor(writePhoto('bir.jpg')),
          pageFor(writePhoto('iki.jpg', width: 900, height: 600)),
        ],
      );

      expect(countPages(bytes), 2);
      final text = asLatin(bytes);
      expect(text, contains(portraitBox));
      expect(text, contains(landscapeBox));
    });

    test('sayfa listesi boşsa PDF üretilmez', () async {
      await expectLater(
        service.buildSearchablePdf(pages: const []),
        throwsA(isA<AppException>()),
      );
    });

    test('okunamayan fotoğrafta anlaşılır hata verir', () async {
      final broken = '${directory.path}${Platform.pathSeparator}bozuk2.jpg';
      File(broken).writeAsBytesSync(const [4, 4, 4]);

      await expectLater(
        service.buildSearchablePdf(
          pages: [SearchablePage(imagePath: broken, words: const [])],
        ),
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

  group('Fotoğraf PDF kenar boşluğu', () {
    test('sade fotoğraf PDF\'i de kenardan kenara kaplar', () async {
      final image = img.Image(width: 600, height: 800);
      img.fill(image, color: img.ColorRgb8(180, 180, 180));
      final path = '${directory.path}${Platform.pathSeparator}kenar.jpg';
      File(path).writeAsBytesSync(img.encodeJpg(image, quality: 85));

      final bytes = await service.buildImagesPdf(imagePaths: [path]);
      final widths = imagePlacementWidths(bytes);

      expect(widths, isNotEmpty);
      // 2 cm boşlukla bu değer 481.9 olurdu.
      expect(widths.first, closeTo(595.28, 1.0));
    });
  });
}
