import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:metincep/core/utils/image_decoding.dart';

import '../helpers/temp_dir.dart';

/// Bu testler bir gerileme (regression) testidir:
/// `image` paketinin `decodeImage` çağrısı bozuk/çok küçük dosyalarda istisna
/// atabiliyor (ör. 3 baytlık dosyada PSD çözücüsü `RangeError` atıyor).
/// Uygulama bu durumda "fotoğraf okunamadı" demeli, çökmemeli.
void main() {
  late Directory directory;

  String pathOf(String name) => '${directory.path}${Platform.pathSeparator}$name';

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('metincep_decode_test_');
  });

  tearDown(() async {
    await deleteTempDirectory(directory);
  });

  test('geçerli fotoğraf çözülür', () {
    final image = img.Image(width: 40, height: 30);
    img.fill(image, color: img.ColorRgb8(120, 120, 120));
    final path = pathOf('gecerli.jpg');
    File(path).writeAsBytesSync(img.encodeJpg(image, quality: 85));

    final decoded = decodeImageFileSafely(path);

    expect(decoded, isNotNull);
    expect(decoded!.width, 40);
    expect(decoded.height, 30);
  });

  test('3 baytlık bozuk dosya istisna atmaz, null döner', () {
    final path = pathOf('bozuk.jpg');
    File(path).writeAsBytesSync(const [9, 9, 9]);

    expect(decodeImageFileSafely(path), isNull);
  });

  test('boş dosya null döner', () {
    final path = pathOf('bos.jpg');
    File(path).writeAsBytesSync(const []);

    expect(decodeImageFileSafely(path), isNull);
  });

  test('olmayan dosya null döner', () {
    expect(decodeImageFileSafely(pathOf('yok.jpg')), isNull);
  });

  test('fotoğraf olmayan içerik (uzantısı .jpg olsa da) null döner', () {
    final path = pathOf('aslinda_metin.jpg');
    File(path).writeAsStringSync('Bu bir fotoğraf değil, düz metin. ' * 10);

    expect(decodeImageFileSafely(path), isNull);
  });

  test('klasör yolu verilirse null döner, çökmez', () {
    expect(decodeImageFileSafely(directory.path), isNull);
  });
}
