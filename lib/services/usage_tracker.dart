import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/usage_model.dart';

/// Free sürümün günlük işlem sayaçlarını cihazda tutar (sunucu yok, internet gerekmez).
///
/// Saklanan alanlar: `date`, `ocrCount`, `pdfCount`, `lastSeenAt`.
///
/// Saat oynama koruması (çevrimdışı, "makul caydırıcılık" düzeyinde):
/// - Sayaçlar yalnızca yerel tarih kayıtlı tarihten İLERİDE olduğunda sıfırlanır.
/// - Görülen en geç zaman (`lastSeenAt`) saklanır. Saat bundan geriye alınırsa
///   sayaçlar sıfırlanmaz; kayıtlı gün, gerçek saat o günü geçene kadar geçerli kalır.
///   Böylece "saati ileri al → sıfırla → geri al" döngüsü tekrar kullanılamaz.
///
/// GÜVENLİK NOTU: Cihazda tutulan sayaç kesin güvenlik sağlamaz. Uygulama verisini
/// silmek veya root erişimi sayaçları sıfırlayabilir. Kötüye kullanıma karşı gerçek
/// koruma için limitlerin sunucu tarafında (ör. Play Integrity + hesap bazlı sayaç)
/// doğrulanması gerekir. MetinCep V1 bilinçli olarak çevrimdışı çalışır.
class UsageTracker extends ChangeNotifier {
  UsageTracker({
    required Future<Directory> Function() directoryProvider,
    DateTime Function()? clock,
  })  : _directoryProvider = directoryProvider,
        _clock = clock ?? DateTime.now;

  factory UsageTracker.appDefault() =>
      UsageTracker(directoryProvider: getApplicationSupportDirectory);

  static const String fileName = 'metincep_usage.json';

  /// Küçük saat düzeltmeleri (ağ saati eşitlemesi vb.) geri alma sayılmaz.
  static const Duration clockRollbackTolerance = Duration(minutes: 10);

  final Future<Directory> Function() _directoryProvider;
  final DateTime Function() _clock;

  String _dayKey = '';
  int _ocrCount = 0;
  int _pdfCount = 0;
  int _lastSeenMs = 0;
  bool _clockRollbackDetected = false;
  Future<void> _pendingWrite = Future<void>.value();

  /// Son kontrolde saatin geri alındığı tespit edildi mi (tanı / test amaçlı).
  bool get clockRollbackDetected => _clockRollbackDetected;

  /// Bugünün sayaçları. Gün değiştiyse otomatik sıfırlanır.
  DailyUsage get today {
    if (_refresh()) {
      _persist();
    }
    return DailyUsage(dayKey: _dayKey, ocrCount: _ocrCount, pdfCount: _pdfCount);
  }

  Future<void> load() async {
    try {
      final file = await _file();
      if (await file.exists()) {
        final decoded = jsonDecode(await file.readAsString());
        if (decoded is Map<String, dynamic>) {
          _dayKey = _readDayKey(decoded['date']);
          _ocrCount = _readCount(decoded['ocrCount']);
          _pdfCount = _readCount(decoded['pdfCount']);
          _lastSeenMs = _readCount(decoded['lastSeenAt']);
        }
      }
    } catch (error) {
      // Bozuk dosya uygulamayı çökertmez; sayaçlar temiz başlar ve dosya yeniden yazılır.
      debugPrint('Kullanım dosyası okunamadı, sıfırdan başlanıyor: $error');
      _dayKey = '';
      _ocrCount = 0;
      _pdfCount = 0;
      _lastSeenMs = 0;
    }
    _refresh();
    notifyListeners();
    await _persist();
  }

  Future<void> recordOcr() => _increment(ocr: 1);

  Future<void> recordPdf() => _increment(pdf: 1);

  /// Yalnızca debug derlemede: sayaçları verilen değerlere getirir.
  /// Limit pencerelerini 10 gerçek çekim yapmadan test etmek için kullanılır.
  Future<void> setCountsForDebug({required int ocrCount, required int pdfCount}) async {
    if (!kDebugMode) {
      return;
    }
    _refresh();
    _ocrCount = ocrCount < 0 ? 0 : ocrCount;
    _pdfCount = pdfCount < 0 ? 0 : pdfCount;
    notifyListeners();
    await _persist();
  }

  /// Yalnızca debug derlemede: bugünkü sayaçları sıfırlar (Pro ekranındaki geliştirici bölümü).
  Future<void> resetTodayForDebug() async {
    if (!kDebugMode) {
      return;
    }
    _refresh();
    _ocrCount = 0;
    _pdfCount = 0;
    notifyListeners();
    await _persist();
  }

  Future<void> _increment({int ocr = 0, int pdf = 0}) async {
    _refresh();
    _ocrCount += ocr;
    _pdfCount += pdf;
    notifyListeners();
    await _persist();
  }

  /// Saati ve günü kontrol eder. Gün değiştiyse (sayaçlar sıfırlandıysa) true döner.
  /// `lastSeenAt` bellekte güncellenir; diske açılışta, işlem kaydında ve gün
  /// değişiminde yazılır (her okumada disk yazımı yapılmaz).
  bool _refresh() {
    final now = _clock();
    final nowMs = now.millisecondsSinceEpoch;

    if (_lastSeenMs > 0 &&
        nowMs + clockRollbackTolerance.inMilliseconds < _lastSeenMs) {
      // Saat geri alınmış: sayaçları sıfırlama, kayıtlı günü koru.
      _clockRollbackDetected = true;
      return false;
    }
    _clockRollbackDetected = false;

    if (nowMs > _lastSeenMs) {
      _lastSeenMs = nowMs;
    }

    final todayKey = DailyUsage.dayKeyOf(now);
    if (_dayKey.isEmpty || todayKey.compareTo(_dayKey) > 0) {
      _dayKey = todayKey;
      _ocrCount = 0;
      _pdfCount = 0;
      return true;
    }
    return false;
  }

  Future<void> _persist() {
    final snapshot = jsonEncode({
      'version': 1,
      'date': _dayKey,
      'ocrCount': _ocrCount,
      'pdfCount': _pdfCount,
      'lastSeenAt': _lastSeenMs,
    });
    final write = _pendingWrite.then((_) => _writeAtomically(snapshot));
    _pendingWrite = write.catchError((Object error) {
      debugPrint('Kullanım dosyası yazılamadı: $error');
    });
    return _pendingWrite;
  }

  Future<void> _writeAtomically(String content) async {
    final file = await _file();
    await file.parent.create(recursive: true);
    final tempFile = File('${file.path}.tmp');
    await tempFile.writeAsString(content, flush: true);
    await tempFile.rename(file.path);
  }

  Future<File> _file() async {
    final directory = await _directoryProvider();
    return File('${directory.path}${Platform.pathSeparator}$fileName');
  }

  static final RegExp _dayKeyPattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');

  static String _readDayKey(Object? value) =>
      value is String && _dayKeyPattern.hasMatch(value) ? value : '';

  static int _readCount(Object? value) => value is int && value > 0 ? value : 0;
}
