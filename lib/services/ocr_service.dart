import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../core/utils/text_layout_formatter.dart';

/// Tek bir görüntüden çıkan yapısal OCR sonucu.
///
/// Sonuç yalnızca String olarak taşınmaz: satır/kelime koordinatları ve güven
/// değerleri korunur. Tablo algılama ve karakter normalizasyonu bu veriye dayanır.
class OcrPage {
  const OcrPage({
    required this.blocks,
    required this.rawText,
    this.averageConfidence,
  });

  static const OcrPage empty = OcrPage(blocks: [], rawText: '');

  final List<OcrBlock> blocks;

  /// Ham (düzeltilmemiş) OCR metni, satır ve paragraf yapısı korunmuş halde.
  final String rawText;

  /// Satır güven değerlerinin ortalaması (0..1). ML Kit yalnızca Android'de verir.
  final double? averageConfidence;

  List<OcrLine> get lines =>
      blocks.expand((block) => block.lines).toList(growable: false);

  bool get isEmpty => rawText.trim().isEmpty;
}

/// Cihaz üzerinde çalışan OCR (Google ML Kit, Latin alfabesi modeli).
/// Latin modeli Türkçe (ç, ğ, ı, İ, ö, ş, ü) ve İngilizce dahil Latin alfabeli dilleri okur.
/// Görüntüler internete gönderilmez.
///
/// Bu sınıf Free/Pro, normalizasyon ve tablo mantığını bilmez; yalnızca tanıma yapar.
class OcrService {
  TextRecognizer? _recognizer;

  TextRecognizer get _activeRecognizer =>
      _recognizer ??= TextRecognizer(script: TextRecognitionScript.latin);

  /// Görüntü dosyasını tanır ve yapısal sonucu döndürür.
  /// EXIF yönü ML Kit tarafından dikkate alınır.
  Future<OcrPage> recognizeFile(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final recognizedText = await _activeRecognizer.processImage(inputImage);

    final blocks = <OcrBlock>[];
    final confidences = <double>[];

    for (final block in recognizedText.blocks) {
      final lines = <OcrLine>[];
      for (final line in block.lines) {
        final confidence = line.confidence;
        if (confidence != null) {
          confidences.add(confidence);
        }
        lines.add(
          OcrLine(
            text: line.text,
            top: line.boundingBox.top,
            bottom: line.boundingBox.bottom,
            left: line.boundingBox.left,
            right: line.boundingBox.right,
            confidence: confidence,
            words: line.elements
                .map(
                  (element) => OcrWord(
                    text: element.text,
                    left: element.boundingBox.left,
                    right: element.boundingBox.right,
                    top: element.boundingBox.top,
                    bottom: element.boundingBox.bottom,
                    confidence: element.confidence,
                  ),
                )
                .toList(),
          ),
        );
      }
      blocks.add(OcrBlock(lines));
    }

    final formatted = TextLayoutFormatter.formatBlocks(blocks);
    final rawText = formatted.isNotEmpty
        ? formatted
        : TextLayoutFormatter.normalize(recognizedText.text);

    return OcrPage(
      blocks: blocks,
      rawText: rawText,
      averageConfidence: confidences.isEmpty
          ? null
          : confidences.reduce((a, b) => a + b) / confidences.length,
    );
  }

  Future<void> dispose() async {
    final recognizer = _recognizer;
    _recognizer = null;
    await recognizer?.close();
  }
}
