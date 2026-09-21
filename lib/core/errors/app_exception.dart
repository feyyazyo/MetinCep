/// Kullanıcıya gösterilebilir, anlaşılır mesaj taşıyan hata.
class AppException implements Exception {
  const AppException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Kullanıcı işlemi iptal ettiğinde fırlatılır.
class OperationCancelledException extends AppException {
  const OperationCancelledException() : super('İşlem iptal edildi.');
}

/// Uygulamadaki tüm hata metinleri tek yerde.
class ErrorMessages {
  ErrorMessages._();

  static const String noTextInImage =
      'Metin okunamadı. Fotoğrafı daha net çekmeyi deneyin.';
  static const String pdfOpenFailed =
      'PDF açılamadı. Dosyanın geçerli bir PDF olduğundan emin olun.';
  static const String pdfPasswordProtected =
      "Bu PDF şifreli. Şifreli PDF'ler şimdilik desteklenmiyor.";
  static const String noTextInPdf = "PDF'de okunabilir metin bulunamadı.";
  static const String cameraFailed =
      'Kameraya erişilemedi. Lütfen kamera iznini kontrol edin.';
  static const String galleryFailed =
      'Galeriye erişilemedi. Lütfen fotoğraf erişim iznini kontrol edin.';
  static const String filePickFailed =
      'Dosya seçilemedi. Lütfen tekrar deneyin.';
  static const String saveFailed =
      'Kayıt sırasında bir sorun oluştu. Lütfen tekrar deneyin.';
  static const String deleteFailed =
      'Belge silinemedi. Lütfen tekrar deneyin.';
  static const String shareFailed = 'Paylaşım başlatılamadı.';
  static const String fileSaveFailed = 'TXT dosyası kaydedilemedi.';
}
