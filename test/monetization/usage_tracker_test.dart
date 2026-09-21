import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:metincep/services/usage_tracker.dart';

void main() {
  late Directory directory;
  late DateTime now;

  UsageTracker createTracker() =>
      UsageTracker(directoryProvider: () async => directory, clock: () => now);

  File usageFile() => File('${directory.path}/${UsageTracker.fileName}');

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('metincep_usage_test_');
    now = DateTime(2026, 9, 11, 10);
  });

  tearDown(() async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });

  test('sayaçlar kaydedilir ve uygulama yeniden açılınca korunur', () async {
    final tracker = createTracker();
    await tracker.load();
    await tracker.recordOcr();
    await tracker.recordOcr();
    await tracker.recordPdf();

    final reopened = createTracker();
    await reopened.load();

    expect(reopened.today.dayKey, '2026-09-11');
    expect(reopened.today.ocrCount, 2);
    expect(reopened.today.pdfCount, 1);

    final saved = jsonDecode(await usageFile().readAsString()) as Map<String, dynamic>;
    expect(saved['date'], '2026-09-11');
    expect(saved['ocrCount'], 2);
    expect(saved['pdfCount'], 1);
  });

  test('aynı gün içinde sayaç sıfırlanmaz', () async {
    final tracker = createTracker();
    await tracker.load();
    await tracker.recordOcr();

    now = DateTime(2026, 9, 11, 23, 59);
    expect(tracker.today.ocrCount, 1);
  });

  test('yeni gün başlayınca sayaçlar otomatik sıfırlanır', () async {
    final tracker = createTracker();
    await tracker.load();
    await tracker.recordOcr();
    await tracker.recordPdf();

    now = DateTime(2026, 9, 12, 0, 5);

    expect(tracker.today.dayKey, '2026-09-12');
    expect(tracker.today.ocrCount, 0);
    expect(tracker.today.pdfCount, 0);
  });

  test('uygulama kapalıyken gün değişirse açılışta sayaçlar sıfırlanır', () async {
    final tracker = createTracker();
    await tracker.load();
    await tracker.recordOcr();

    now = DateTime(2026, 9, 13, 8);
    final reopened = createTracker();
    await reopened.load();

    expect(reopened.today.ocrCount, 0);
  });

  test('saat geri alınınca sayaçlar sıfırlanmaz (ileri al / geri al hilesi)', () async {
    final tracker = createTracker();
    await tracker.load();
    for (var i = 0; i < 5; i++) {
      await tracker.recordOcr();
    }

    // Kullanıcı saati yarına alıyor: yeni gün, sayaçlar sıfırlanır.
    now = DateTime(2026, 9, 12, 9);
    expect(tracker.today.ocrCount, 0);
    for (var i = 0; i < 5; i++) {
      await tracker.recordOcr();
    }

    // Saati gerçek zamana geri alıyor: yeni hak KAZANMAMALI.
    now = DateTime(2026, 9, 11, 10, 30);
    expect(tracker.today.ocrCount, 5);
    expect(tracker.today.dayKey, '2026-09-12');
    expect(tracker.clockRollbackDetected, isTrue);

    // Uygulamayı kapatıp açmak da hileyi aşmaz.
    final reopened = createTracker();
    await reopened.load();
    expect(reopened.today.ocrCount, 5);

    // Gerçek zaman kayıtlı günü geçince normal sıfırlama devam eder.
    now = DateTime(2026, 9, 13, 8);
    expect(reopened.today.ocrCount, 0);
    expect(reopened.clockRollbackDetected, isFalse);
  });

  test('küçük saat düzeltmeleri geri alma sayılmaz', () async {
    final tracker = createTracker();
    await tracker.load();
    await tracker.recordOcr();

    now = DateTime(2026, 9, 11, 9, 55);

    expect(tracker.today.ocrCount, 1);
    expect(tracker.clockRollbackDetected, isFalse);
  });

  test('geliştirici aracı sayaçları doldurur ve sıfırlar (debug)', () async {
    final tracker = createTracker();
    await tracker.load();

    await tracker.setCountsForDebug(ocrCount: 10, pdfCount: 3);
    expect(tracker.today.ocrCount, 10);
    expect(tracker.today.pdfCount, 3);

    // Doldurulan değerler de kalıcıdır.
    final reopened = createTracker();
    await reopened.load();
    expect(reopened.today.ocrCount, 10);

    await reopened.resetTodayForDebug();
    expect(reopened.today.ocrCount, 0);
    expect(reopened.today.pdfCount, 0);

    // Negatif değer sıfıra çekilir.
    await reopened.setCountsForDebug(ocrCount: -3, pdfCount: -1);
    expect(reopened.today.ocrCount, 0);
    expect(reopened.today.pdfCount, 0);
  });

  test('bozuk kullanım dosyası uygulamayı çökertmez', () async {
    await usageFile().writeAsString('{bozuk json');

    final tracker = createTracker();
    await tracker.load();

    expect(tracker.today.ocrCount, 0);
    expect(tracker.today.pdfCount, 0);

    await tracker.recordOcr();
    final repaired = jsonDecode(await usageFile().readAsString()) as Map<String, dynamic>;
    expect(repaired['ocrCount'], 1);
  });

  test('geçersiz alan değerleri güvenle yok sayılır', () async {
    await usageFile().writeAsString(
      jsonEncode({'date': 'dün', 'ocrCount': -5, 'pdfCount': 'çok', 'lastSeenAt': null}),
    );

    final tracker = createTracker();
    await tracker.load();

    expect(tracker.today.dayKey, '2026-09-11');
    expect(tracker.today.ocrCount, 0);
    expect(tracker.today.pdfCount, 0);
  });

  test('dosya liste gibi beklenmeyen JSON içerirse çökmez', () async {
    await usageFile().writeAsString('[1, 2, 3]');

    final tracker = createTracker();
    await tracker.load();

    expect(tracker.today.ocrCount, 0);
  });
}
