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

  /// PDF çıktısında kullanılan Unicode yazı tipi (Türkçe ş, ğ, İ, ı için şart).
  /// PDF'in yerleşik fontları Türkçe harfleri içermez.
  static const String pdfFontAsset = 'assets/fonts/DejaVuSans.ttf';

  /// Fotoğraf → PDF: görüntünün uzun kenarı en fazla bu kadar piksele indirilir
  /// (A4 ~150 dpi). Hem dosya boyutunu hem RAM kullanımını sınırlar.
  static const int pdfImageMaxDimension = 1754;
  static const int pdfImageQuality = 85;

  /// Tek PDF'te üretilebilecek en fazla sayfa (kütüphane koruması).
  static const int pdfMaxPages = 500;

  /// Bu kadar veya daha fazla kolonlu tablolar yatay (landscape) sayfaya basılır.
  static const int pdfTableLandscapeColumnCount = 5;

  /// **Sınırsız test derlemesi.** Yalnızca geliştiricinin kendi cihazında
  /// denemesi içindir.
  ///
  /// Derleme zamanı sabitidir; tanımlanmazsa **false**'tur:
  /// ```
  /// flutter build apk --release --dart-define=METINCEP_TEST_BUILD=true
  /// ```
  /// Mağazaya gidecek derlemede bu tanım VERİLMEZ, dolayısıyla kod ağaçtan
  /// atılır ve kullanıcı hiçbir şekilde ücretsiz Pro alamaz.
  /// `tool/verify_release_guards.sh` bunu her derlemede doğrular.
  static const bool isTestBuild = bool.fromEnvironment('METINCEP_TEST_BUILD');

  /// Aranabilir PDF'teki görünmez metnin yazı boyu sınırları (punto).
  /// Çok küçük kutularda metin seçilemez hâle gelmesin, çok büyük kutularda
  /// da sayfa dışına taşmasın diye sınırlanır.
  static const double searchableMinFontSize = 2;
  static const double searchableMaxFontSize = 72;
}
