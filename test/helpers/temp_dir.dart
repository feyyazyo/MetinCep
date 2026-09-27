import 'dart:io';

/// Test geçici klasörünü güvenle siler.
///
/// Neden gerekli: `UsageTracker.today` getter'ı gün değiştiğinde sayaçları
/// sıfırlar ve dosyayı **beklemeden** (fire-and-forget) diske yazar — bir
/// getter `await` edemez ve arayüzün bu yazmayı beklemesi de istenmez.
/// Bu yüzden test bittiğinde arkada hâlâ tamamlanmakta olan bir yazma
/// olabilir; klasör silinirken dosya yeniden oluşursa `delete(recursive: true)`
/// "Directory not empty" (errno 39) hatası verir.
///
/// Çözüm: kısa aralıklarla birkaç kez denenir. Bu, üretim davranışını
/// değiştirmeden testleri kararlı hâle getirir; bir hatayı gizlemez, çünkü
/// klasörün silinmesi testin doğruladığı davranışın parçası değildir.
Future<void> deleteTempDirectory(Directory directory) async {
  for (var attempt = 0; attempt < 8; attempt++) {
    if (!await directory.exists()) {
      return;
    }
    try {
      await directory.delete(recursive: true);
      return;
    } on FileSystemException {
      // Arkada bekleyen yazma bitsin, sonra tekrar denenir.
      await Future<void>.delayed(const Duration(milliseconds: 25));
    }
  }
  // Son deneme de başarısızsa klasör işletim sistemine bırakılır:
  // sistem geçici klasörü zaten temizlenir ve test sonucu etkilenmemelidir.
}
