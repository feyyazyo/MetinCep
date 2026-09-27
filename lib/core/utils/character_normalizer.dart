/// OCR'ın sık yaptığı rakam/harf karışmalarını **bağlam kontrollü** düzeltir.
///
/// Amaç: `ME2AR` → `MEZAR`, `5ELAM` → `SELAM` gibi kelime içi hataları düzeltmek,
/// ama sayıyı, tarihi, telefonu, para tutarını ve seri/ürün kodunu ASLA bozmamak.
///
/// Global "her 2'yi Z yap" replace KESİNLİKLE yapılmaz. Bir rakam yalnızca şu
/// koşulların tamamı sağlanırsa harfe çevrilir:
///
/// 1. Jeton korumalı bir kalıba uymuyor (tarih, saat, telefon, para, yüzde,
///    binlik ayraçlı sayı, e-posta, adres, seri kodu).
/// 2. Jetonda en az [minLetters] harf var ve harf oranı [minAlphabeticRatio]
///    değerinin altına düşmüyor (bu, `A2B5C9` gibi kodları korur).
/// 3. Rakamın her iki yanındaki komşu karakter harf (ya da jeton başı/sonunda,
///    tek komşu harf). Böylece `2025`, `PLAKA25` gibi rakam kümeleri korunur.
/// 4. OCR güven değeri biliniyorsa [minConfidence] eşiğinin altında değil;
///    düşük güvende ham sonuç korunur.
///
/// Türkçe harflere (ç, ğ, ı, İ, ö, ş, ü) dokunulmaz.
class CharacterNormalizer {
  CharacterNormalizer._();

  /// Rakam → büyük harf eşlemesi. Yalnızca OCR'da en sık karışan ikili tutulur;
  /// liste bilinçli olarak kısadır, çünkü her yeni eşleme yanlış düzeltme riskidir.
  static const Map<String, String> digitToLetter = {'2': 'Z', '5': 'S'};

  /// Bu değerin altındaki güvende düzeltme yapılmaz, ham metin korunur.
  static const double minConfidence = 0.35;

  /// Jetondaki en az harf oranı (harf / (harf + rakam)).
  static const double minAlphabeticRatio = 0.6;

  /// Jetonda en az bu kadar harf olmalı.
  static const int minLetters = 3;

  /// Jetondaki en fazla rakam oranı.
  static const double maxDigitRatio = 0.4;

  static const String _lowerLetters = 'abcdefghijklmnopqrstuvwxyzçğıöşüâîû';
  static const String _upperLetters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZÇĞIİÖŞÜÂÎÛ';

  static final RegExp _token = RegExp(r'\S+');
  static final RegExp _date =
      RegExp(r'^\d{1,4}[./\-]\d{1,2}([./\-]\d{2,4})?$');
  static final RegExp _time = RegExp(r'^\d{1,2}[:.]\d{2}(:\d{2})?$');
  static final RegExp _groupedNumber =
      RegExp(r'^\d{1,3}([.,]\d{3})*([.,]\d+)?$');
  static final RegExp _phoneLike = RegExp(r'^[+()\d][\d()\-+\s/]*$');
  static const List<String> _currencyMarkers = [
    'TL',
    '₺',
    'TRY',
    r'$',
    'USD',
    '€',
    'EUR',
    '£',
    'GBP',
    '%',
  ];

  static bool isLetter(String char) =>
      _lowerLetters.contains(char) || _upperLetters.contains(char);

  static bool isDigit(String char) => char.length == 1 && '0123456789'.contains(char);

  /// Tüm metni jeton jeton işler; boşluklar ve satır sonları birebir korunur.
  static NormalizationResult normalizeText(String text, {double? confidence}) {
    if (text.isEmpty) {
      return NormalizationResult(text: text, changes: const []);
    }
    if (confidence != null && confidence < minConfidence) {
      // OCR kendinden emin değil: ham sonucu bozmak yerine olduğu gibi bırak.
      return NormalizationResult(text: text, changes: const []);
    }

    final changes = <NormalizationChange>[];
    final normalized = text.splitMapJoin(
      _token,
      onMatch: (match) {
        final original = match[0]!;
        final fixed = _normalizeToken(original);
        if (fixed != original) {
          changes.add(NormalizationChange(before: original, after: fixed));
        }
        return fixed;
      },
      onNonMatch: (nonMatch) => nonMatch,
    );

    return NormalizationResult(text: normalized, changes: changes);
  }

