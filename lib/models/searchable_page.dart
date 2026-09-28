/// Aranabilir PDF için tek bir sayfanın verisi:
/// fotoğrafın kendisi + üzerine yerleştirilecek görünmez metin.
///
/// Koordinatlar **0..1 aralığında normalize** edilir (OCR yapılan görüntünün
/// en/boyuna göre). Böylece fotoğraf PDF'e küçültülerek yerleştirilse de metin
/// doğru yere denk gelir ve ölçek bilgisi taşımaya gerek kalmaz.
class SearchablePage {
  const SearchablePage({required this.imagePath, required this.words});

  /// Sayfada gösterilecek **özgün** fotoğrafın yolu.
  final String imagePath;

  /// Görünmez metin katmanını oluşturan kelimeler.
  final List<SearchableWord> words;

  bool get hasText => words.isNotEmpty;
}

/// Görünmez metin katmanındaki tek kelime (normalize koordinatlarla).
class SearchableWord {
  const SearchableWord({
    required this.text,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  /// Karakter düzeltmesinden geçmiş metin: kopyalanan yazı, kullanıcının
  /// ekranda gördüğü metinle aynı olur.
  final String text;

  final double left;
  final double top;
  final double right;
  final double bottom;

  double get width => right - left;

  double get height => bottom - top;
}
