import 'dart:io';
import 'dart:typed_data';

/// PDF yazı tipini testlerde doğrudan dosyadan okur.
/// Böylece testler asset paketine (rootBundle) bağımlı olmaz.
///
/// Ayrı dosyada tutulur: burada `dart:typed_data` `ByteData` adını sağlayan
/// tek içe alımdır, yani gereksiz içe alım uyarısı doğmaz.
Future<ByteData> testFontLoader() async {
  final bytes = await File('assets/fonts/DejaVuSans.ttf').readAsBytes();
  return ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.lengthInBytes);
}
