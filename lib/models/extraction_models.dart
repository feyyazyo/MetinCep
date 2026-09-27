import 'document_model.dart';
import 'ocr_mode.dart';
import 'ocr_table.dart';

/// Metin çıkarma isteği. V2'de yeni kaynak türleri (ör. Word) buraya eklenebilir.
abstract class ExtractionRequest {
  const ExtractionRequest();

  DocumentSource get source;
}

/// Bir veya birden fazla fotoğraf (toplu işleme hazır).
class ImageExtractionRequest extends ExtractionRequest {
  const ImageExtractionRequest({
    required this.imagePaths,
    required this.source,
    this.mode = OcrMode.printed,
  });

  final List<String> imagePaths;

  /// Basılı metin (varsayılan) veya el yazısı profili.
  final OcrMode mode;

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
    this.rawText,
    this.tables = const [],
    this.normalizationCount = 0,
    this.tableNearMiss = false,
  });

  /// Kullanıcıya gösterilen metin (karakter normalizasyonundan geçmiş hali).
  final String text;
  final DocumentSource source;
  final String? suggestedTitle;

  /// İşlenen sayfa / görsel sayısı.
  final int unitCount;

  /// OCR'dan geçirilen sayfa / görsel sayısı (PDF metin katmanı okunanlar hariç).
  final int ocrUnitCount;

  /// PDF'in toplam sayfa sayısı. [unitCount]'tan büyükse yalnızca ilk sayfalar işlenmiştir.
  final int? sourcePageCount;

  /// OCR'ın ham (düzeltilmemiş) çıktısı. Yanlış bir otomatik düzeltme olursa
  /// veri kaybolmasın diye saklanır; kullanıcı sonuç ekranından ham metne dönebilir.
  final String? rawText;

  /// Güvenilir şekilde algılanan tablolar. Boşsa metin akışı kullanılır.
  final List<OcrTable> tables;

  /// Karakter normalizasyonunda düzeltilen jeton sayısı (ör. ME2AR → MEZAR).
  final int normalizationCount;

  /// Yerleşim tabloya benziyordu ama güven eşiğini geçemedi. Metin korunur;
  /// kullanıcıya yalnızca bilgi verilir ("tablo algılanamadı").
  final bool tableNearMiss;

  bool get isPartial => sourcePageCount != null && sourcePageCount! > unitCount;

  OcrTable? get primaryTable => tables.isEmpty ? null : tables.first;

  /// Ham metin, gösterilen metinden farklıysa kullanıcıya "ham metne dön" sunulur.
  bool get hasRawDifference =>
      rawText != null && rawText!.trim().isNotEmpty && rawText!.trim() != text.trim();
}
