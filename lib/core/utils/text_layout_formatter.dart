import 'dart:math' as math;

/// OCR motorundan bağımsız satır modeli (test edilebilirlik için).
class OcrLine {
  const OcrLine({required this.text, required this.top, required this.bottom});

  final String text;
  final double top;
  final double bottom;

  double get height => (bottom - top).abs();
}

/// OCR motorundan bağımsız blok (paragraf) modeli.
class OcrBlock {
  const OcrBlock(this.lines);

  final List<OcrLine> lines;

  double get top => lines.isEmpty ? 0 : lines.map((line) => line.top).reduce(math.min);

  double get bottom =>
      lines.isEmpty ? 0 : lines.map((line) => line.bottom).reduce(math.max);

  double get averageLineHeight {
    if (lines.isEmpty) {
      return 0;
    }
    final total = lines.fold<double>(0, (sum, line) => sum + line.height);
    return total / lines.length;
  }
}

/// OCR sonucunu okunabilir metne dönüştürür: satırları ve paragrafları korur,
/// noktalama, sayı ve Türkçe karakterlere dokunmaz.
class TextLayoutFormatter {
  TextLayoutFormatter._();

  /// İki blok arasındaki dikey boşluk, satır yüksekliğinin bu katından büyükse
  /// yeni paragraf (boş satır) olarak kabul edilir.
  static const double paragraphGapFactor = 0.8;

  static String formatBlocks(List<OcrBlock> blocks) {
    final buffer = StringBuffer();
    OcrBlock? previous;

    for (final block in blocks) {
      final lines = block.lines
          .map((line) => line.text.trim())
          .where((text) => text.isNotEmpty)
          .toList();
      if (lines.isEmpty) {
        continue;
      }

      if (previous != null) {
        final gap = block.top - previous.bottom;
        final reference = math.max(previous.averageLineHeight, 1.0);
        buffer.write(gap > reference * paragraphGapFactor ? '\n\n' : '\n');
      }

      buffer.write(lines.join('\n'));
      previous = block;
    }

    return normalize(buffer.toString());
  }

  /// Satır sonlarını birleştirir, satır sonu boşluklarını ve 2'den fazla boş satırı temizler.
  static String normalize(String text) {
    final unified = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final trimmedLines =
        unified.split('\n').map((line) => line.trimRight()).join('\n');
    return trimmedLines.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
  }

  /// Birden fazla sayfa/görsel varsa "Sayfa 1", "Sayfa 2" başlıklarıyla birleştirir.
  static String joinSections({
    required List<String> sections,
    required String label,
    String emptyPlaceholder = '(Bu bölümde metin bulunamadı)',
  }) {
    if (sections.isEmpty) {
      return '';
    }
    if (sections.length == 1) {
      return sections.first.trim();
    }

    final buffer = StringBuffer();
    for (var index = 0; index < sections.length; index++) {
      if (index > 0) {
        buffer.write('\n\n');
      }
      buffer.write('$label ${index + 1}\n');
      final content = sections[index].trim();
      buffer.write(content.isEmpty ? emptyPlaceholder : content);
    }
    return buffer.toString();
  }

  static int visibleCharCount(String text) =>
      text.replaceAll(RegExp(r'\s'), '').length;
}
