import '../core/utils/character_normalizer.dart';
import '../core/utils/table_detector.dart';
import '../core/utils/text_layout_formatter.dart';
import '../models/ocr_table.dart';
import '../models/table_grid_lines.dart';
import 'ocr_service.dart';

/// Tek bir OCR sayfasının işlenmiş hali.
class OcrPipelineResult {
  const OcrPipelineResult({
    required this.rawText,
    required this.text,
    this.table,
    this.normalizationCount = 0,
    this.changes = const [],
    this.tableNearMiss = false,
    this.words = const [],
  });

  static const OcrPipelineResult empty = OcrPipelineResult(rawText: '', text: '');

  /// OCR'ın verdiği ham metin (hiç düzeltilmemiş).
  final String rawText;

  /// Karakter normalizasyonundan geçmiş metin. Kullanıcı bunu düzenler.
  final String text;

  /// Güvenilir şekilde algılandıysa tablo; aksi halde null (düz metne fallback).
  final OcrTable? table;

  final int normalizationCount;

  final List<NormalizationChange> changes;

  /// Karakter düzeltmesinden geçmiş kelimeler (koordinatlarıyla birlikte).
  /// Aranabilir PDF'teki görünmez metin katmanı bunlardan kurulur; böylece
  /// kopyalanan yazı, kullanıcının ekranda gördüğü metinle birebir aynı olur.
  final List<OcrWord> words;

  /// Yerleşim tabloya benziyordu ama güven eşiğini geçemedi. Kullanıcıya
  /// "tablo algılanamadı, metin olarak gösteriliyor" demek için kullanılır;
  /// metin her durumda korunur, veri kaybolmaz.
  final bool tableNearMiss;

  bool get isEmpty => text.trim().isEmpty && rawText.trim().isEmpty;
}

/// OCR sonrası adımların tek yeri:
/// OCR → karakter normalizasyonu → tablo algılama → metin.
///
/// Free/Pro kuralları burada YOKTUR; bu katman yalnızca veriyi işler.
class OcrPipeline {
  const OcrPipeline();

  OcrPipelineResult process(OcrPage page, {TableGridLines? gridLines}) {
    if (page.blocks.isEmpty) {
      final raw = page.rawText;
      if (raw.trim().isEmpty) {
        return OcrPipelineResult.empty;
      }
      // Koordinat yok (ör. blok listesi boş): yalnızca metin normalizasyonu yapılır.
      final normalized = CharacterNormalizer.normalizeText(
        raw,
        confidence: page.averageConfidence,
      );
      return OcrPipelineResult(
        rawText: raw,
        text: normalized.text,
        normalizationCount: normalized.changeCount,
        changes: normalized.changes,
      );
    }

    final changes = <NormalizationChange>[];
    final normalizedBlocks = <OcrBlock>[];

    for (final block in page.blocks) {
      final lines = <OcrLine>[];
      for (final line in block.lines) {
        // Satır bazında güven kontrolü: düşük güvende ham satır korunur.
        final result = CharacterNormalizer.normalizeText(
          line.text,
          confidence: line.confidence,
        );
        changes.addAll(result.changes);
        // Kelimeler de aynı kurallarla düzeltilir; böylece tablo hücreleri ile
        // metin birbiriyle tutarlı olur (hücrede ME2AR, metinde MEZAR olmaz).
        final normalizedWords = line.words
            .map(
              (word) => word.copyWith(
                text: CharacterNormalizer.normalizeText(
                  word.text,
                  confidence: word.confidence ?? line.confidence,
                ).text,
              ),
            )
            .toList();
        lines.add(line.copyWith(text: result.text, words: normalizedWords));
      }
      normalizedBlocks.add(OcrBlock(lines));
    }

    final normalizedText = TextLayoutFormatter.formatBlocks(normalizedBlocks);
    // Tablo, düzeltilmiş metin üzerinden algılanır; koordinatlar değişmez.
    // Fotoğrafta tablo çizgisi bulunduysa kolon sınırları onunla doğrulanır.
    final detection = TableDetector.analyze(
      normalizedBlocks.expand((block) => block.lines).toList(),
      gridLines: gridLines,
    );

    return OcrPipelineResult(
      rawText: page.rawText,
      text: normalizedText.isEmpty ? page.rawText : normalizedText,
      table: detection.table,
      normalizationCount: changes.length,
      changes: changes,
      tableNearMiss: detection.isNearMiss,
      words: normalizedBlocks
          .expand((block) => block.lines)
          .expand((line) => line.words)
          .toList(growable: false),
    );
  }
}
