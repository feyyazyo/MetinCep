/// Türkçe'ye uygun, harf büyüklüğü ve şapka/nokta farklarını önemsemeyen arama.
///
/// "sirket" araması "ŞİRKET", "Şirket" ve "şirket" ile eşleşir.
/// Dart'ın toLowerCase() metodu "İ" harfini tek başına doğru küçültmediği için
/// önce elle dönüştürülür.
class SearchUtils {
  SearchUtils._();

  static const Map<String, String> _foldMap = {
    'ı': 'i',
    'ş': 's',
    'ğ': 'g',
    'ü': 'u',
    'ö': 'o',
    'ç': 'c',
    'â': 'a',
    'î': 'i',
    'û': 'u',
    '\u0307': '', // birleşik üst nokta
  };

  static final RegExp _foldPattern = RegExp('[ışğüöçâîû\u0307]');
  static final RegExp _whitespace = RegExp(r'\s+');

  static String fold(String input) {
    final lower = input.replaceAll('İ', 'i').replaceAll('I', 'i').toLowerCase();
    return lower
        .replaceAllMapped(_foldPattern, (match) => _foldMap[match[0]] ?? '')
        .replaceAll(_whitespace, ' ')
        .trim();
  }

  /// [query] boşsa her şey eşleşir. Birden fazla kelime varsa hepsi aranır.
  /// [foldedFields] önceden [fold] uygulanmış alanlardır.
  static bool matchesFolded(String query, String foldedFields) {
    final terms = fold(query).split(' ').where((term) => term.isNotEmpty);
    return terms.every(foldedFields.contains);
  }

  static bool matches(String query, List<String> fields) =>
      matchesFolded(query, fields.map(fold).join('\n'));
}
