import 'package:flutter/foundation.dart';

import '../core/constants/plan_limits.dart';
import '../models/document_model.dart';
import '../models/subscription_model.dart';
import '../models/usage_model.dart';
import 'entitlement_service.dart';
import 'usage_tracker.dart';

/// Özellik erişim kararlarının TEK yeri.
///
/// Ekranlar `if (isPro)` yazmaz; buradaki `canUse...` sorularını sorar.
/// OCR / PDF servisleri bu sınıftan habersizdir: sınırlar yalnızca akışın başında
/// (ExtractionFlow) ve işlem bitince kullanım kaydında uygulanır.
class FeatureAccessService extends ChangeNotifier {
  FeatureAccessService({
    required EntitlementService entitlement,
    required UsageTracker usage,
  })  : _entitlement = entitlement,
        _usage = usage {
    _entitlement.addListener(notifyListeners);
    _usage.addListener(notifyListeners);
  }

  final EntitlementService _entitlement;
  final UsageTracker _usage;

  Entitlement get entitlement => _entitlement.current;

  bool get isPro => _entitlement.isPro;

  /// Geçerli planın sınırları.
  PlanLimits get limits => isPro ? ProLimits.plan : FreeLimits.plan;

  DailyUsage get todayUsage => _usage.today;

  /// Bugün kalan OCR işlemi. null = sınırsız.
  int? get remainingOcrToday =>
      _remaining(limits.dailyOcrOperations, todayUsage.ocrCount);

  /// Bugün kalan PDF işlemi. null = sınırsız.
  int? get remainingPdfToday =>
      _remaining(limits.dailyPdfOperations, todayUsage.pdfCount);

  bool canUseOcr() => _hasRemaining(remainingOcrToday);

  bool canProcessPdf() => _hasRemaining(remainingPdfToday);

  /// [imageCount] fotoğraf tek seferde işlenebilir mi?
  bool canUseBatchOcr(int imageCount) {
    final max = limits.maxImagesPerBatch;
    return max == null || imageCount <= max;
  }

  /// [pageCount] sayfalık PDF'in tamamı işlenebilir mi?
  bool canUseLargePdf(int pageCount) {
    final max = limits.maxPdfPages;
    return max == null || pageCount <= max;
  }

  /// [sizeBytes] boyutundaki PDF açılabilir mi?
  bool canOpenPdfFile(int sizeBytes) {
    final max = limits.maxPdfFileSizeBytes;
    return max == null || sizeBytes <= max;
  }

  /// Reklam politikası: Pro kullanıcıya hiçbir reklam gösterilmez.
  bool shouldShowAds() => !isPro;

  /// Başarıyla tamamlanan işlemi Free sayacına yazar.
  /// Pro kullanımı sayılmaz (abonelik biterse kullanıcı gün ortasında cezalandırılmaz).
  /// Hata veya iptal ile biten işlemler hiç çağrılmaz, hak harcanmaz.
  Future<void> recordCompletedExtraction(DocumentSource source) async {
    if (isPro) {
      return;
    }
    if (source == DocumentSource.pdf) {
      await _usage.recordPdf();
    } else {
      await _usage.recordOcr();
    }
  }

  @override
  void dispose() {
    _entitlement.removeListener(notifyListeners);
    _usage.removeListener(notifyListeners);
    super.dispose();
  }

  static int? _remaining(int? limit, int used) {
    if (limit == null) {
      return null;
    }
    final remaining = limit - used;
    return remaining < 0 ? 0 : remaining;
  }

  static bool _hasRemaining(int? remaining) => remaining == null || remaining > 0;
}
