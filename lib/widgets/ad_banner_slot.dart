import 'package:flutter/material.dart';

import '../core/app_scope.dart';
import '../services/ad_service.dart';

/// Banner reklam yeri. Pro kullanıcıda veya reklam sağlayıcısı yokken hiç yer kaplamaz.
class AdBannerSlot extends StatelessWidget {
  const AdBannerSlot({super.key, required this.placement});

  final AdPlacement placement;

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    return ListenableBuilder(
      listenable: services.access,
      builder: (context, _) => services.ads.showBanner(placement),
    );
  }
}
