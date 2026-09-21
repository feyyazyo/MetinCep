import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:metincep/core/errors/app_exception.dart';
import 'package:metincep/core/utils/cancellation_token.dart';
import 'package:metincep/models/document_model.dart';
import 'package:metincep/models/extraction_models.dart';
import 'package:metincep/services/extraction_service.dart';
import 'package:metincep/services/ocr_service.dart';
import 'package:metincep/services/pdf_service.dart';

/// Bu testler ML Kit ve PDFium eklentilerine ULAŞMADAN önce devreye giren
/// koruma yollarını doğrular; bu yüzden gerçek cihaz olmadan deterministik çalışırlar.
///
/// Kota kuralıyla ilişkisi: bu yolların hepsi istisna fırlatır. ProcessingScreen
/// yalnızca başarılı sonuçta `recordCompletedExtraction` çağırdığı için
/// bu durumlarda kullanıcının günlük hakkı harcanmaz.
void main() {
  late ExtractionService extraction;
  late Directory directory;

  setUp(() async {
    final ocr = OcrService();
    extraction = ExtractionService(ocr: ocr, pdf: PdfService(ocr: ocr));
    directory = await Directory.systemTemp.createTemp('metincep_extract_test_');
  });

  tearDown(() async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });

  Future<ExtractionResult> run(
    ExtractionRequest request, {
    CancellationToken? token,
  }) {
    return extraction.run(
      request,
      cancellationToken: token ?? CancellationToken(),
      onProgress: (_) {},
    );
  }

  group('Görsel akışı', () {
    test('fotoğraf verilmezse hata döner (kota harcanmaz)', () async {
      await expectLater(
        run(const ImageExtractionRequest(imagePaths: [], source: DocumentSource.gallery)),
        throwsA(
          isA<AppException>().having(
            (error) => error.message,
            'mesaj',
            ErrorMessages.noTextInImage,
          ),
        ),
      );
    });

    test('işlem baştan iptal edilmişse OCR hiç çalışmaz', () async {
      final token = CancellationToken()..cancel();

      await expectLater(
        run(
          const ImageExtractionRequest(
            imagePaths: ['/olmayan/yol/foto.jpg'],
            source: DocumentSource.camera,
          ),
          token: token,
        ),
        throwsA(isA<OperationCancelledException>()),
      );
    });
  });

  group('PDF akışı', () {
    test('geçersiz dosya PDF olarak açılmaz', () async {
      final file = File('${directory.path}/sahte.pdf');
      await file.writeAsString('Bu bir PDF değil, düz metin.');

      await expectLater(
        run(PdfExtractionRequest(pdfPath: file.path, fileName: 'sahte.pdf')),
        throwsA(
          isA<AppException>().having(
            (error) => error.message,
            'mesaj',
            ErrorMessages.pdfOpenFailed,
          ),
        ),
      );
    });

    test('olmayan dosya uygulamayı çökertmez', () async {
      await expectLater(
        run(
          PdfExtractionRequest(
            pdfPath: '${directory.path}/yok.pdf',
            fileName: 'yok.pdf',
          ),
        ),
        throwsA(isA<AppException>()),
      );
    });

    test('boş dosya PDF sayılmaz', () async {
      final file = File('${directory.path}/bos.pdf');
      await file.writeAsBytes(const []);

      await expectLater(
        run(PdfExtractionRequest(pdfPath: file.path, fileName: 'bos.pdf')),
        throwsA(isA<AppException>()),
      );
    });
  });

  group('İptal jetonu', () {
    test('iptal edilince durum kalıcıdır ve throwIfCancelled fırlatır', () {
      final token = CancellationToken();

      expect(token.isCancelled, isFalse);
      token.throwIfCancelled();

      token.cancel();

      expect(token.isCancelled, isTrue);
      expect(token.throwIfCancelled, throwsA(isA<OperationCancelledException>()));
      token.cancel(); // tekrar iptal güvenli
      expect(token.isCancelled, isTrue);
    });
  });
}
