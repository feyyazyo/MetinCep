import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../core/utils/text_layout_formatter.dart';

/// Cihaz üzerinde çalışan OCR (Google ML Kit, Latin alfabesi modeli).
/// Latin modeli Türkçe (ç, ğ, ı, İ, ö, ş, ü) ve İngilizce dahil Latin alfabeli dilleri okur.
/// Görüntüler internete gönderilmez.
class OcrService {
  TextRecognizer? _recognizer;

  TextRecognizer get _activeRecognizer =>
      _recognizer ??= TextRecognizer(script: TextRecognitionScript.latin);

  /// Görüntü dosyasındaki metni satır ve paragraf yapısını koruyarak döndürür.
  /// EXIF yönü ML Kit tarafından dikkate alınır.
  Future<String> recognizeFile(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final recognizedText = await _activeRecognizer.processImage(inputImage);

    final blocks = recognizedText.blocks
        .map(
          (block) => OcrBlock(
            block.lines
                .map(
                  (line) => OcrLine(
                    text: line.text,
                    top: line.boundingBox.top,
                    bottom: line.boundingBox.bottom,
                  ),
                )
                .toList(),
          ),
        )
        .toList();

    final formatted = TextLayoutFormatter.formatBlocks(blocks);
    return formatted.isNotEmpty
        ? formatted
        : TextLayoutFormatter.normalize(recognizedText.text);
  }

  Future<void> dispose() async {
    final recognizer = _recognizer;
    _recognizer = null;
    await recognizer?.close();
  }
}
