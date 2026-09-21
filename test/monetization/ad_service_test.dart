import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metincep/core/constants/ad_config.dart';
import 'package:metincep/services/ad_service.dart';
import 'package:metincep/services/entitlement_service.dart';
import 'package:metincep/services/feature_access_service.dart';
import 'package:metincep/services/purchase_service.dart';
import 'package:metincep/services/usage_tracker.dart';

/// Her zaman hazır reklam sağlayıcısı. "Hazır değil" durumu NoOpAdProvider testiyle kapsanır.
class _FakeAdProvider implements AdProvider {
  @override
  bool get isReady => true;

  int interstitialCalls = 0;
  final Widget banner = const SizedBox(key: ValueKey('fake-banner'), height: 50);

  @override
  Widget buildBanner(AdPlacement placement) => banner;

  @override
  Future<bool> showInterstitial(AdPlacement placement) async {
    interstitialCalls++;
    return true;
  }
}

void main() {
  late Directory directory;
  late DateTime now;
  late EntitlementService entitlement;
  late FeatureAccessService access;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('metincep_ads_test_');
    now = DateTime(2026, 9, 11, 10);
    final usage = UsageTracker(directoryProvider: () async => directory, clock: () => now);
    await usage.load();
    entitlement = EntitlementService(purchases: const UnavailablePurchaseService());
    access = FeatureAccessService(entitlement: entitlement, usage: usage);
  });

  tearDown(() async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });

  AdService createAds(AdProvider provider) =>
      AdService(access: access, provider: provider, clock: () => now);

  test('bu sürümün sağlayıcısı (NoOp) Free kullanıcıda bile reklam göstermez', () async {
    final ads = createAds(const NoOpAdProvider());

    expect(ads.isAdsEnabled(), isFalse);
    expect(ads.showBanner(AdPlacement.homeBottomBanner), isA<SizedBox>());
    expect(await ads.showInterstitial(AdPlacement.afterResultClosed), isFalse);
  });

  test('Free kullanıcı + hazır sağlayıcı: banner gösterilebilir', () {
    final provider = _FakeAdProvider();
    final ads = createAds(provider);

    expect(ads.isAdsEnabled(), isTrue);
    expect(ads.showBanner(AdPlacement.homeBottomBanner), same(provider.banner));
    expect(ads.showBanner(AdPlacement.historyBottomBanner), same(provider.banner));
  });

  test('Pro kullanıcı: banner ve tam ekran reklam kapalı', () async {
    final provider = _FakeAdProvider();
    final ads = createAds(provider);
    entitlement.setMockPro(true);

    expect(ads.isAdsEnabled(), isFalse);
    for (final placement in AdPlacement.values) {
      expect(ads.showBanner(placement), isA<SizedBox>(), reason: placement.name);
    }
    for (var i = 0; i < 10; i++) {
      expect(await ads.showInterstitial(AdPlacement.afterResultClosed), isFalse);
    }
    expect(provider.interstitialCalls, 0);
  });

  test('yerleşim kuralları: banner yerinde tam ekran, geçiş noktasında banner yok', () async {
    final provider = _FakeAdProvider();
    final ads = createAds(provider);

    expect(ads.showBanner(AdPlacement.afterResultClosed), isA<SizedBox>());
    for (var i = 0; i < 10; i++) {
      expect(await ads.showInterstitial(AdPlacement.homeBottomBanner), isFalse);
    }
    expect(provider.interstitialCalls, 0);
  });

  test('tam ekran reklam sıklığı sınırlıdır', () async {
    final provider = _FakeAdProvider();
    final ads = createAds(provider);
    final perAd = AdConfig.completedExtractionsPerInterstitial;

    for (var i = 1; i < perAd; i++) {
      expect(await ads.showInterstitial(AdPlacement.afterResultClosed), isFalse);
    }
    expect(await ads.showInterstitial(AdPlacement.afterResultClosed), isTrue);
    expect(provider.interstitialCalls, 1);

    // Sayı dolsa bile en kısa süre geçmeden ikinci reklam yok.
    for (var i = 0; i < perAd * 2; i++) {
      expect(await ads.showInterstitial(AdPlacement.afterResultClosed), isFalse);
    }
    expect(provider.interstitialCalls, 1);

    now = now.add(AdConfig.minTimeBetweenInterstitials + const Duration(seconds: 1));
    expect(await ads.showInterstitial(AdPlacement.afterResultClosed), isTrue);
    expect(provider.interstitialCalls, 2);
  });

  test('reklam için işlem sırasında / kamera / düzenleme yerleşimi tanımlı değil', () {
    expect(
      AdPlacement.values.map((placement) => placement.name),
      unorderedEquals(['homeBottomBanner', 'historyBottomBanner', 'afterResultClosed']),
    );
  });
}
