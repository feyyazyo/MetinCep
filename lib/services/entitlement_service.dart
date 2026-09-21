import 'package:flutter/foundation.dart';

import '../core/constants/purchase_products.dart';
import '../models/subscription_model.dart';
import 'purchase_service.dart';

/// Kullanıcının Free / Pro durumunun TEK kaynağı.
///
/// Ekranlar doğrudan `isPro` kontrolü yapmak yerine [FeatureAccessService] kullanır.
///
/// Mock Pro (geliştirici testi):
/// - Yalnızca `kDebugMode` derlemelerinde çalışır. `kDebugMode` derleme zamanı sabitidir;
///   release ve profile derlemelerde false olur ve ilgili kod ağaçtan atılır.
/// - Kalıcı değildir (yalnızca bellekte). Uygulama yeniden başlatılınca Free'ye döner;
///   uygulama silinip kurulunca Pro korunuyormuş gibi davranmaz.
class EntitlementService extends ChangeNotifier {
  EntitlementService({
    required PurchaseService purchases,
    bool allowMockPro = true,
  })  : _purchases = purchases,
        _mockProAllowed = kDebugMode && allowMockPro;

  final PurchaseService _purchases;
  final bool _mockProAllowed;

  Entitlement _purchased = Entitlement.free;
  bool _mockProEnabled = false;

  Entitlement get current =>
      isMockProEnabled ? Entitlement.debugMock : _purchased;

  bool get isPro => current.isPro;

  /// Mock Pro anahtarı gösterilebilir mi? Release'te her zaman false.
  bool get isMockProAvailable => _mockProAllowed;

  bool get isMockProEnabled => _mockProAllowed && _mockProEnabled;

  /// Gerçek satın alma kullanılabilir mi? (Bu sürümde false.)
  bool get canPurchase => _purchases.isAvailable;

  /// Satın almaları sağlayıcıdan yeniden okur. Ağ/sağlayıcı hatasında mevcut durum korunur;
  /// uygulama açılışını bekletmemek için arka planda çağrılır.
  Future<void> refresh() async {
    try {
      final activeIds = await _purchases.queryActiveProductIds();
      var next = Entitlement.free;
      for (final productId in PurchaseProducts.proProducts) {
        if (activeIds.contains(productId)) {
          next = Entitlement.purchased(productId);
          break;
        }
      }
      _setPurchased(next);
    } catch (error) {
      debugPrint('Satın almalar okunamadı, mevcut durum korunuyor: $error');
    }
  }

  Future<PurchaseResult> purchase(String productId) async {
    if (!PurchaseProducts.grantsPro(productId) || !_purchases.isAvailable) {
      return PurchaseResult.unavailable;
    }
    try {
      final result = await _purchases.purchase(productId);
      if (result == PurchaseResult.purchased) {
        await refresh();
      }
      return result;
    } catch (error) {
      debugPrint('Satın alma hatası: $error');
      return PurchaseResult.failed;
    }
  }

  /// Yalnızca debug derlemede etkilidir; release'te hiçbir şey yapmaz.
  void setMockPro(bool enabled) {
    if (!_mockProAllowed || _mockProEnabled == enabled) {
      return;
    }
    _mockProEnabled = enabled;
    notifyListeners();
  }

  void _setPurchased(Entitlement next) {
    final changed = next.tier != _purchased.tier ||
        next.source != _purchased.source ||
        next.productId != _purchased.productId;
    _purchased = next;
    if (changed) {
      notifyListeners();
    }
  }
}
