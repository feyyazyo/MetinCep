import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metincep/app.dart';
import 'package:metincep/core/app_scope.dart';
import 'package:metincep/models/document_model.dart';
import 'package:metincep/models/extraction_models.dart';
import 'package:metincep/screens/result/result_screen.dart';

import '../helpers/test_services.dart';

void main() {
  testWidgets('Ana ekran üç eylem kartını ve boş geçmişi gösterir', (tester) async {
    await tester.pumpWidget(
      AppScope(services: createTestServices(), child: const MetinCepApp()),
    );
    await tester.pumpAndSettle();

    expect(find.text('MetinCep'), findsOneWidget);
    expect(find.text('Fotoğraf Çek'), findsOneWidget);
    expect(find.text('Galeriden Seç'), findsOneWidget);
    expect(find.text('PDF Aç'), findsOneWidget);

    await tester.tap(find.text('Geçmiş'));
    await tester.pumpAndSettle();

    expect(find.text('Henüz kayıtlı belge yok'), findsOneWidget);

    await tester.tap(find.text('Ayarlar'));
    await tester.pumpAndSettle();

    expect(find.text('Tema'), findsOneWidget);
    expect(find.text('OCR dili'), findsOneWidget);
  });

  testWidgets('Sonuç ekranı metni, sayaçları ve eylemleri gösterir', (tester) async {
    await tester.pumpWidget(
      wrapWithServices(
        createTestServices(),
        ResultScreen.fromExtraction(
          result: const ExtractionResult(
            text: 'Çalışma\nŞirket',
            source: DocumentSource.camera,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Çıkarılan Metin'), findsOneWidget);
    expect(find.text('Çalışma\nŞirket'), findsOneWidget);
    expect(find.text('14 karakter · 2 kelime'), findsOneWidget);
    for (final label in ['Kopyala', 'Paylaş', 'TXT kaydet', 'Temizle', 'Kaydet']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
  });

  testWidgets('Temizle metni siler, Geri al geri getirir', (tester) async {
    await tester.pumpWidget(
      wrapWithServices(
        createTestServices(),
        ResultScreen.fromExtraction(
          result: const ExtractionResult(text: 'Ödeme 12.500 TL', source: DocumentSource.gallery),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Temizle'));
    await tester.pumpAndSettle();
    expect(find.text('Ödeme 12.500 TL'), findsNothing);
    expect(find.text('0 karakter · 0 kelime'), findsOneWidget);

    await tester.tap(find.text('Geri al'));
    await tester.pumpAndSettle();
    expect(find.text('Ödeme 12.500 TL'), findsOneWidget);
  });

  testWidgets('Kayıtlı belge düzenlenince kaydet düğmesi etkinleşir', (tester) async {
    final document = DocumentModel(
      id: 'doc1',
      title: 'Fatura 12',
      text: 'ABC Mermer Ltd.',
      createdAt: DateTime(2026, 9, 11),
      updatedAt: DateTime(2026, 9, 11),
    );
    await tester.pumpWidget(
      wrapWithServices(createTestServices(), ResultScreen.fromDocument(document: document)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Fatura 12'), findsOneWidget);
    expect(find.text('Kaydedildi'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'ABC Mermer Ltd. İşçilik');
    await tester.pump();

    expect(find.text('Değişiklikleri kaydet'), findsOneWidget);
  });

  testWidgets('Kaydedilmemiş metinden çıkarken onay istenir', (tester) async {
    await tester.pumpWidget(
      wrapWithServices(
        createTestServices(),
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ResultScreen.fromExtraction(
                      result: const ExtractionResult(
                        text: 'Kaydedilmemiş metin',
                        source: DocumentSource.camera,
                      ),
                    ),
                  ),
                ),
                child: const Text('Aç'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Aç'));
    await tester.pumpAndSettle();
    expect(find.text('Çıkarılan Metin'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Kaydedilmemiş değişiklikler'), findsOneWidget);

    await tester.tap(find.text('Kaydetmeden çık'));
    await tester.pumpAndSettle();
    expect(find.text('Aç'), findsOneWidget);
    expect(find.text('Çıkarılan Metin'), findsNothing);
  });
}
