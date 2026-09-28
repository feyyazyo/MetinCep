import 'dart:io';

/// PDF'in içeriğini testlerde inceleme yardımcıları.
///
/// PDF'te nesne sözlükleri (`/Type`, `/XObject`, `/MediaBox` …) düz metindir,
/// ama **içerik akışları** (çizim komutları) Flate ile sıkıştırılmıştır.
/// Bu yardımcı akışları açar; böylece fotoğrafın sayfaya hangi ölçekle
/// yerleştirildiği gibi şeyler gerçekten doğrulanabilir.
String asLatin1(List<int> bytes) => String.fromCharCodes(bytes);

/// PDF içindeki tüm sıkıştırılmış akışları açar ve metin olarak birleştirir.
/// Açılamayan akışlar (ikili görüntü verisi vb.) sessizce atlanır.
String inflatedStreams(List<int> bytes) {
  final buffer = StringBuffer();
  final text = asLatin1(bytes);
  var index = 0;
  while (true) {
    final start = text.indexOf('stream', index);
    if (start < 0) {
      break;
    }
    var from = start + 'stream'.length;
    // "stream" sonrası CRLF veya LF gelir.
    if (from < text.length && text.codeUnitAt(from) == 0x0d) {
      from++;
    }
    if (from < text.length && text.codeUnitAt(from) == 0x0a) {
      from++;
    }
    final end = text.indexOf('endstream', from);
    if (end < 0) {
      break;
    }
    index = end + 'endstream'.length;
    try {
      buffer.writeln(asLatin1(zlib.decode(bytes.sublist(from, end))));
    } catch (_) {
      // Görüntü verisi veya sıkıştırılmamış akış: atlanır.
    }
  }
  return buffer.toString();
}

/// İçerik akışındaki görüntü yerleştirme matrislerinden çizim genişliklerini
/// çıkarır. PDF'te `w 0 0 h x y cm` + `/Ad Do` biçiminde yazılır.
List<double> imagePlacementWidths(List<int> bytes) {
  final pattern = RegExp(
    r'([\d.]+) 0 0 ([\d.]+) (-?[\d.]+) (-?[\d.]+) cm\s*/[A-Za-z0-9]+ Do',
  );
  return pattern
      .allMatches(inflatedStreams(bytes))
      .map((match) => double.parse(match.group(1)!))
      .toList(growable: false);
}
