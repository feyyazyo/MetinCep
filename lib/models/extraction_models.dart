import 'document_model.dart';

/// Metin çıkarma isteği. V2'de yeni kaynak türleri (ör. Word) buraya eklenebilir.
abstract class ExtractionRequest {
  const ExtractionRequest();

  DocumentSource get source;
}

/// Bir veya birden fazla fotoğraf (toplu işleme hazır).
class ImageExtractionRequest extends ExtractionRequest {
  const ImageExtractionRequest({required this.imagePaths, required this.source});

  final List<String> imagePaths;

  @override
  final DocumentSource source;
}

class PdfExtractionRequest extends ExtractionRequest {
  const PdfExtractionRequest({
    required this.pdfPath,
    required this.fileName,
    this.maxPages,
  });

  final String pdfPath;
  final String fileName;

  /// İşlenecek en fazla sayfa. null = sınırsız. Aşılırsa servis karar ister
  /// (bkz. [PageLimitResolver]); servis bu sınırın nereden geldiğini bilmez.
  final int? maxPages;

  @override
  DocumentSource get source => DocumentSource.pdf;
}

/// PDF sayfa sınırı aşıldığında verilecek karar.
enum PageLimitDecision { processAll, processFirstPages, cancel }

typedef PageLimitResolver = Future<PageLimitDecision> Function(int pageCount, int maxPages);

enum ProgressUnit {
  image('görsel'),
  page('sayfa');

  const ProgressUnit(this.label);

  final String label;
}

class ExtractionProgress {
  const ExtractionProgress({
    required this.completed,
    required this.total,
    required this.unit,
    this.detail,
  });

  final int completed;
  final int total;
  final ProgressUnit unit;
  final String? detail;

  /// Tek görsel/sayfada gerçek ilerleme bilinemez; belirsiz gösterge kullanılır.
  bool get isDeterminate => total > 1;

  double get fraction => total <= 0 ? 0 : (completed / total).clamp(0.0, 1.0);

  int get percent => (fraction * 100).round();
}

class ExtractionResult {
  const ExtractionResult({
    required this.text,
    required this.source,
    this.suggestedTitle,
    this.unitCount = 1,
    this.ocrUnitCount = 0,
    this.sourcePageCount,
  });

  final String text;
  final DocumentSource source;
  final String? suggestedTitle;

  /// İşlenen sayfa / görsel sayısı.
  final int unitCount;

  /// OCR'dan geçirilen sayfa / görsel sayısı (PDF metin katmanı okunanlar hariç).
  final int ocrUnitCount;

  /// PDF'in toplam sayfa sayısı. [unitCount]'tan büyükse yalnızca ilk sayfalar işlenmiştir.
  final int? sourcePageCount;

  bool get isPartial => sourcePageCount != null && sourcePageCount! > unitCount;
}
