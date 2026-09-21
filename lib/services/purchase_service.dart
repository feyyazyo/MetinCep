/// Satın alma sağlayıcısı arayüzü.
///
/// Mimari:
///   EntitlementService  →  PurchaseService  →  Google Play Billing
///
/// Bu sprintte Google Play Billing BAĞLANMADI. Uygulama [UnavailablePurchaseService]
/// kullanır: hiçbir ürün satın alınamaz, kimseden ödeme alınmaz.
///
/// Sonraki aşamada `in_app_purchase` paketiyle bu arayüzü uygulayan
/// `GooglePlayPurchaseService` yazılacak ve main.dart'ta yalnızca sağlayıcı değiştirilecek.
/// Satın almalar Google hesabından doğrulanacağı için uygulama silinip kurulsa da
/// Pro geri yüklenebilecek; Play Billing önbelleği sayesinde çevrimdışı da çalışacak.
abstract class PurchaseService {
  /// Satın alma bu cihazda/derlemede kullanılabilir mi?
  bool get isAvailable;

  /// Kullanıcının şu anda etkin (süresi dolmamış / iade edilmemiş) ürün kimlikleri.
  Future<Set<String>> queryActiveProductIds();

  /// Satın alma akışını başlatır.
  Future<PurchaseResult> purchase(String productId);
}

enum PurchaseResult { purchased, pending, cancelled, unavailable, failed }

/// Varsayılan sağlayıcı: satın alma yok.
class UnavailablePurchaseService implements PurchaseService {
  const UnavailablePurchaseService();

  @override
  bool get isAvailable => false;

  @override
  Future<Set<String>> queryActiveProductIds() async => const <String>{};

  @override
  Future<PurchaseResult> purchase(String productId) async => PurchaseResult.unavailable;
}
