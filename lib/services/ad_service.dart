import 'package:flutter/widgets.dart';

import '../core/constants/ad_config.dart';
import 'feature_access_service.dart';

/// Reklamın gösterilebileceği yerler.
///
/// Bilinçli olarak YOK: OCR işlemi, PDF işleme, kamera açılışı, metin düzenleme.
/// Bu anlar için bir yerleşim tanımlanmadığından reklam kodu oralardan çağrılamaz.
enum AdPlacement {
  /// Ana ekranın en altı.
  homeBottomBanner(allowsBanner: true),

  /// Geçmiş ekranının en altı.
  historyBottomBanner(allowsBanner: true),

  /// Kullanıcı sonuç ekranından çıkıp ana ekrana döndükten sonra.
  afterResultClosed(allowsInterstitial: true);

  const AdPlacement({this.allowsBanner = false, this.allowsInterstitial = false});

  final bool allowsBanner;
  final bool allowsInterstitial;
}

/// Reklam SDK'sı sağlayıcısı. İleride `AdMobAdProvider` bu arayüzü uygulayacak.
abstract class AdProvider {
  /// SDK başlatıldı ve reklam gösterebilir mi?
  bool get isReady;

  Widget buildBanner(AdPlacement placement);

  /// Gösterildiyse true.
  Future<bool> showInterstitial(AdPlacement placement);
}

/// Bu sürümün sağlayıcısı: hiçbir reklam SDK'sı yok, hiçbir şey göstermez, ağ kullanmaz.
class NoOpAdProvider implements AdProvider {
  const NoOpAdProvider();

  @override
  bool get isReady => false;

  @override
  Widget buildBanner(AdPlacement placement) => const SizedBox.shrink();

  @override
  Future<bool> showInterstitial(AdPlacement placement) async => false;
}

/// Reklam kararlarının tek yeri: Pro kontrolü, yerleşim kuralları ve sıklık sınırı.
/// OCR / PDF kodu bu sınıfı tanımaz.
class AdService {
  AdService({
    required FeatureAccessService access,
    AdProvider provider = const NoOpAdProvider(),
    DateTime Function()? clock,
  })  : _access = access,
        _provider = provider,
        _clock = clock ?? DateTime.now;

  final FeatureAccessService _access;
  final AdProvider _provider;
  final DateTime Function() _clock;

  int _completedSinceInterstitial = 0;
  DateTime? _lastInterstitialAt;

  /// Pro kullanıcıda her zaman false.
  bool isAdsEnabled() => _access.shouldShowAds() && _provider.isReady;

  /// Banner alanı. Reklam kapalıysa yer kaplamayan boş widget döner.
  Widget showBanner(AdPlacement placement) {
    if (!placement.allowsBanner || !isAdsEnabled()) {
      return const SizedBox.shrink();
    }
    return _provider.buildBanner(placement);
  }

  /// Uygun geçiş noktasında çağrılır; sıklık sınırına uymuyorsa hiçbir şey yapmaz.
  Future<bool> showInterstitial(AdPlacement placement) async {
    if (!placement.allowsInterstitial || !isAdsEnabled()) {
      return false;
    }
    _completedSinceInterstitial++;
    if (_completedSinceInterstitial < AdConfig.completedExtractionsPerInterstitial) {
      return false;
    }
    final now = _clock();
    final last = _lastInterstitialAt;
    if (last != null && now.difference(last) < AdConfig.minTimeBetweenInterstitials) {
      return false;
    }
    try {
      final shown = await _provider.showInterstitial(placement);
      if (shown) {
        _lastInterstitialAt = now;
        _completedSinceInterstitial = 0;
      }
      return shown;
    } catch (error) {
      debugPrint('Reklam gösterilemedi: $error');
      return false;
    }
  }
}
