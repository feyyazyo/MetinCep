enum PlanTier {
  free('Free'),
  pro('Pro');

  const PlanTier(this.label);

  final String label;
}

/// Pro yetkisinin nereden geldiği.
enum EntitlementSource {
  /// Pro yok.
  none,

  /// Google Play satın alması (Billing entegrasyonu sonraki aşamada).
  googlePlay,

  /// Yalnızca debug derlemede geliştirici testi. Release'te asla oluşmaz.
  debugMock,
}

/// Kullanıcının o anki plan yetkisi.
class Entitlement {
  const Entitlement({required this.tier, required this.source, this.productId});

  factory Entitlement.purchased(String productId) => Entitlement(
        tier: PlanTier.pro,
        source: EntitlementSource.googlePlay,
        productId: productId,
      );

  static const Entitlement free =
      Entitlement(tier: PlanTier.free, source: EntitlementSource.none);

  static const Entitlement debugMock =
      Entitlement(tier: PlanTier.pro, source: EntitlementSource.debugMock);

  final PlanTier tier;
  final EntitlementSource source;
  final String? productId;

  bool get isPro => tier == PlanTier.pro;
}
