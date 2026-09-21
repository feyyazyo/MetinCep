/// Uygulama genelinde kullanılan sabitler.
class AppConstants {
  AppConstants._();

  static const String appName = 'MetinCep';
  static const String appTagline = "Fotoğraf ve PDF'lerden hızlıca metin çıkarın.";
  static const String appVersion = '1.0.0';

  /// OCR öncesi fotoğrafın uzun kenarı en fazla bu kadar piksel olur (RAM tasarrufu).
  static const double imageMaxDimension = 2560;
  static const int imageQuality = 92;

  /// Taranmış PDF sayfaları bu çözünürlükte görüntüye çevrilir.
  static const double pdfRenderDpi = 200;
  static const double pdfRenderMaxDimension = 2400;
  static const double pdfRenderMinDimension = 1400;

  /// Bir PDF sayfasının metin katmanında bundan az görünür karakter varsa sayfa OCR'dan geçirilir.
  static const int minTextLayerChars = 20;

  /// Bundan uzun metinler, Android sınırlarına takılmamak için TXT dosyası olarak paylaşılır.
  static const int shareAsFileThreshold = 100000;

  static const int recentDocumentsLimit = 5;
  static const int previewMaxChars = 120;
  static const int titleMaxLength = 80;
}
