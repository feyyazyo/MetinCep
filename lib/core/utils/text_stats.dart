/// Düzenleyicinin altında gösterilen karakter / kelime sayısı.
/// Uzun PDF metinlerinde her tuşta çalıştığı için tek geçişte, regex'siz hesaplanır.
class TextStats {
  const TextStats({required this.characters, required this.words});

  final int characters;
  final int words;

  static TextStats of(String text) {
    var characters = 0;
    var words = 0;
    var inWord = false;

    for (var index = 0; index < text.length; index++) {
      final unit = text.codeUnitAt(index);
      // Emoji gibi iki kod birimlik karakterlerin ikinci yarısı sayılmaz.
      if (unit >= 0xDC00 && unit <= 0xDFFF) {
        continue;
      }
      characters++;
      if (_isWhitespace(unit)) {
        inWord = false;
      } else if (!inWord) {
        inWord = true;
        words++;
      }
    }
    return TextStats(characters: characters, words: words);
  }

  static bool _isWhitespace(int unit) =>
      unit == 0x20 || // boşluk
      (unit >= 0x09 && unit <= 0x0D) || // \t \n \v \f \r
      unit == 0xA0 || // bölünmez boşluk
      unit == 0x2007 ||
      unit == 0x202F ||
      unit == 0x3000 ||
      (unit >= 0x2000 && unit <= 0x200A) ||
      unit == 0x2028 ||
      unit == 0x2029;

  /// 12500 -> "12.500"
  static String formatCount(int value) {
    final digits = value.abs().toString();
    final buffer = StringBuffer(value < 0 ? '-' : '');
    for (var index = 0; index < digits.length; index++) {
      if (index > 0 && (digits.length - index) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(digits[index]);
    }
    return buffer.toString();
  }
}
