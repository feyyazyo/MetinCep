import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Geçerli hiçbir görüntü dosyası bundan küçük olamaz (en kısa başlık ~13 bayt).
const int minimumImageBytes = 16;

/// Görüntü dosyasını **güvenle** çözer; başarısızsa `null` döner.
///
/// Neden gerekli: `image` paketinin biçim tanıma kodu (`decodeImage` →
/// `findDecoderForData`) bozuk veya çok küçük dosyalarda istisna atabilir.
/// Örneğin 3 baytlık bir dosyada PSD çözücüsü başlıktan 4 baytlık bir sayı
/// okumaya çalışır ve `RangeError` atar. Bu durum uygulamada "fotoğraf
/// okunamadı" mesajı verilmesi gereken normal bir haldir; istisna olarak
/// yukarı taşınmamalıdır.
///
/// Dosya yoksa, okunamıyorsa, çok küçükse veya biçim tanınmıyorsa `null` döner.
/// `compute` içinde (isolate) çağrılabilir: platform kanalı kullanmaz.
img.Image? decodeImageFileSafely(String path) {
  try {
    final file = File(path);
    if (!file.existsSync()) {
      return null;
    }
    final bytes = file.readAsBytesSync();
    if (bytes.length < minimumImageBytes) {
      return null;
    }
    return img.decodeImage(bytes);
  } catch (error) {
    // RangeError dahil her şey yakalanır: burada tek iş "çözülemedi" demektir.
    debugPrint('Görüntü çözülemedi ($path): $error');
    return null;
  }
}
