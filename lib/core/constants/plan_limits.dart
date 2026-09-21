/// Free / Pro kullanım sınırlarının TEK kaynağı.
///
/// Uygulamanın başka hiçbir yerinde "10", "3" gibi sınır sayıları yazılmaz;
/// ekranlar ve servisler değerleri buradan okur. Sınırı değiştirmek için
/// yalnızca [FreeLimits] içindeki sabitleri güncelleyin.
class PlanLimits {
  const PlanLimits({
    this.dailyOcrOperations,
    this.dailyPdfOperations,
    this.maxPdfPages,
    this.maxImagesPerBatch,
    this.maxPdfFileSizeBytes,
  });

  /// Günlük fotoğraf OCR işlemi (bir kamera/galeri işlemi = 1; toplu seçim de 1 sayılır).
  /// null = sınırsız.
  final int? dailyOcrOperations;

  /// Günlük PDF işlemi. null = sınırsız.
  final int? dailyPdfOperations;

  /// Tek PDF'te işlenebilecek en fazla sayfa. null = sınırsız.
  final int? maxPdfPages;

  /// Tek seferde işlenebilecek en fazla fotoğraf. null = sınırsız.
  final int? maxImagesPerBatch;

  /// İşlenebilecek en büyük PDF dosyası (bayt). null = sınırsız.
  final int? maxPdfFileSizeBytes;
}

class FreeLimits {
  FreeLimits._();

  static const int dailyOcrOperations = 10;
  static const int dailyPdfOperations = 3;
  static const int maxPdfPages = 10;
  static const int maxImagesPerBatch = 3;
  static const int maxPdfFileSizeMb = 25;

  static const PlanLimits plan = PlanLimits(
    dailyOcrOperations: dailyOcrOperations,
    dailyPdfOperations: dailyPdfOperations,
    maxPdfPages: maxPdfPages,
    maxImagesPerBatch: maxImagesPerBatch,
    maxPdfFileSizeBytes: maxPdfFileSizeMb * 1024 * 1024,
  );
}

class ProLimits {
  ProLimits._();

  /// Pro: tüm sınırlar kaldırılır. İleride bir üst sınır gerekirse burada tanımlanır.
  static const PlanLimits plan = PlanLimits();
}
