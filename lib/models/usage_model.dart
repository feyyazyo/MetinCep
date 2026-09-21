/// Bir güne ait Free kullanım sayaçları.
class DailyUsage {
  const DailyUsage({required this.dayKey, required this.ocrCount, required this.pdfCount});

  /// Yerel tarih: YYYY-MM-DD (sözlük sırası = tarih sırası).
  final String dayKey;
  final int ocrCount;
  final int pdfCount;

  static String dayKeyOf(DateTime date) {
    final local = date.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year.toString().padLeft(4, '0')}-$month-$day';
  }
}
