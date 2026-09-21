import 'package:flutter/widgets.dart';

import '../repositories/document_repository.dart';
import '../services/ad_service.dart';
import '../services/entitlement_service.dart';
import '../services/extraction_service.dart';
import '../services/feature_access_service.dart';
import '../services/settings_controller.dart';
import '../services/share_service.dart';
import '../services/source_picker_service.dart';
import '../services/usage_tracker.dart';

/// Uygulama servisleri. Ek paket kullanmadan basit bağımlılık yönetimi.
class AppServices {
  const AppServices({
    required this.documents,
    required this.settings,
    required this.extraction,
    required this.picker,
    required this.share,
    required this.usage,
    required this.entitlement,
    required this.access,
    required this.ads,
  });

  final DocumentRepository documents;
  final SettingsController settings;
  final ExtractionService extraction;
  final SourcePickerService picker;
  final ShareService share;

  /// Free günlük sayaçları.
  final UsageTracker usage;

  /// Free / Pro durumu.
  final EntitlementService entitlement;

  /// Tüm özellik erişim kararları (ekranlar bunu kullanır).
  final FeatureAccessService access;

  /// Reklam kararları (bu sürümde reklam SDK'sı yok).
  final AdService ads;
}

class AppScope extends InheritedWidget {
  const AppScope({super.key, required this.services, required super.child});

  final AppServices services;

  /// Servisler uygulama boyunca değişmez; bu yüzden bağımlılık kaydı gerekmez
  /// ve initState / geri çağırmalar içinde güvenle kullanılabilir.
  static AppServices of(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope widget ağacında bulunamadı.');
    return scope!.services;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) => services != oldWidget.services;
}
