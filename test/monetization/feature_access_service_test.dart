import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:metincep/core/constants/plan_limits.dart';
import 'package:metincep/core/constants/purchase_products.dart';
import 'package:metincep/models/document_model.dart';
import 'package:metincep/models/subscription_model.dart';
import 'package:metincep/services/entitlement_service.dart';
import 'package:metincep/services/feature_access_service.dart';
import 'package:metincep/services/purchase_service.dart';
import 'package:metincep/services/usage_tracker.dart';

import '../helpers/test_services.dart';

class _Setup {
  _Setup(this.usage, this.entitlement, this.access);

  final UsageTracker usage;
  final EntitlementService entitlement;
  final FeatureAccessService access;
}

void main() {
  late Directory directory;
  late DateTime now;

  Future<_Setup> createSetup({
    PurchaseService purchases = const UnavailablePurchaseService(),
    bool allowMockPro = true,
  }) async {
    final usage = UsageTracker(directoryProvider: () async => directory, clock: () => now);
    await usage.load();
    final entitlement = EntitlementService(purchases: purchases, allowMockPro: allowMockPro);
    final access = FeatureAccessService(entitlement: entitlement, usage: usage);
    return _Setup(usage, entitlement, access);
  }

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('metincep_access_test_');
    now = DateTime(2026, 9, 11, 10);
  });

  tearDown(() async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });

  group('FreeLimits', () {
    test('başlangıç değerleri tek yerde tanımlı', () {
      expect(FreeLimits.dailyOcrOperations, 10);
      expect(FreeLimits.dailyPdfOperations, 3);
      expect(FreeLimits.maxPdfPages, 10);
      expect(FreeLimits.plan.dailyOcrOperations, FreeLimits.dailyOcrOperations);
      expect(FreeLimits.plan.maxPdfPages, FreeLimits.maxPdfPages);
    });

    test('Pro planında sınır yok', () {
      expect(ProLimits.plan.dailyOcrOperations, isNull);
      expect(ProLimits.plan.dailyPdfOperations, isNull);
      expect(ProLimits.plan.maxPdfPages, isNull);
      expect(ProLimits.plan.maxImagesPerBatch, isNull);
      expect(ProLimits.plan.maxPdfFileSizeBytes, isNull);
    });

    test('ürün kimlikleri tanımlı ve Pro yetkisi veriyor', () {
      expect(PurchaseProducts.proProducts, [
        'metincep_pro_monthly',
        'metincep_pro_yearly',
        'metincep_pro_lifetime',
      ]);
      expect(PurchaseProducts.grantsPro('baska_urun'), isFalse);
    });
  });

  group('Free kullanıcı', () {
    test('OCR limiti dolmadan canUseOcr true, dolunca false', () async {
      final setup = await createSetup();
      final access = setup.access;

      for (var i = 0; i < FreeLimits.dailyOcrOperations; i++) {
        expect(access.canUseOcr(), isTrue, reason: '${i + 1}. işlemden önce');
        expect(access.remainingOcrToday, FreeLimits.dailyOcrOperations - i);
        await access.recordCompletedExtraction(DocumentSource.camera);
      }

      expect(access.canUseOcr(), isFalse);
      expect(access.remainingOcrToday, 0);
      // OCR limiti PDF hakkını etkilemez.
      expect(access.canProcessPdf(), isTrue);
    });

    test('PDF limiti dolunca canProcessPdf false, OCR etkilenmez', () async {
      final setup = await createSetup();
      final access = setup.access;

      for (var i = 0; i < FreeLimits.dailyPdfOperations; i++) {
        expect(access.canProcessPdf(), isTrue);
        await access.recordCompletedExtraction(DocumentSource.pdf);
      }

      expect(access.canProcessPdf(), isFalse);
      expect(access.remainingPdfToday, 0);
      expect(access.canUseOcr(), isTrue);
    });

    test('galeri ve kamera aynı OCR hakkından düşer', () async {
      final setup = await createSetup();
      await setup.access.recordCompletedExtraction(DocumentSource.camera);
      await setup.access.recordCompletedExtraction(DocumentSource.gallery);

      expect(setup.usage.today.ocrCount, 2);
      expect(setup.access.remainingOcrToday, FreeLimits.dailyOcrOperations - 2);
    });

    test('sayfa, toplu fotoğraf ve dosya boyutu sınırları', () async {
      final access = (await createSetup()).access;
      final maxBytes = FreeLimits.plan.maxPdfFileSizeBytes!;

      expect(access.canUseLargePdf(FreeLimits.maxPdfPages), isTrue);
      expect(access.canUseLargePdf(FreeLimits.maxPdfPages + 1), isFalse);
      expect(access.canUseBatchOcr(FreeLimits.maxImagesPerBatch), isTrue);
      expect(access.canUseBatchOcr(FreeLimits.maxImagesPerBatch + 1), isFalse);
      expect(access.canOpenPdfFile(maxBytes), isTrue);
      expect(access.canOpenPdfFile(maxBytes + 1), isFalse);
    });

    test('Free kullanıcı için reklam politikası açık', () async {
      final access = (await createSetup()).access;
      expect(access.shouldShowAds(), isTrue);
      expect(access.entitlement.tier, PlanTier.free);
    });

    test('yeni gün başlayınca haklar geri gelir', () async {
      final setup = await createSetup();
      for (var i = 0; i < FreeLimits.dailyOcrOperations; i++) {
        await setup.access.recordCompletedExtraction(DocumentSource.camera);
      }
      expect(setup.access.canUseOcr(), isFalse);

      now = DateTime(2026, 9, 12, 7);

      expect(setup.access.canUseOcr(), isTrue);
      expect(setup.access.remainingOcrToday, FreeLimits.dailyOcrOperations);
    });

    test('bozuk kullanım dosyasıyla da erişim kararları çalışır', () async {
      await File('${directory.path}/${UsageTracker.fileName}').writeAsString('çöp');

      final access = (await createSetup()).access;

      expect(access.canUseOcr(), isTrue);
      expect(access.canProcessPdf(), isTrue);
    });
  });

  group('Pro kullanıcı (satın alma sağlayıcısından)', () {
    test('tüm özellikler açık, reklam kapalı', () async {
      final setup = await createSetup(
        purchases: FakePurchaseService(activeProductIds: {PurchaseProducts.proYearly}),
      );
      await setup.entitlement.refresh();
      final access = setup.access;

      expect(access.isPro, isTrue);
      expect(access.entitlement.source, EntitlementSource.googlePlay);
      expect(access.entitlement.productId, PurchaseProducts.proYearly);
      expect(access.canUseOcr(), isTrue);
      expect(access.canProcessPdf(), isTrue);
      expect(access.canUseBatchOcr(500), isTrue);
      expect(access.canUseLargePdf(10000), isTrue);
      expect(access.canOpenPdfFile(2000 * 1024 * 1024), isTrue);
      expect(access.shouldShowAds(), isFalse);
      expect(access.remainingOcrToday, isNull);
      expect(access.remainingPdfToday, isNull);
    });

    test('Pro kullanımı Free sayacından düşmez', () async {
      final setup = await createSetup(
        purchases: FakePurchaseService(activeProductIds: {PurchaseProducts.proLifetime}),
      );
      await setup.entitlement.refresh();

      for (var i = 0; i < 25; i++) {
        await setup.access.recordCompletedExtraction(DocumentSource.pdf);
      }

      expect(setup.usage.today.pdfCount, 0);
      expect(setup.access.canProcessPdf(), isTrue);
    });

    test('Free hakkı bitmiş kullanıcı Pro olunca devam edebilir', () async {
      final purchases = FakePurchaseService();
      final setup = await createSetup(purchases: purchases);
      for (var i = 0; i < FreeLimits.dailyOcrOperations; i++) {
        await setup.access.recordCompletedExtraction(DocumentSource.camera);
      }
      expect(setup.access.canUseOcr(), isFalse);

      final result = await setup.entitlement.purchase(PurchaseProducts.proMonthly);

      expect(result, PurchaseResult.purchased);
      expect(setup.access.canUseOcr(), isTrue);
    });

    test('tanınmayan ürün Pro yetkisi vermez', () async {
      final setup = await createSetup(
        purchases: FakePurchaseService(activeProductIds: {'baska_uygulama_pro'}),
      );
      await setup.entitlement.refresh();

      expect(setup.access.isPro, isFalse);
    });

    test('satın alma sağlayıcısı hata verirse uygulama çökmez, durum korunur', () async {
      final purchases = FakePurchaseService(activeProductIds: {PurchaseProducts.proYearly});
      final setup = await createSetup(purchases: purchases);
      await setup.entitlement.refresh();
      expect(setup.access.isPro, isTrue);

      purchases.throwOnQuery = true;
      await setup.entitlement.refresh();

      expect(setup.access.isPro, isTrue);
    });

    test('satın alma yokken (bu sürüm) herkes Free ve satın alma kapalı', () async {
      final setup = await createSetup();
      await setup.entitlement.refresh();

      expect(setup.access.isPro, isFalse);
      expect(setup.entitlement.canPurchase, isFalse);
      expect(
        await setup.entitlement.purchase(PurchaseProducts.proYearly),
        PurchaseResult.unavailable,
      );
      expect(setup.access.isPro, isFalse);
    });
  });

  group('Mock Pro', () {
    test('debug ortamında açılınca özellikler açılır, kapanınca geri döner', () async {
      final setup = await createSetup();
      final access = setup.access;
      var notifications = 0;
      access.addListener(() => notifications++);

      expect(setup.entitlement.isMockProAvailable, isTrue);
      setup.entitlement.setMockPro(true);

      expect(access.isPro, isTrue);
      expect(access.entitlement.source, EntitlementSource.debugMock);
      expect(access.canUseOcr(), isTrue);
      expect(access.canProcessPdf(), isTrue);
      expect(access.canUseBatchOcr(100), isTrue);
      expect(access.shouldShowAds(), isFalse);
      expect(notifications, greaterThan(0));

      setup.entitlement.setMockPro(false);
      expect(access.isPro, isFalse);
      expect(access.shouldShowAds(), isTrue);
    });

    test('release koşulunda (Mock Pro izni yok) kullanıcı kendini Pro yapamaz', () async {
      final setup = await createSetup(allowMockPro: false);

      expect(setup.entitlement.isMockProAvailable, isFalse);
      setup.entitlement.setMockPro(true);

      expect(setup.entitlement.isMockProEnabled, isFalse);
      expect(setup.access.isPro, isFalse);
      expect(setup.access.shouldShowAds(), isTrue);
    });

    test('Mock Pro kalıcı değildir: yeni servis örneği Free başlar', () async {
      final first = await createSetup();
      first.entitlement.setMockPro(true);
      expect(first.access.isPro, isTrue);

      final restarted = await createSetup();
      expect(restarted.access.isPro, isFalse);
    });
  });
}
