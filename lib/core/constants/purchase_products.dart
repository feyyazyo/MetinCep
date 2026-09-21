/// Google Play ürün kimlikleri — TEK kaynak.
///
/// DİKKAT: Bu ürünler henüz Google Play Console'da oluşturulmadı ve
/// uygulamada satın alınabilir olarak GÖSTERİLMEZ. Gerçek Billing
/// entegrasyonu yapılırken Play Console'daki kimliklerle birebir aynı olmalıdır.
class PurchaseProducts {
  PurchaseProducts._();

  static const String proMonthly = 'metincep_pro_monthly';
  static const String proYearly = 'metincep_pro_yearly';
  static const String proLifetime = 'metincep_pro_lifetime';

  /// Pro yetkisi veren tüm ürünler.
  static const List<String> proProducts = [proMonthly, proYearly, proLifetime];

  /// Abonelik (yenilenen) ürünler; lifetime tek seferlik satın almadır.
  static const List<String> subscriptions = [proMonthly, proYearly];

  static bool grantsPro(String productId) => proProducts.contains(productId);
}
