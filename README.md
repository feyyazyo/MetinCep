# MetinCep

**Fotoğraf ve PDF'lerden hızlıca metin çıkarın.**

MetinCep; kamerayla çekilen fotoğraflardaki, galeriden seçilen görsellerdeki ve PDF dosyalarındaki yazıları **cihaz üzerinde** metne dönüştüren sade bir Android uygulamasıdır. Metin tanıma her zaman telefonda yapılır: kullanıcı hesabı, sunucu ve bulut servisi yoktur, uygulama çevrimdışı çalışır.

Uygulamanın iki kullanım seviyesi vardır: **MetinCep Free** (günlük kullanım limitleriyle) ve **MetinCep Pro** (limitsiz ve reklamsız). Bu sürümde durum şöyledir:

- **Free sürüm tamamen çalışır.** Tüm özellikler kullanılabilir, yalnızca günlük limitler geçerlidir.
- **Pro satın alınamaz.** Google Play satın alma entegrasyonu sonraki aşamadadır; uygulama hiçbir ödeme almaz, "Pro'ya Geç" düğmesi "Yakında" olarak pasiftir.
- **Reklam gösterilmez.** Reklam altyapısı hazırdır ama reklam SDK'sı eklenmemiştir.
- Pro özelliklerini geliştirme sırasında denemek için yalnızca debug derlemede çalışan bir **Mock Pro** anahtarı vardır; release APK'da bulunmaz.