  /// Bir jetonu (boşluksuz parça) düzeltir. Değişmemesi gerekiyorsa aynısını döner.
  static String _normalizeToken(String token) {
    // Baştaki ve sondaki noktalama işaretlerini ayır, sonuna aynen geri ekle.
    var start = 0;
    var end = token.length;
    while (start < end && !isLetter(token[start]) && !isDigit(token[start])) {
      start++;
    }
    while (end > start && !isLetter(token[end - 1]) && !isDigit(token[end - 1])) {
      end--;
    }
    if (start >= end) {
      return token;
    }

    final prefix = token.substring(0, start);
    final core = token.substring(start, end);
    final suffix = token.substring(end);

    if (!_canNormalize(core, token)) {
      return token;
    }

    final buffer = StringBuffer();
    var changed = false;
    for (var index = 0; index < core.length; index++) {
      final char = core[index];
      final replacement = digitToLetter[char];
      if (replacement != null && _digitIsInsideWord(core, index)) {
        buffer.write(_matchCase(core, index, replacement));
        changed = true;
      } else {
        buffer.write(char);
      }
    }

    if (!changed) {
      return token;
    }
    final fixedCore = buffer.toString();
    return '$prefix$fixedCore$suffix';
  }

  /// Jeton düzeltilebilir mi? Korumalı kalıplar burada elenir.
  static bool _canNormalize(String core, String fullToken) {
    // E-posta, adres, dosya yolu: dokunulmaz.
    if (fullToken.contains('@') || fullToken.contains('://') || fullToken.contains('\\')) {
      return false;
    }
    if (_date.hasMatch(core) || _time.hasMatch(core) || _groupedNumber.hasMatch(core)) {
      return false;
    }

    var letters = 0;
    var digits = 0;
    var hasMappedDigit = false;
    for (var index = 0; index < core.length; index++) {
      final char = core[index];
      if (isLetter(char)) {
        letters++;
      } else if (isDigit(char)) {
        digits++;
        if (digitToLetter.containsKey(char)) {
          hasMappedDigit = true;
        }
      }
    }

    if (!hasMappedDigit || digits == 0) {
      return false; // Düzeltilecek bir şey yok.
    }
    if (letters < minLetters) {
      return false; // "A2B", "5" gibi kısa/kodsu jetonlar korunur.
    }

    final total = letters + digits;
    if (letters / total < minAlphabeticRatio) {
      return false; // "A2B5C9" gibi alfanümerik kodlar korunur.
    }
    if (digits / total > maxDigitRatio) {
      return false;
    }

    // Telefon / para / yüzde: rakam ağırlıklı içerik korunur.
    if (_phoneLike.hasMatch(core)) {
      return false;
    }
    final upperToken = fullToken.toUpperCase();
    for (final marker in _currencyMarkers) {
      if (upperToken.contains(marker.toUpperCase()) && digits > 0) {
        // "2500TL" gibi tutarlar korunur; "TL" tek başına rakam içermez.
        return false;
      }
    }

    return true;
  }

  /// Rakam gerçekten kelimenin içinde mi? Komşuları harf olmalı.
  static bool _digitIsInsideWord(String core, int index) {
    final hasPrevious = index > 0;
    final hasNext = index < core.length - 1;
    final previousIsLetter = hasPrevious && isLetter(core[index - 1]);
    final nextIsLetter = hasNext && isLetter(core[index + 1]);

    if (hasPrevious && hasNext) {
      return previousIsLetter && nextIsLetter;
    }
    if (hasNext) {
      return nextIsLetter; // Jeton başı: "5ELAM"
    }
    if (hasPrevious) {
      return previousIsLetter; // Jeton sonu: "SELAM5"
    }
    return false;
  }

  /// Komşu harflerin büyük/küçük durumuna göre harfi seçer.
  static String _matchCase(String core, int index, String upperReplacement) {
    for (var offset = 1; offset < core.length; offset++) {
      for (final candidate in [index - offset, index + offset]) {
        if (candidate < 0 || candidate >= core.length) {
          continue;
        }
        final char = core[candidate];
        if (_upperLetters.contains(char)) {
          return upperReplacement;
        }
        if (_lowerLetters.contains(char)) {
          return upperReplacement.toLowerCase();
        }
      }
    }
    return upperReplacement;
  }
}

/// Tek bir jetonda yapılan düzeltme (kullanıcıya/raporlamaya göstermek için).
class NormalizationChange {
  const NormalizationChange({required this.before, required this.after});

  final String before;
  final String after;

  @override
  String toString() => '$before → $after';
}

class NormalizationResult {
  const NormalizationResult({required this.text, required this.changes});

  final String text;
  final List<NormalizationChange> changes;

  int get changeCount => changes.length;

  bool get hasChanges => changes.isNotEmpty;
}
