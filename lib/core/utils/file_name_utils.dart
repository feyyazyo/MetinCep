import '../constants/app_constants.dart';

class FileNameUtils {
  FileNameUtils._();

  /// Dosya adında kullanılamayan karakterleri temizler.
  static String sanitize(String input, {String fallback = 'MetinCep'}) {
    final cleaned = input
        .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .replaceAll(RegExp(r'[. ]+$'), '');
    if (cleaned.isEmpty) {
      return fallback;
    }
    if (cleaned.length > AppConstants.titleMaxLength) {
      return cleaned.substring(0, AppConstants.titleMaxLength).trim();
    }
    return cleaned;
  }

  /// "fatura.pdf" -> "fatura"
  static String withoutExtension(String fileName) {
    final dotIndex = fileName.lastIndexOf('.');
    if (dotIndex <= 0) {
      return fileName;
    }
    return fileName.substring(0, dotIndex);
  }
}
