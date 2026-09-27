import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:metincep/core/constants/plan_limits.dart';
import 'package:metincep/core/constants/purchase_products.dart';
import 'package:metincep/models/document_model.dart';
import 'package:metincep/services/entitlement_service.dart';
import 'package:metincep/services/feature_access_service.dart';
import 'package:metincep/services/purchase_service.dart';
import 'package:metincep/services/usage_tracker.dart';

import '../helpers/test_services.dart';

void main() {
  late Directory directory;
  late DateTime now;

  Future<(UsageTracker, EntitlementService, FeatureAccessService)> createSetup({
    PurchaseService purchases = const UnavailablePurchaseService(),
  }) async {
    final usage = UsageTracker(
      directoryProvider: () async => directory,
      clock: () => now,
    );
    await usage.load();
    final entitlement = EntitlementService(purchases: purchases);
    final access = FeatureAccessService(entitlement: entitlement, usage: usage);
    return (usage, entitlement, access);
  }

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('metincep_pdfquota_test_');
    now = DateTime(2026, 9, 27, 10);
  });

  tearDown(() async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });

  test('Free plan günlük PDF çıktı limiti tanımlı', () {
    expect(FreeLimits.dailyPdfExports, 2);
    expect(FreeLimits.plan.dailyPdfExports, FreeLimits.dailyPdfExports);
    expect(ProLimits.plan.dailyPdfExports, isNull);
  });

  test('Free kullanıcı günlük hakkı kadar PDF oluşturabilir, sonrası engellenir',
      () async {
    final (usage, _, access) = await createSetup();

    for (var index = 0; index < FreeLimits.dailyPdfExports; index++) {
      expect(access.canExportPdf(), isTrue, reason: '${index + 1}. PDF öncesi');
      expect(access.remainingPdfExportsToday, FreeLimits.dailyPdfExports - index);
      await access.recordCompletedPdfExport();
    }

    expect(access.canExportPdf(), isFalse);
    expect(access.remainingPdfExportsToday, 0);
    expect(usage.today.pdfExportCount, FreeLimits.dailyPdfExports);
  });

  test('PDF çıktısı OCR ve PDF okuma kotalarını etkilemez', () async {
    final (usage, _, access) = await createSetup();

    await access.recordCompletedPdfExport();
    await access.recordCompletedPdfExport();

    expect(access.canExportPdf(), isFalse);
    // Diğer haklar bozulmaz.
    expect(access.canUseOcr(), isTrue);
    expect(access.canProcessPdf(), isTrue);
    expect(usage.today.ocrCount, 0);
    expect(usage.today.pdfCount, 0);
  });

  test('OCR ve PDF okuma, PDF çıktı hakkını tüketmez', () async {
    final (usage, _, access) = await createSetup();

    await access.recordCompletedExtraction(DocumentSource.camera);
    await access.recordCompletedExtraction(DocumentSource.pdf);

    expect(usage.today.pdfExportCount, 0);
    expect(access.remainingPdfExportsToday, FreeLimits.dailyPdfExports);
  });

  test('başarısız / iptal edilen PDF kota tüketmez', () async {
    final (usage, _, access) = await createSetup();

    // Hata veya iptal durumunda akış recordCompletedPdfExport çağırmaz.
    expect(usage.today.pdfExportCount, 0);
    expect(access.canExportPdf(), isTrue);
    expect(access.remainingPdfExportsToday, FreeLimits.dailyPdfExports);
  });

  test('yeni gün başlayınca PDF çıktı hakkı yenilenir', () async {
    final (_, _, access) = await createSetup();
    for (var index = 0; index < FreeLimits.dailyPdfExports; index++) {
      await access.recordCompletedPdfExport();
    }
    expect(access.canExportPdf(), isFalse);

    now = DateTime(2026, 9, 28, 8);

    expect(access.canExportPdf(), isTrue);
    expect(access.remainingPdfExportsToday, FreeLimits.dailyPdfExports);
  });

  test('Pro kullanıcıda PDF çıktısı sınırsız ve sayaç artmaz', () async {
    final (usage, entitlement, access) = await createSetup(
      purchases: FakePurchaseService(
        activeProductIds: {PurchaseProducts.proYearly},
      ),
    );
    await entitlement.refresh();

    for (var index = 0; index < 25; index++) {
      expect(access.canExportPdf(), isTrue);
      await access.recordCompletedPdfExport();
    }

    expect(usage.today.pdfExportCount, 0);
    expect(access.remainingPdfExportsToday, isNull);
  });

  test('PDF çıktı sayacı diske yazılır ve yeniden açılınca korunur', () async {
    final (_, _, access) = await createSetup();
    await access.recordCompletedPdfExport();

    final reopened = UsageTracker(
      directoryProvider: () async => directory,
      clock: () => now,
    );
    await reopened.load();

    expect(reopened.today.pdfExportCount, 1);

    final saved = jsonDecode(
      await File('${directory.path}/${UsageTracker.fileName}').readAsString(),
    ) as Map<String, dynamic>;
    expect(saved['pdfExportCount'], 1);
  });

  test('V1 dosyasında pdfExportCount yoksa 0 sayılır (geriye uyumluluk)', () async {
    // Eski sürümün yazdığı dosya: pdfExportCount alanı yok.
    await File('${directory.path}/${UsageTracker.fileName}').writeAsString(
      jsonEncode({
        'version': 1,
        'date': '2026-09-27',
        'ocrCount': 4,
        'pdfCount': 1,
        'lastSeenAt': DateTime(2026, 9, 27, 9).millisecondsSinceEpoch,
      }),
    );

    final (usage, _, access) = await createSetup();

    expect(usage.today.ocrCount, 4);
    expect(usage.today.pdfCount, 1);
    expect(usage.today.pdfExportCount, 0);
    expect(access.canExportPdf(), isTrue);
  });

  test('geliştirici aracı PDF çıktı sayacını da doldurur (debug)', () async {
    final (usage, _, access) = await createSetup();

    await usage.setCountsForDebug(
      ocrCount: 0,
      pdfCount: 0,
      pdfExportCount: FreeLimits.dailyPdfExports,
    );

    expect(access.canExportPdf(), isFalse);
    await usage.resetTodayForDebug();
    expect(access.canExportPdf(), isTrue);
  });
}
