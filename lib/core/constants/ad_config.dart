/// Reklam sıklığı ayarları — TEK kaynak.
///
/// Bu sürümde reklam SDK'sı YOKTUR (NoOpAdProvider). Değerler, ileride AdMob
/// bağlandığında reklamların kullanıcıyı rahatsız etmemesi için baştan sınırlıdır.
class AdConfig {
  AdConfig._();

  /// Tam ekran reklam en erken bu kadar tamamlanmış işlemden sonra gösterilir.
  static const int completedExtractionsPerInterstitial = 3;

  /// İki tam ekran reklam arasındaki en kısa süre.
  static const Duration minTimeBetweenInterstitials = Duration(minutes: 5);
}
