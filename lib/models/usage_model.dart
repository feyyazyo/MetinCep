/// Bir güne ait Free kullanım sayaçları.
class DailyUsage {
  const DailyUsage({
    required this.dayKey,
    required this.ocrCount,
    required this.pdfCount,
    this.pdfExportCount = 0,
  });

  /// Yerel tarih: YYYY-MM-DD (sözlük sırası = tarih sırası).
  final String dayKey;

  /// Fotoğraf OCR işlemleri (kamera + galeri).
  final int ocrCount;

  /// PDF okuma (girdi) işlemleri.
  final int pdfCount;

  /// PDF oluşturma (çıktı) işlemleri: metin, fotoğraf ve tablo PDF'leri.
  final int pdfExportCount;

  static String dayKeyOf(DateTime date) {
    final local = date.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year.toString().padLeft(4, '0')}-$month-$day';
  }
}
