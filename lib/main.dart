import 'dart:async' show unawaited;
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/widgets.dart';

import 'app.dart';
import 'core/app_scope.dart';
import 'repositories/document_repository.dart';
import 'services/ad_service.dart';
import 'services/entitlement_service.dart';
import 'services/extraction_service.dart';
import 'services/feature_access_service.dart';
import 'services/ocr_service.dart';
import 'services/pdf_service.dart';
import 'services/purchase_service.dart';
import 'services/settings_controller.dart';
import 'services/share_service.dart';
import 'services/source_picker_service.dart';
import 'services/usage_tracker.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Yakalanmamış asenkron hatalar uygulamayı kapatmasın.
  PlatformDispatcher.instance.onError = (error, stackTrace) {
    debugPrint('Yakalanmamış hata: $error\n$stackTrace');
    return true;
  };

  final documents = DocumentRepository.appDefault();
  final settings = SettingsController.appDefault();
  final usage = UsageTracker.appDefault();
  await Future.wait([documents.load(), settings.load(), usage.load()]);

  // Google Play Billing bu sürümde bağlı değil: satın alma yok, herkes Free.
  // Mock Pro yalnızca debug derlemede Pro ekranından açılabilir.
  final entitlement = EntitlementService(purchases: const UnavailablePurchaseService());
  // Çevrimdışı öncelik: satın alma kontrolü açılışı asla bekletmez.
  unawaited(entitlement.refresh());
  final access = FeatureAccessService(entitlement: entitlement, usage: usage);

  final ocrService = OcrService();
  final services = AppServices(
    documents: documents,
    settings: settings,
    extraction: ExtractionService(
      ocr: ocrService,
      pdf: PdfService(ocr: ocrService),
    ),
    picker: SourcePickerService(),
    share: ShareService(),
    usage: usage,
    entitlement: entitlement,
    access: access,
    // Reklam SDK'sı yok; AdMob ayrı bir aşamada AdProvider olarak bağlanacak.
    ads: AdService(access: access, provider: const NoOpAdProvider()),
  );

  runApp(AppScope(services: services, child: const MetinCepApp()));
}