Ayrıntılar: [MetinCep Free ve Pro](#9a-metincep-free-ve-pro).

| Özellik | Durum (V1) |
|---|---|
| Kameradan fotoğraf → OCR | ✅ |
| Galeriden bir veya birden fazla fotoğraf → OCR | ✅ |
| PDF → metin (metin katmanı varsa OCR'suz, taranmışsa OCR ile) | ✅ |
| Çok sayfalı PDF, ilerleme yüzdesi, sayfa sayacı, iptal | ✅ |
| Sonucu düzenleme, kopyalama, paylaşma | ✅ |
| Uygulama içine kaydetme (başlıkla), TXT dosyası olarak kaydetme | ✅ |
| Geçmiş: listeleme, Türkçe uyumlu arama, tekrar açma, silme | ✅ |
| Ayarlar: tema (Sistem / Açık / Koyu), gizlilik, hakkında | ✅ |
| Ek Android izni | ❌ Gerekmez |
| MetinCep Free / Pro erişim altyapısı (limitler, Pro ekranı, Mock Pro) | ✅ |
| Google Play ile Pro satın alma | ⏳ Sonraki aşama — **şu anda ödeme alınmaz** |
| Reklam (AdMob) | ⏳ Sonraki aşama — **şu anda reklam SDK'sı yok** |

---

## İçindekiler

1. [En kolay yol: APK'yı GitHub'da otomatik oluşturma](#1-en-kolay-yol-apkyı-githubda-otomatik-oluşturma)
2. [Gereksinimler](#2-gereksinimler)
3. [Yerel kurulum ve çalıştırma](#3-yerel-kurulum-ve-çalıştırma)
4. [APK oluşturma](#4-apk-oluşturma)
5. [Kullanılan paketler](#5-kullanılan-paketler)
6. [OCR sistemi](#6-ocr-sistemi)
7. [PDF sistemi](#7-pdf-sistemi)
8. [Veri saklama ve gizlilik](#8-veri-saklama-ve-gizlilik)
9. [İzinler](#9-izinler)
9A. [MetinCep Free ve Pro](#9a-metincep-free-ve-pro)
10. [Proje klasör yapısı](#10-proje-klasör-yapısı)
11. [Testler](#11-testler)
12. [Bilinen sınırlamalar](#12-bilinen-sınırlamalar)
13. [Sorun giderme](#13-sorun-giderme)
14. [V2 fikirleri](#14-v2-fikirleri)

---

## 1. En kolay yol: APK'yı GitHub'da otomatik oluşturma

Bilgisayarınıza Flutter kurmadan APK almak için projede hazır bir GitHub Actions iş akışı vardır (`.github/workflows/build-apk.yml`).

1. [github.com](https://github.com) üzerinde ücretsiz hesap açın ve **yeni bir depo (repository)** oluşturun. Özel (private) olabilir.
2. Bu klasörün **tüm içeriğini** depoya yükleyin. `.github` klasörünün de yüklendiğinden emin olun (gizli klasördür; bazı bilgisayarlarda görünmez).
   - Komut satırıyla:
     ```bash
     cd metincep
     git init
     git add .
     git commit -m "MetinCep V1"
     git branch -M main
     git remote add origin https://github.com/KULLANICI_ADINIZ/metincep.git
     git push -u origin main
     ```
   - Komut satırı kullanmıyorsanız **GitHub Desktop** uygulaması en kolay yoldur.
3. Depoda **Actions** sekmesine girin. "MetinCep APK Oluştur" iş akışı kendiliğinden başlar (başlamazsa **Run workflow** düğmesine basın).
4. Yaklaşık 10–20 dakika sonra iş akışı biter. İş akışına tıklayın:
   - Sayfanın üstündeki **özet** bölümünde `flutter analyze`, `flutter test`, `flutter build apk --release` ve release güvenlik doğrulamasının **PASS/FAIL tablosu** vardır. Önce buraya bakın.
   - Sayfanın altındaki **Artifacts** bölümünden **MetinCep-APK** dosyasını indirin.
5. İndirilen ZIP içindeki `app-release.apk` dosyasını telefona aktarın ve açın. Android "bilinmeyen kaynaklardan yükleme" izni isteyebilir; bu izin yalnızca dosyayı açtığınız uygulama (ör. Dosyalar) için verilir.

> **Yeşil / kırmızı ne anlama gelir?** Kalite kontrol adımları (analiz, test, güvenlik doğrulaması) APK üretimini engellemez: hepsi çalışır, APK yine yüklenir. Ancak adımlardan biri bile başarısızsa iş akışı sonunda **kırmızı** işaretlenir. Yani kırmızı bir işte de indirilebilir bir APK bulabilirsiniz, ama o APK'da bilinen bir sorun vardır: özet tablosundaki FAIL satırına ve ilgili adımın günlüğüne bakın.
>
> Release APK hiç üretilemezse iş akışı yedek olarak `app-debug.apk` üretir. Debug APK de telefona kurulabilir, yalnızca biraz daha büyük ve yavaştır.

## 2. Gereksinimler

| Araç | Sürüm |
|---|---|
| Flutter | **3.35.7** (stable) — önerilen ve paket aralıklarının doğrulandığı sürüm |
| Dart | Flutter 3.35.7 ile gelen sürüm (3.9.x) |
| Java (JDK) | 17 |
| Android SDK | Android Studio ile gelen güncel SDK, platform-tools, CMake |
| Android cihaz | Android 7.0 (API 24) ve üzeri; hedef: Android 10+ |
| İnternet | İlk derlemede gerekir (paketler ve PDFium kütüphanesi indirilir) |

> Farklı bir Flutter sürümü kullanırsanız `flutter pub get` farklı paket sürümleri seçebilir. Sorun yaşarsanız 3.35.7'ye geçin: `flutter downgrade 3.35.7` veya [fvm](https://fvm.app) ile `fvm use 3.35.7`.

## 3. Yerel kurulum ve çalıştırma

Bu depo, Android proje iskeletinin yalnızca MetinCep'e özel dosyalarını içerir (manifest, ikon, R8 kuralları). Geri kalan standart Android dosyaları kurulum betiğiyle üretilir.

**macOS / Linux:**
```bash
cd metincep
bash tool/setup_android.sh
flutter pub get
flutter run
```

**Windows (PowerShell):**
```powershell
cd metincep
powershell -ExecutionPolicy Bypass -File tool\setup_android.ps1
flutter pub get
flutter run
```

Kurulum betiği şunları yapar:
- `flutter create .` ile eksik Android dosyalarını üretir (var olan dosyalara dokunmaz),
- Uygulama kimliğini `com.metincep.app`, minimum Android sürümünü API 24 yapar,
- Release derlemesine `android/app/proguard-rules.pro` dosyasını ekler,
- `flutter create`'in ürettiği, bu projeyle uyumsuz varsayılan `test/widget_test.dart` dosyasını siler.

Betik birden fazla kez çalıştırılabilir.

## 4. APK oluşturma

```bash
# Tek dosya, tüm işlemci türlerini içerir (en kolay kurulum)
flutter build apk --release

# Daha küçük dosyalar: işlemci türüne göre ayrı APK'lar
flutter build apk --release --split-per-abi

# Test için
flutter build apk --debug
```

Çıktılar:
```text
build/app/outputs/flutter-apk/app-release.apk
build/app/outputs/flutter-apk/app-arm64-v8a-release.apk   (--split-per-abi ile; güncel telefonların çoğu)
build/app/outputs/flutter-apk/app-debug.apk
```

> **İmzalama:** V1 release APK'sı Flutter şablonundaki gibi *debug anahtarıyla* imzalanır; telefona kurmak için yeterlidir. Google Play'e yüklemeden önce kendi imza anahtarınızı oluşturmanız gerekir ([Flutter belgesi](https://docs.flutter.dev/deployment/android#sign-the-app)).

## 5. Kullanılan paketler

Her paket bir ihtiyacı karşıladığı için eklendi; durum yönetimi, veritabanı veya tarih biçimlendirme için ek paket kullanılmadı.

| Paket | Sürüm aralığı | Neden |
|---|---|---|
| `google_mlkit_text_recognition` | `>=0.13.0 <1.0.0` | Cihaz üzerinde OCR (Latin alfabesi modeli APK'ya gömülü) |
| `pdfrx` | `>=1.3.0 <2.0.0` | PDF metin katmanı okuma ve sayfaları görüntüye çevirme (PDFium) |
| `image_picker` | `^1.1.2` | Sistem kamerası ve fotoğraf seçici (izin gerektirmez) |
| `file_picker` | `>=8.1.0 <11.0.0` | PDF seçme ve TXT dosyasını kullanıcının seçtiği konuma kaydetme |
| `share_plus` | `>=11.0.0 <14.0.0` | Android paylaşım menüsü |
| `path_provider` | `^2.1.4` | Uygulama klasörleri (kayıtlar, geçici dosyalar) |
| `flutter_localizations` | SDK | Türkçe arayüz metinleri (iletişim kutuları, lisans sayfası vb.) |

API uyumluluğu, bu aralıklardaki paketlerin kaynak koduyla karşılaştırılarak kontrol edildi (ör. `PdfPage.render`, `PdfImage.format`, `PdfPasswordException`, `SharePlus.instance.share`, `FilePicker.platform.saveFile`).

> `file_picker` 11 ve `pdfrx` 2 sürümlerinde API değiştiği için üst sınırlar bilinçli olarak konuldu. Yükseltme V2 işidir.

## 6. OCR sistemi

- **Motor:** Google ML Kit Text Recognition v2, **Latin alfabesi** modeli. Model APK'nın içindedir; ilk açılışta indirme gerektirmez ve çevrimdışı çalışır.
- **Diller:** Latin modeli Türkçe (ç, ğ, ı, İ, ö, ş, ü), İngilizce ve diğer Latin alfabeli dilleri *aynı anda* tanır. Bu yüzden ayrı bir "OCR dili" seçimi gerekmez; Ayarlar'da bu bilgi olarak gösterilir.
- **Satır ve paragraf yapısı:** ML Kit blokları ve satırları `TextLayoutFormatter` ile birleştirilir. Aynı blok içindeki satırlar alt alta yazılır; bloklar arası dikey boşluk satır yüksekliğinin 0,8 katından büyükse araya boş satır (paragraf) konur. Noktalama, sayılar, tarihler ve Türkçe karakterler değiştirilmez.
- **Görüntü hazırlığı:** Fotoğraflar OCR öncesi uzun kenarı en fazla 2560 piksele küçültülür (RAM tasarrufu, OCR için yeterli çözünürlük). EXIF yönü dikkate alınır.
- **Birden fazla fotoğraf:** Sırayla işlenir ve sonuç `Görsel 1`, `Görsel 2`… başlıklarıyla birleştirilir. Bir görsel okunamazsa diğerleri yine işlenir.
- **Hata:** Hiç metin bulunamazsa: *"Metin okunamadı. Fotoğrafı daha net çekmeyi deneyin."*
- **Düşük RAM'li telefonlar:** Android kamera açıkken uygulamayı kapatırsa, uygulama tekrar açıldığında çekilen fotoğraf kurtarılıp işlenir (`retrieveLostData`).

**Daha iyi OCR için ipuçları:** Belgeyi düz bir zemine koyun, gölge düşürmeyin, telefonu belgeye paralel tutun, yazı ekranın büyük kısmını kaplasın.

## 7. PDF sistemi

Her sayfa **tek tek** işlenir; bütün sayfalar aynı anda RAM'e alınmaz.

1. Dosyanın ilk baytlarında `%PDF` imzası aranır. Yoksa: *"PDF açılamadı. Dosyanın geçerli bir PDF olduğundan emin olun."*
2. Sayfanın **metin katmanı** okunur (hızlı ve birebir doğru; OCR kullanılmaz).
3. Metin katmanında 20'den az görünür karakter varsa sayfa taranmış kabul edilir: sayfa yaklaşık 200 DPI'da (uzun kenar 1400–2400 piksel arası) görüntüye çevrilir, geçici PNG dosyasına yazılır, OCR'dan geçirilir ve geçici dosya hemen silinir. İki sonuçtan hangisi daha fazla metin içeriyorsa o kullanılır.
4. Her sayfadan sonra ilerleme (`3 / 12 sayfa`, yüzde) güncellenir ve **İptal** kontrol edilir.
5. Çok sayfalı sonuç şu biçimdedir:
   ```text
   Sayfa 1
   ...

   Sayfa 2
   ...
   ```
   Boş sayfalar `(Bu bölümde metin bulunamadı)` olarak işaretlenir.

Şifreli PDF'ler için ayrı bir mesaj gösterilir (V1'de parola sorulmaz).

## 8. Veri saklama ve gizlilik

- Kayıtlar uygulamanın özel klasöründe tek bir JSON dosyasında tutulur (`metincep_documents.json`). Her kayıt: `id`, `title`, `text`, `createdAt`, `updatedAt`, `source`.
- Yazma işlemleri **atomiktir** (önce `.tmp` dosyasına yazılır, sonra yeniden adlandırılır) ve sıraya alınır; uygulama yazma sırasında kapansa bile dosya bozulmaz. Dosya yine de bozuksa uygulama çökmez, dosya `.bozuk-<zaman>` adıyla yedeklenir.
- Fotoğraflar ve PDF'ler kalıcı olarak saklanmaz. Seçicilerin önbelleğe aldığı kopyalar işlem ekranı kapanınca silinir; kullanıcının galerideki/indirilenlerdeki orijinal dosyalarına dokunulmaz.
- Ayarlar ayrı bir küçük dosyada tutulur (`metincep_settings.json`).
- Hesap, reklam SDK'sı, analiz servisi, Firebase veya bulut senkronizasyonu **yoktur**.
- **Açıklık notu:** Google ML Kit, Google'ın veri açıklamasına göre bileşenin çalışmasıyla ilgili teknik ölçümler (performans, hata kodları vb.) gönderebilir. Görüntüler ve tanınan metinler gönderilmez. Bu durum uygulama içindeki Gizlilik ekranında da belirtilmiştir.

## 9. İzinler

`AndroidManifest.xml` içinde **hiçbir ek izin tanımlı değildir**:

| İşlem | Nasıl yapılıyor | İzin |
|---|---|---|
| Fotoğraf çekme | Sistem kamera uygulaması (`ACTION_IMAGE_CAPTURE`) | Gerekmez |
| Galeriden seçme | Android fotoğraf seçici | Gerekmez |
| PDF seçme | Sistem dosya seçicisi | Gerekmez |
| TXT kaydetme | Sistem "Farklı kaydet" ekranı | Gerekmez |

> ⚠️ Manifest'e `android.permission.CAMERA` **eklemeyin**. Eklenirse Android, sistem kamerasını açmadan önce çalışma zamanı izni ister ve izin verilmezse kamera açılmaz.

## 9A. MetinCep Free ve Pro

> **Durum:** Pro satın alma altyapısı hazırlanmıştır. **Google Play satın alma entegrasyonu sonraki aşamadadır.** Bu sürümde hiçbir ödeme alınmaz; Pro ekranındaki düğme "Yakında" olarak pasiftir. Reklam altyapısı da hazırdır ancak **reklam SDK'sı eklenmemiştir**, hiçbir reklam gösterilmez.

### Planlar

| Özellik | MetinCep Free | MetinCep Pro |
|---|---|---|
| Kamera / galeri → OCR | Günde **10** işlem | Sınırsız |
| PDF → metin (taranmış PDF dahil) | Günde **3** PDF | Sınırsız |
| PDF sayfa sınırı | PDF başına **10** sayfa (fazlası için "İlk 10 sayfayı işle" seçeneği) | Sınırsız |
| Toplu fotoğraf OCR | Tek seferde **3** fotoğraf (fazlası için "İlk 3 fotoğrafı işle") | Sınırsız |
| PDF dosya boyutu | En fazla **25 MB** | Sınırsız |
| Düzenleme, kopyalama, paylaşma, TXT kaydetme | ✅ | ✅ |
| Geçmiş, arama, silme, tema, gizlilik | ✅ | ✅ |
| Çevrimdışı çalışma | ✅ | ✅ |
| Reklam | Altyapı hazır, bu sürümde yok | Hiçbir zaman |

Sayım kuralları:
- Bir kamera çekimi veya bir galeri seçimi **1 OCR işlemi** sayılır (toplu seçim de 1).
- Bir PDF **1 PDF işlemi** sayılır; taranmış sayfalar OCR'dan geçse bile OCR hakkından düşmez.
- Hak yalnızca işlem **başarıyla bittiğinde** harcanır; hata, iptal ve "metin bulunamadı" sayılmaz.
- Pro kullanımı Free sayacına yazılmaz.
- Haklar yerel saatle her gün yenilenir.

### Sınırları değiştirmek

Tüm sayılar tek dosyadadır: [`lib/core/constants/plan_limits.dart`](lib/core/constants/plan_limits.dart) → `FreeLimits`. Ekranlardaki metinler ("günde 10", "İlk 10 sayfayı işle") bu değerlerden üretilir; başka dosyada sayı yazılmaz.

### Mimari

```text
Ekranlar ──► FeatureAccessService ──┬──► EntitlementService ──► PurchaseService ──► (Google Play Billing — sonraki aşama)
  │          canUseOcr()            │     isPro, Mock Pro        UnavailablePurchaseService (şimdi)
  │          canProcessPdf()        │
  │          canUseBatchOcr(n)      └──► UsageTracker (metincep_usage.json)
  │          canUseLargePdf(n)
  │          canOpenPdfFile(bayt)
  │          shouldShowAds()
  │
  └──► AdService ──► AdProvider ──► NoOpAdProvider (şimdi) / AdMobAdProvider (sonraki aşama)
```

| Dosya | Görev |
|---|---|
| `core/constants/plan_limits.dart` | `PlanLimits`, `FreeLimits`, `ProLimits` |
| `core/constants/purchase_products.dart` | `metincep_pro_monthly`, `metincep_pro_yearly`, `metincep_pro_lifetime` (satın alınabilir olarak gösterilmez) |
| `core/constants/ad_config.dart` | Tam ekran reklam sıklık sınırları |
| `models/subscription_model.dart` | `PlanTier`, `EntitlementSource`, `Entitlement` |
| `models/usage_model.dart` | `DailyUsage` |
| `services/entitlement_service.dart` | Free / Pro durumunun tek kaynağı; Mock Pro |
| `services/purchase_service.dart` | Satın alma arayüzü + `UnavailablePurchaseService` |
| `services/usage_tracker.dart` | Günlük sayaçlar, gün değişimi, saat geri alma koruması |
| `services/feature_access_service.dart` | Tüm erişim kararları |
| `services/ad_service.dart` | `AdPlacement`, `AdProvider`, `NoOpAdProvider`, `AdService` |
| `screens/pro/pro_screen.dart` | "MetinCep Pro" ekranı |
| `screens/pro/limit_dialog.dart` | "Günlük OCR limitin doldu." pencereleri |
| `widgets/ad_banner_slot.dart` | Banner yeri (reklam yoksa yer kaplamaz) |

Tasarım kuralları:
- **OCR / PDF servisleri Free / Pro'yu bilmez.** Sınırlar yalnızca `ExtractionFlow` içinde, kamera veya seçici açılmadan önce uygulanır. PDF sayfa sınırı `PdfExtractionRequest.maxPages` ile nötr bir parametre olarak geçer; aşılırsa işlem ekranı kullanıcıya sorar.
- Ekranlarda `if (isPro)` yoktur; `FeatureAccessService` soruları kullanılır.
- Pro durumu ve limitler **internet gerektirmez**. Satın alma kontrolü açılışı bekletmez.

### Limit dolunca

Uygulama çökmez; pencere açılır:

```text
Günlük OCR limitin doldu.
Pro ile sınırsız OCR kullanabilirsin. Free hakların yarın yenilenir.
          [İptal]   [Pro'yu İncele]
```

Kullanıcı Pro ekranından döndüğünde erişim yeniden kontrol edilir. PDF sayfa ve toplu fotoğraf sınırlarında ayrıca "İlk N sayfayı / fotoğrafı işle" seçeneği vardır; Free kullanıcı işlemi yarım bırakmak zorunda kalmaz.

Kalan haklar yalnızca Pro ekranında ("Bugün kalan OCR: 7 / 10") ve Ayarlar → Pro Durumu satırında görünür. Ana ekranda sayaç yoktur. Free kullanıcıya ana ekranda, eylem kartlarının ve son belgelerin **altında** küçük bir Pro kartı gösterilir.

### Günlük limit saklama ve güvenlik

`metincep_usage.json` (uygulamanın özel klasörü):

```json
{ "version": 1, "date": "2026-09-11", "ocrCount": 3, "pdfCount": 1, "lastSeenAt": 1789113600000 }
```

- Yeni gün başlayınca sayaçlar otomatik sıfırlanır.
- **Saat geri alma koruması:** Görülen en geç zaman saklanır. Saat bundan 10 dakikadan fazla geri alınırsa sayaçlar sıfırlanmaz. "Saati yarına al → hakları sıfırla → geri al" döngüsü ek hak kazandırmaz.
- Bozuk veya elle değiştirilmiş dosya uygulamayı çökertmez; geçersiz alanlar sıfır sayılır.
- ⚠️ **Bu bir caydırıcıdır, kesin güvenlik değildir.** Uygulama verisini temizlemek veya root erişimi sayaçları sıfırlayabilir. Gerçek koruma için limitlerin sunucu tarafında doğrulanması gerekir (ör. Play Integrity API + hesap bazlı sayaç). MetinCep bu aşamada bilinçli olarak sunucusuz ve çevrimdışı çalışır.

### Mock Pro (yalnızca geliştirme)

Debug derlemede (`flutter run`): **Ayarlar → Pro Durumu → en alttaki "Geliştirici araçları"** bölümünden:
- **Mock Pro** anahtarı Pro özelliklerini ödeme olmadan açar.
- **Free sayaçlarını limite doldur** günlük hakları anında bitirir; limit pencerelerini 10 gerçek çekim yapmadan test edersiniz.
- **Bugünkü Free sayaçlarını sıfırla** hakları geri verir.

Release güvenliği:
- Mock Pro `kDebugMode && allowMockPro` koşuluna bağlıdır. `kDebugMode` bir **derleme zamanı sabitidir**; release ve profile derlemelerde `false` olur ve geliştirici bölümü uygulamaya hiç girmez.
- Sayaç sıfırlama da `kDebugMode` ile korunur.
- Mock Pro **kalıcı değildir** (yalnızca bellekte). Uygulama yeniden başlatılınca Free'ye döner. Uygulama silinip kurulunca Pro korunuyormuş gibi davranılmaz.
- Release APK'da kullanıcının kendini Pro yapabileceği hiçbir yol yoktur.

Release güvenliğini doğrulamak için üç yol vardır:

1. **Otomatik betik** (her CI derlemesinde de çalışır):
   ```bash
   bash tool/verify_release_guards.sh build/app/outputs/flutter-apk/app-release.apk
   ```
   Kaynak koddaki `kDebugMode` korumalarının yerinde olduğunu doğrular ve APK içinde geliştirici arayüzü metni kalıp kalmadığını tarar. Koruma kaldırılırsa betik hata verir ve CI kırmızı olur.
2. **Otomatik test:** `feature_access_service_test.dart` içindeki "release koşulunda kullanıcı kendini Pro yapamaz" testi, izin verilmediğinde `setMockPro`'nun etkisiz olduğunu doğrular.
3. **Cihazda gözle kontrol (zorunlu):** `docs/TEST_PLANI.md` → R1–R6.

### Reklam kuralları (AdMob bağlandığında da geçerli)

- Reklam yerleşimleri yalnızca `AdPlacement` içinde tanımlıdır: ana ekran altı banner, geçmiş ekranı altı banner, **sonuç ekranı kapatıldıktan sonra** tam ekran geçiş.
- OCR işlemi, PDF işleme, kamera açılışı ve metin düzenleme için yerleşim **yoktur**; reklam kodu oralardan çağrılamaz.
- Tam ekran reklam en erken 3 tamamlanmış işlemde bir ve iki reklam arasında en az 5 dakika (`AdConfig`).
- Pro kullanıcıda `isAdsEnabled() == false`: banner ve tam ekran reklam kapalıdır.

### Sonraki aşama: Google Play Billing

1. Play Console'da `metincep_pro_monthly`, `metincep_pro_yearly` (abonelik) ve `metincep_pro_lifetime` (tek seferlik) ürünlerini oluşturun.
2. `in_app_purchase` paketini ekleyip `PurchaseService` arayüzünü uygulayan `GooglePlayPurchaseService` yazın (satın alma akışı, onaylama/acknowledge, geri yükleme, iptal/iade takibi).
3. `main.dart` içinde `UnavailablePurchaseService` yerine yeni sağlayıcıyı verin. `EntitlementService`, `FeatureAccessService` ve ekranlar değişmez.
4. Pro ekranına plan seçimi (aylık / yıllık / ömür boyu) ekleyin.
5. Satın alma doğrulaması için sunucu tarafı doğrulama (Google Play Developer API) önerilir.

### Sonraki aşama: AdMob

1. `google_mobile_ads` paketini ekleyip `AdProvider` arayüzünü uygulayan `AdMobAdProvider` yazın.
2. `main.dart` içinde `NoOpAdProvider` yerine verin.
3. Gizlilik ekranını ve Play Console veri güvenliği formunu reklam SDK'sına göre güncelleyin. AB kullanıcıları için UMP onay akışını ekleyin. Manifest'e AdMob uygulama kimliğini ekleyin.

## 10. Proje klasör yapısı

```text
metincep/
├── .github/workflows/build-apk.yml   # Bulutta APK derleme
├── android/app/
│   ├── proguard-rules.pro            # R8 kuralları (ML Kit)
│   └── src/main/
│       ├── AndroidManifest.xml       # İzinsiz manifest
│       └── res/                      # Uyarlanabilir uygulama ikonu
├── docs/TEST_PLANI.md                # Gerçek cihaz test listesi
├── lib/
│   ├── main.dart                     # Başlatma, hata yakalama, servis kurulumu
│   ├── app.dart                      # MaterialApp, tema, Türkçe yerelleştirme
│   ├── core/
│   │   ├── app_scope.dart            # Paketsiz bağımlılık erişimi
│   │   ├── constants/                # Boyut, kalite, sınır sabitleri
│   │   ├── errors/                   # AppException ve tüm hata mesajları
│   │   ├── theme/                    # Tek vurgu renkli Material 3 tema
│   │   └── utils/                    # Metin düzenleme, arama, tarih, dosya adı, iptal
│   ├── models/                       # DocumentModel, çıkarma istek/ilerleme/sonuç, plan, kullanım
│   ├── repositories/                 # DocumentRepository (yerel JSON)
│   ├── services/
│   │   ├── ocr_service.dart          # ML Kit
│   │   ├── pdf_service.dart          # pdfrx: metin katmanı + sayfa OCR
│   │   ├── extraction_service.dart   # Tüm çıkarma işlerinin tek giriş noktası
│   │   ├── source_picker_service.dart# Kamera, galeri, PDF seçici, geçici dosya temizliği
│   │   ├── share_service.dart        # Kopyala, paylaş, TXT kaydet
│   │   ├── settings_controller.dart  # Tema ayarı
│   │   ├── entitlement_service.dart  # Free / Pro durumu, Mock Pro
│   │   ├── purchase_service.dart     # Satın alma arayüzü (Billing sonraki aşama)
│   │   ├── usage_tracker.dart        # Günlük Free sayaçları
│   │   ├── feature_access_service.dart # Tüm erişim kararları
│   │   └── ad_service.dart           # Reklam politikası (SDK yok)
│   ├── screens/
│   │   ├── home/                     # Alt menü + ana ekran
│   │   ├── processing/               # İlerleme, iptal, hata, akış başlatıcı
│   │   ├── result/                   # Düzenleme ve eylemler
│   │   ├── history/                  # Geçmiş ve arama
│   │   ├── pro/                      # MetinCep Pro ekranı, limit pencereleri
│   │   └── settings/                 # Ayarlar (Pro Durumu) ve gizlilik
│   └── widgets/                      # Kart, liste satırı, yükleme, hata, boş durum, banner yeri
├── test/
│   ├── helpers/                      # Ortak test servis kurulumu
│   ├── monetization/                 # Free / Pro, sayaç, reklam birim testleri
│   └── widget/                       # Arayüz testleri
├── tool/setup_android.sh / .ps1      # Android iskeletini hazırlama
└── pubspec.yaml
```

**Mimari kararlar:**
- Ekranlar servisleri `AppScope` üzerinden alır; ek durum yönetimi paketi yok.
- OCR motoruna bağlı olmayan saf mantık (`TextLayoutFormatter`, `SearchUtils`, `PdfRenderSizing`, `TextStats`) ayrı dosyalardadır ve cihaz olmadan test edilir.
- Yeni kaynak türleri `ExtractionRequest` alt sınıfı olarak, sonuç üzerinde çalışan yeni özellikler (özet, fatura bilgisi) `ExtractionService`'ten sonra çalışan servisler olarak eklenebilir.

## 11. Testler ve kalite kontrol

```bash
flutter clean
flutter pub get
flutter analyze
flutter test
flutter build apk --release
bash tool/verify_release_guards.sh build/app/outputs/flutter-apk/app-release.apk
```

Aynı adımlar GitHub Actions'ta her derlemede otomatik çalışır ve iş akışı özetinde **PASS/FAIL tablosu** olarak raporlanır. Bir adım başarısız olursa APK yine yüklenir, ancak iş akışı kırmızı işaretlenir; sessizce geçmez.

| Dosya | Kapsam |
|---|---|
| `test/text_layout_formatter_test.dart` | Satır/paragraf koruma, Türkçe karakterler, sayılar (`12.500 TL`, `%20`, `11/09/2026`, `3,25 m²`), `Sayfa N` birleştirme |
| `test/utils_test.dart` | Türkçe tarih, dosya adı temizleme, PDF çizim boyutu, Türkçe uyumlu arama, karakter/kelime sayacı |
| `test/document_model_test.dart` | JSON gidiş-dönüş, bozuk kayıt, önizleme |
| `test/document_repository_test.dart` | Kaydet → yeniden aç (kalıcılık), güncelleme, silme, toplu silme, bozuk dosya |
| `test/widget/app_widget_test.dart` | Ana ekran, alt menü, sonuç ekranı, Temizle/Geri al, düzenleme sonrası kaydet, kaydetmeden çıkış onayı |
| `test/monetization/usage_tracker_test.dart` | Kalıcılık, yeni günde sıfırlama, saat geri alma hilesi, küçük saat düzeltmesi, bozuk / geçersiz dosya |
| `test/monetization/feature_access_service_test.dart` | Free OCR/PDF limitleri, sayfa/toplu/boyut sınırları, Pro'da tüm özellikler ve reklamsızlık, Pro kullanımının sayılmaması, Mock Pro (debug) ve release koşulu, satın alma hatası |
| `test/monetization/ad_service_test.dart` | NoOp sağlayıcı, Pro'da reklam kapalı, yerleşim kuralları, tam ekran sıklık sınırı |
| `test/extraction/extraction_guards_test.dart` | Fotoğrafsız istek, baştan iptal (OCR hiç çalışmaz), geçersiz / olmayan / boş PDF, iptal jetonu — hepsi hata yolları olduğu için kota harcanmaz |
| `test/widget/pro_widget_test.dart` | Ana ekran Pro kartı, Ayarlar Free/Pro, limit penceresi (İptal / Pro'yu İncele), Pro ekranı "Yakında", Mock Pro anahtarı |

Not: Kotanın yalnızca başarılı işlemde harcanması kuralı iki katmanda doğrulanır — hata yolları yukarıdaki `extraction_guards` testleriyle, sayaç davranışı `feature_access_service` testleriyle. Bu ikisinin birleştiği yer (`ProcessingScreen`) gerçek OCR gerektirdiği için cihazda test edilir (TEST_PLANI P4).

Kamera, gerçek OCR, PDF çizimi, paylaşım ve dosya kaydetme platform bileşeni gerektirdiği için **gerçek cihazda** test edilmelidir: [`docs/TEST_PLANI.md`](docs/TEST_PLANI.md).

## 12. Bilinen sınırlamalar

- **Pro satın alma yok:** Google Play Billing sonraki aşamadadır; bu sürümde herkes Free'dir (debug derlemede Mock Pro hariç).
- **Free sayaçları cihazdadır:** Uygulama verisini temizlemek sayaçları sıfırlar; gerçek koruma sunucu gerektirir (bkz. 9A).
- **Doğrulama durumu:** Kod, geliştirme ortamında Flutter SDK indirilemediği için yazıldığı yerde derlenemedi. Paket API'leri kaynak kodlarıyla karşılaştırıldı ve statik kontroller yapıldı; ilk `flutter analyze`, `flutter test` ve cihaz testleri sizin ortamınızda veya GitHub Actions'ta yapılacaktır. GitHub Actions bu üç komutu ve güvenlik doğrulamasını her derlemede çalıştırır; sonuçları iş akışı özetindeki PASS/FAIL tablosundan kontrol edin. Adımlardan biri başarısız olsa bile APK üretilip yüklenir, ancak iş akışı kırmızı işaretlenir.
- **El yazısı** güvenilir biçimde okunmaz; ML Kit basılı metin için tasarlanmıştır.
- **Tablolar** satır satır metin olarak çıkar; sütun hizası korunmaz.
- **Kırpma, perspektif düzeltme, kontrast artırma** V1'de yok (OCR kararlılığı öncelikli tutuldu). Sistem kamerası/galeri düzenleyicisiyle önceden kırpılabilir.
- **Şifreli PDF'ler** açılmaz.
- **Latin dışı alfabeler** (Arapça, Kiril, Çince vb.) okunmaz.
- **Çok uzun metinler** (yüz binlerce karakter) düzenleyicide yavaşlayabilir; 100.000 karakteri aşan metin paylaşılırken otomatik olarak TXT dosyası olarak gönderilir.
- **APK boyutu:** ML Kit modeli ve PDFium tüm işlemci türleri için gömülü olduğundan tek APK büyüktür; `--split-per-abi` ile küçülür.
- 7.0–9 sürümlü Android cihazlar destekleniyor ancak test önceliği Android 10+.

## 13. Sorun giderme

| Belirti | Çözüm |
|---|---|
| `flutter pub get` sürüm çözümleme hatası | Flutter 3.35.7 kullanın |
| Derlemede PDFium indirme hatası | İnternet bağlantısını kontrol edin; pdfrx derleme sırasında PDFium'u GitHub'dan indirir |
| `Missing classes detected while running R8` | `tool/setup_android.sh` betiğini çalıştırdığınızdan ve `proguard-rules.pro`'nun `build.gradle.kts` içinde eklendiğinden emin olun |
| NDK sürüm uyarısı | Genellikle yalnızca uyarıdır; hata verirse `android/app/build.gradle.kts` içinde uyarıda önerilen `ndkVersion` değerini yazın |
| Kamera açılmıyor | Manifest'e CAMERA izni eklenmediğini kontrol edin; cihazda bir kamera uygulaması olmalı |
| `test/widget_test.dart` içinde `MyApp` hatası | Dosyayı silin (kurulum betiği bunu otomatik yapar) |

## 14. V2 fikirleri

Mimari aşağıdakilere hazırdır; hiçbiri V1'de yoktur.

- **Görüntü:** kırpma, perspektif düzeltme, siyah-beyaz/kontrast, toplu tarama modu
- **Yapay zekâ (isteğe bağlı, kullanıcı onayıyla):** özetleme, yazım düzeltme, çeviri, belge analizi
- **Dönüşüm:** Fotoğraf → PDF, Fotoğraf/PDF → Word, PDF → Excel
- **Akıllı belge:** IBAN, telefon, e-posta, tarih ve tutar algılama; fatura alanlarını çıkarma (`ExtractionResult.text` üzerinde çalışan ayrı bir servis olarak)
- **Tablo algılama:** ML Kit satır koordinatlarından (`OcrLine.top/bottom` ve sol/sağ konumlar) sütun kümeleme → `List<List<String>>` → Excel/CSV
- **Depolama:** kayıt sayısı büyürse JSON yerine SQLite; toplu silme, etiketler, sıralama
- **Kalite:** Play Store için imza anahtarı, çok dilli arayüz, Latin dışı alfabe modelleri
