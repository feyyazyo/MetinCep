import 'dart:io';

import 'package:flutter/material.dart';
import 'package:metincep/core/app_scope.dart';
import 'package:metincep/repositories/document_repository.dart';
import 'package:metincep/services/ad_service.dart';
import 'package:metincep/services/entitlement_service.dart';
import 'package:metincep/services/extraction_service.dart';
import 'package:metincep/services/feature_access_service.dart';
import 'package:metincep/services/ocr_service.dart';
import 'package:metincep/services/pdf_service.dart';
import 'package:metincep/services/purchase_service.dart';
import 'package:metincep/services/settings_controller.dart';
import 'package:metincep/services/share_service.dart';
import 'package:metincep/services/source_picker_service.dart';
import 'package:metincep/services/usage_tracker.dart';

/// Test için satın alma sağlayıcısı: verilen ürünler etkin sayılır.
class FakePurchaseService implements PurchaseService {
  FakePurchaseService({this.activeProductIds = const {}, this.throwOnQuery = false});

  Set<String> activeProductIds;
  bool throwOnQuery;

  @override
  bool get isAvailable => true;

  @override
  Future<Set<String>> queryActiveProductIds() async {
    if (throwOnQuery) {
      throw StateError('Play Store erişilemedi');
    }
    return activeProductIds;
  }

  @override
  Future<PurchaseResult> purchase(String productId) async {
    activeProductIds = {...activeProductIds, productId};
    return PurchaseResult.purchased;
  }
}

/// Widget testlerinde kullanılan servis kurulumu (belge / ayar dosyası yazılmaz).
AppServices createTestServices({
  PurchaseService purchases = const UnavailablePurchaseService(),
  DateTime Function()? clock,
}) {
  final directory = Directory.systemTemp.createTempSync('metincep_widget_');
  final ocr = OcrService();
  final usage = UsageTracker(directoryProvider: () async => directory, clock: clock);
  final entitlement = EntitlementService(purchases: purchases);
  final access = FeatureAccessService(entitlement: entitlement, usage: usage);
  return AppServices(
    documents: DocumentRepository(directoryProvider: () async => directory),
    settings: SettingsController(directoryProvider: () async => directory),
    extraction: ExtractionService(ocr: ocr, pdf: PdfService(ocr: ocr)),
    picker: SourcePickerService(),
    share: ShareService(),
    usage: usage,
    entitlement: entitlement,
    access: access,
    ads: AdService(access: access),
  );
}

Widget wrapWithServices(AppServices services, Widget home) {
  return AppScope(
    services: services,
    child: MaterialApp(home: home),
  );
}
