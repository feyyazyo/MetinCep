import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metincep/app.dart';
import 'package:metincep/core/app_scope.dart';
import 'package:metincep/core/constants/plan_limits.dart';
import 'package:metincep/screens/pro/limit_dialog.dart';
import 'package:metincep/screens/pro/pro_screen.dart';

import '../helpers/test_services.dart';

/// Liste öğeleri test ekranının (800x600) dışında kalınca "offstage" sayılır ve bulunamaz.
/// Pro ekranı ve ana ekran uzun olduğu için testler telefon boyu bir görünümde çalışır.
void useTallView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('Free kullanıcı ana ekranda küçük Pro kartını görür, Pro olunca kart kaybolur',
      (tester) async {
    useTallView(tester);
    final services = createTestServices();
    await tester.pumpWidget(AppScope(services: services, child: const MetinCepApp()));
    await tester.pumpAndSettle();

    expect(find.text('MetinCep Pro'), findsOneWidget);
    expect(find.text('Limitsiz belge işlemi'), findsOneWidget);
    // OCR / PDF düğmeleri yerinde.
    expect(find.text('Fotoğraf Çek'), findsOneWidget);
    expect(find.text('PDF Aç'), findsOneWidget);

    services.entitlement.setMockPro(true);
    await tester.pumpAndSettle();

    expect(find.text('Limitsiz belge işlemi'), findsNothing);
    expect(find.text('Fotoğraf Çek'), findsOneWidget);
  });

  testWidgets('Ayarlarda Pro Durumu Free / Pro olarak görünür', (tester) async {
    useTallView(tester);
    final services = createTestServices();
    await tester.pumpWidget(AppScope(services: services, child: const MetinCepApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ayarlar'));
    await tester.pumpAndSettle();

    expect(find.text('Pro Durumu'), findsOneWidget);
    expect(find.text('Free'), findsOneWidget);
    expect(
      find.text(
        'Bugün kalan: ${FreeLimits.dailyOcrOperations} OCR · ${FreeLimits.dailyPdfOperations} PDF',
      ),
      findsOneWidget,
    );

    services.entitlement.setMockPro(true);
    await tester.pumpAndSettle();

    expect(find.text('Pro'), findsOneWidget);
    expect(find.text('Free'), findsNothing);
  });

  testWidgets('Günlük OCR limiti dolunca pencere çıkar, İptal ile kapanır', (tester) async {
    useTallView(tester);
    final services = createTestServices();
    // Geliştirici aracı: 10 gerçek işlem yapmadan hakları doldur.
    await services.usage.setCountsForDebug(
      ocrCount: FreeLimits.dailyOcrOperations,
      pdfCount: 0,
    );
    await tester.pumpWidget(AppScope(services: services, child: const MetinCepApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Fotoğraf Çek'));
    await tester.pumpAndSettle();

    expect(find.text('Günlük OCR limitin doldu.'), findsOneWidget);
    expect(find.text('Pro ile sınırsız OCR kullanabilirsin. Free hakların yarın yenilenir.'),
        findsOneWidget);
    expect(find.widgetWithText(FilledButton, "Pro'yu İncele"), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'İptal'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'İptal'));
    await tester.pumpAndSettle();

    expect(find.text('Günlük OCR limitin doldu.'), findsNothing);
    expect(find.text('Fotoğraf Çek'), findsOneWidget);
  });

  testWidgets('Limit penceresinden Pro ekranına gidilir', (tester) async {
    useTallView(tester);
    final services = createTestServices();
    await services.usage.setCountsForDebug(
      ocrCount: 0,
      pdfCount: FreeLimits.dailyPdfOperations,
    );
    await tester.pumpWidget(AppScope(services: services, child: const MetinCepApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('PDF Aç'));
    await tester.pumpAndSettle();
    expect(find.text('Günlük PDF limitin doldu.'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, "Pro'yu İncele"));
    await tester.pumpAndSettle();

    expect(find.text('Daha fazla belge işle.'), findsOneWidget);
    expect(find.text('Bugün kalan PDF'), findsOneWidget);
    expect(find.text('0 / ${FreeLimits.dailyPdfOperations}'), findsOneWidget);

    // Pro ekranından geri dönülünce erişim hâlâ yok: akış sessizce biter.
    // (Uygulama Türkçe olduğundan pageBack()'in aradığı "Back" ipucu yok; düğmeye doğrudan dokunulur.)
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('PDF Aç'), findsOneWidget);
  });

  testWidgets('Pro ekranı: satın alma yokken düğme pasif ve "Yakında"', (tester) async {
    useTallView(tester);
    await tester.pumpWidget(wrapWithServices(createTestServices(), const ProScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Limitsiz OCR'), findsOneWidget);
    expect(find.text('Limitsiz PDF'), findsOneWidget);
    expect(find.text('Çok sayfalı PDF'), findsOneWidget);
    expect(find.text('Toplu OCR'), findsOneWidget);
    expect(find.text('Reklamsız kullanım'), findsOneWidget);
    expect(find.text('Daha yüksek dosya limitleri'), findsOneWidget);
    expect(find.text('Bugün kalan OCR'), findsOneWidget);
    expect(find.text('${FreeLimits.dailyOcrOperations} / ${FreeLimits.dailyOcrOperations}'),
        findsOneWidget);

    final buttonFinder = find.ancestor(
      of: find.text("Pro'ya Geç · Yakında"),
      matching: find.byWidgetPredicate((widget) => widget is ButtonStyleButton),
    );
    expect(buttonFinder, findsOneWidget);
    expect(tester.widget<ButtonStyleButton>(buttonFinder).onPressed, isNull);
  });

  testWidgets('Debug derlemede Mock Pro anahtarı Pro özelliklerini açar', (tester) async {
    useTallView(tester);
    final services = createTestServices();
    await tester.pumpWidget(wrapWithServices(services, const ProScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mock Pro'));
    await tester.pumpAndSettle();

    expect(services.access.isPro, isTrue);
    expect(services.ads.isAdsEnabled(), isFalse);
    expect(find.text('MetinCep Pro etkin'), findsOneWidget);
    expect(find.text('Test Pro (yalnızca debug derleme)'), findsOneWidget);
  });

  test('Limit metinleri sayıları plandan alır', () {
    final pages = LimitPrompt.pdfPages(pageCount: 24, maxPages: FreeLimits.maxPdfPages);
    expect(pages.title, 'Bu PDF 24 sayfa.');
    expect(pages.continueLabel, 'İlk ${FreeLimits.maxPdfPages} sayfayı işle');

    final batch = LimitPrompt.batch(selectedCount: 5, maxImages: FreeLimits.maxImagesPerBatch);
    expect(batch.continueLabel, 'İlk ${FreeLimits.maxImagesPerBatch} fotoğrafı işle');

    expect(LimitPrompt.formatMegabytes(25 * 1024 * 1024), '25 MB');
    expect(LimitPrompt.formatMegabytes(1536 * 1024), '1,5 MB');
  });
}
