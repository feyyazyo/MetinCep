import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:metincep/models/ocr_mode.dart';
import 'package:metincep/services/image_preprocessor.dart';
import '../helpers/temp_dir.dart';

/// Yatay "metin satırları" çizer. [skewDegrees] verilirse satırlar eğik çizilir.
img.Image buildDocument({
  int width = 300,
  int height = 200,
  double skewDegrees = 0,
  List<int> baselines = const [40, 90, 140],
}) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(255, 255, 255));
  final slope = math.tan(skewDegrees * math.pi / 180.0);

  for (var x = 0; x < width; x++) {
    for (final baseline in baselines) {
      final y = baseline + (x * slope).round();
      for (var thickness = 0; thickness < 3; thickness++) {
        final targetY = y + thickness;
        if (targetY >= 0 && targetY < height) {
          image.setPixelRgb(x, targetY, 20, 20, 20);
        }
      }
    }
  }
  return image;
}

void main() {
  group('Eğiklik tahmini', () {
    test('düz belgede eğiklik ~0', () {
      final skew = ImagePreprocessor.estimateSkewDegrees(buildDocument());
      expect(skew.abs(), lessThanOrEqualTo(ImagePreprocessor.skewStepDegrees));
    });

    test('3 derece eğik belgede ~3 bulunur', () {
      final skew =
          ImagePreprocessor.estimateSkewDegrees(buildDocument(skewDegrees: 3));
      expect(skew, closeTo(3, 0.75));
    });

    test('-2 derece eğik belgede ~-2 bulunur', () {
      final skew =
          ImagePreprocessor.estimateSkewDegrees(buildDocument(skewDegrees: -2));
      expect(skew, closeTo(-2, 0.75));
    });

    test('boş (metinsiz) görüntüde 0 döner', () {
      final blank = img.Image(width: 100, height: 100);
      img.fill(blank, color: img.ColorRgb8(255, 255, 255));
      expect(ImagePreprocessor.estimateSkewDegrees(blank), 0);
    });

    test('çok küçük görüntüde 0 döner', () {
      final tiny = img.Image(width: 4, height: 4);
      expect(ImagePreprocessor.estimateSkewDegrees(tiny), 0);
    });
  });

  group('El yazısı profili', () {
    test('gri tonlamaya çevirir ve boyutu korur', () {
      final processed = ImagePreprocessor.enhanceForHandwriting(buildDocument());

      expect(processed.width, 300);
      expect(processed.height, 200);
      final pixel = processed.getPixel(10, 10);
      expect(pixel.r, pixel.g);
      expect(pixel.g, pixel.b);
    });

    test('çok büyük görüntüyü küçültür', () {
      final large = buildDocument(width: 3000, height: 400, baselines: [100, 200]);
      final processed = ImagePreprocessor.enhanceForHandwriting(large);

      expect(processed.width, lessThanOrEqualTo(2560));
      expect(processed.width, greaterThan(2000));
    });

    test('eğik belgeyi düzeltir (eğiklik azalır)', () {
      final skewed = buildDocument(skewDegrees: 3);
      final processed = ImagePreprocessor.enhanceForHandwriting(skewed);
      final remaining = ImagePreprocessor.estimateSkewDegrees(processed);

      expect(remaining.abs(), lessThan(3));
    });
  });

  group('İkili (siyah-beyaz) ikinci geçiş', () {
    test('çıktı yalnızca siyah ve beyaz içerir', () {
      final binary =
          ImagePreprocessor.binarizeForHandwriting(buildDocument());

      var checked = 0;
      for (var y = 0; y < binary.height; y += 7) {
        for (var x = 0; x < binary.width; x += 11) {
          final value = binary.getPixel(x, y).luminanceNormalized.toDouble();
          expect(value < 0.02 || value > 0.98, isTrue,
              reason: '($x,$y) ikili değil: $value');
          checked++;
        }
      }
      expect(checked, greaterThan(100));
    });

    test('metin satırları ikili çıktıda korunur', () {
      final binary = ImagePreprocessor.binarizeForHandwriting(buildDocument());
      // buildDocument 40, 90, 140 taban çizgilerine 3 piksel kalınlığında
      // koyu satırlar çizer; eşiklemeden sonra siyah kalmalılar.
      final middle = binary.width ~/ 2;
      var darkRows = 0;
      for (var y = 0; y < binary.height; y++) {
        if (binary.getPixel(middle, y).luminanceNormalized < 0.5) {
          darkRows++;
        }
      }
      expect(darkRows, greaterThanOrEqualTo(6),
          reason: 'üç satırın çoğu koyu kalmalı');
    });
  });

  group('prepare()', () {
    late Directory directory;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('metincep_pre_test_');
    });

    tearDown(() async {
      await deleteTempDirectory(directory);
    });

    test('basılı metin modunda görüntüye dokunulmaz (null döner)', () async {
      const preprocessor = ImagePreprocessor();
      final result = await preprocessor.prepare(
        sourcePath: '${directory.path}/yok.jpg',
        targetPath: '${directory.path}/cikti.jpg',
        mode: OcrMode.printed,
      );

      expect(result, isNull);
      expect(File('${directory.path}/cikti.jpg').existsSync(), isFalse);
    });

    test('okunamayan dosyada null döner, uygulama çökmez', () async {
      const preprocessor = ImagePreprocessor();
      final broken = File('${directory.path}/bozuk.jpg')
        ..writeAsBytesSync(const [1, 2, 3, 4, 5]);

      final result = await preprocessor.prepare(
        sourcePath: broken.path,
        targetPath: '${directory.path}/cikti.jpg',
        mode: OcrMode.handwriting,
      );

      expect(result, isNull);
    });

    test('prepareBinary ikili dosya üretir (iyileştirilmiş kaynak)', () async {
      const preprocessor = ImagePreprocessor();
      final source = File('${directory.path}/kaynak2.jpg')
        ..writeAsBytesSync(img.encodeJpg(buildDocument(), quality: 95));
      final targetPath = '${directory.path}/ikili.jpg';

      final result = await preprocessor.prepareBinary(
        sourcePath: source.path,
        targetPath: targetPath,
        alreadyEnhanced: true,
      );

      expect(result, targetPath);
      final decoded = img.decodeImage(File(targetPath).readAsBytesSync());
      expect(decoded, isNotNull);
      // JPEG sıkıştırması uçları biraz yumuşatır; yine de iki kutupta kalmalı.
      var extremes = 0;
      var total = 0;
      for (var y = 0; y < decoded!.height; y += 9) {
        for (var x = 0; x < decoded.width; x += 13) {
          final value = decoded.getPixel(x, y).luminanceNormalized.toDouble();
          total++;
          if (value < 0.15 || value > 0.85) {
            extremes++;
          }
        }
      }
      expect(extremes / total, greaterThan(0.9));
    });

    test('prepareBinary okunamayan dosyada null döner', () async {
      const preprocessor = ImagePreprocessor();
      final broken = File('${directory.path}/bozuk2.jpg')
        ..writeAsBytesSync(const [7, 7, 7]);

      final result = await preprocessor.prepareBinary(
        sourcePath: broken.path,
        targetPath: '${directory.path}/cikti2.jpg',
      );

      expect(result, isNull);
    });

    test('el yazısı modunda işlenmiş dosya üretir', () async {
      const preprocessor = ImagePreprocessor();
      final source = File('${directory.path}/kaynak.jpg')
        ..writeAsBytesSync(img.encodeJpg(buildDocument(), quality: 90));
      final targetPath = '${directory.path}/islenmis.jpg';

      final result = await preprocessor.prepare(
        sourcePath: source.path,
        targetPath: targetPath,
        mode: OcrMode.handwriting,
      );

      expect(result, targetPath);
      final output = File(targetPath);
      expect(output.existsSync(), isTrue);
      expect(output.lengthSync(), greaterThan(0));
      expect(img.decodeImage(output.readAsBytesSync()), isNotNull);
    });
  });
}
