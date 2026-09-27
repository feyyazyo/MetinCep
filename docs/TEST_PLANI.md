# MetinCep — Gerçek Cihaz Test Planı

Otomatik testler (`flutter test`) saf mantığı ve arayüz akışını doğrular. Kamera, ML Kit OCR, görüntü ön işleme, PDF okuma/yazma, paylaşım ve dosya kaydetme ise **gerçek Android cihazda** test edilmelidir.

Her satırı işaretleyin: ✅ geçti · ❌ kaldı (not düşün). Henüz cihazda denenmemiş satırlar **DEVICE TEST PENDING** sayılır; raporda "geçti" olarak yazılmaz.

Bölümler: **A–B** zorunlu akışlar · **1–13** temel senaryolar · **E** ek kontroller · **H** el yazısı · **N** karakter düzeltme · **T** tablo · **O** PDF çıktısı · **P** Free/Pro (debug) · **R** release güvenliği · **Z** bu turun düzeltmeleri.

**Cihaz:** ____________ **Android sürümü:** ____ **APK:** release / debug **Tarih:** ________

## Hazırlık

Test için şu dosyaları hazırlayın:

1. **Türkçe belge:** Bir kâğıda veya ekrana büyük puntoyla yazın ve fotoğrafını çekin:
   ```text
   Çalışma
   Şirket
   İstanbul
   Ürün
   Ödeme
   İşçilik
   ```
2. **Sayı belgesi:**
   ```text
   12.500 TL
   %20
   11/09/2026
   3,25 m²
   ```
3. **Metin PDF'i:** Word/Google Dokümanlar'da yazılıp PDF olarak kaydedilmiş 1 sayfalık belge.
4. **Taranmış PDF:** Telefonla taranmış veya fotoğraftan oluşturulmuş PDF (metin katmanı yok).
5. **Çok sayfalı PDF:** En az 10 sayfalık bir PDF (tercihen biri 50+ sayfa).
6. **Bozuk dosya:** Herhangi bir `.txt` dosyasının uzantısını `.pdf` yapın.
7. **El yazısı sayfası:** Düz çizgili kâğıda **tükenmez/keçeli kalemle**, büyük ve ayrık harflerle (bitişik el yazısı değil) yazın:
   ```text
   MEZAR TASI
   SELAM
   ISTANBUL 2026
   ```
   İkinci bir kopyayı bilerek **eğik** (yaklaşık 3°) tutarak fotoğraflayın — deskew testi için.
8. **Karakter düzeltme sayfası:** Büyük puntoyla yazın (bazı karakterlerin yanlış okunması beklenir):
   ```text
   MEZAR TASI
   SELAM DUNYA
   SERI NO: A5B2C
   12.500 TL
   %20
   11/09/2026
   0532 123 45 67
   ```
9. **Tablo belgesi:** Kenarlıklı, en az 3 kolon × 4 satırlık bir tablo. Bir market fişi veya basit bir fiyat listesi de olur:
   ```text
   Urun        Adet   Fiyat
   Kalem       2      25,00 TL
   Defter      1      2.500 TL
   Silgi       3      7,50 TL
   ```
10. **Geniş tablo:** 6 veya daha fazla kolonlu bir tablo (yatay PDF testi için).
11. **Uzun metin:** 5+ sayfa dolduracak kadar uzun düz metin (PDF sayfalama testi için; Hazırlık 5'in metnini kullanabilirsiniz).
12. **Fiş:** Gerçek bir market fişi (tutarlar sağa dayalı, 6+ satır). Sağa dayalı kolon eski sürümde yanlış algılanıyordu.
13. **Başlıklı tablo:** Tablonun üstünde tam genişlikte bir başlık satırı olan fiyat listesi (ör. "MERMER FİYAT LİSTESİ 2026").
14. **Kapı/duvar yazısı:** Bir kapıya, duvara veya panoya **elle** yazılmış yazı. Üç kopya çekin: (a) karşıdan, (b) yandan açıyla (perspektif), (c) gölgeli/düşük ışıkta.
15. **Eğik tablo:** Hazırlık 9'u telefonu kasıtlı olarak 2–5° eğik tutarak çekin.

## Zorunlu akışlar (V1 bunlar olmadan tamamlanmış sayılmaz)

| # | Akış | Beklenen | Sonuç |
|---|---|---|---|
| A | Uygulamayı aç → Fotoğraf Çek → çek → OCR → metni düzenle → Kopyala / Paylaş / Kaydet | Kamera izin sormadan açılır, metin çıkar, üç eylem çalışır | |
| B | Uygulamayı aç → PDF Aç → PDF seç → analiz → metni düzenle → Kopyala / Paylaş / Kaydet | İlerleme görünür, metin çıkar, üç eylem çalışır | |

## Senaryolar

| # | Test | Adımlar | Beklenen | Sonuç |
|---|---|---|---|---|
| 1 | Kamera → OCR | Fotoğraf Çek → belgeyi çek → onayla | "Metin okunuyor…" ekranı, ardından Çıkarılan Metin | |
| 2 | Galeri → OCR | Galeriden Seç → net bir belge fotoğrafı | Metin satır yapısı korunarak çıkar | |
| 3 | Türkçe karakterler | Hazırlık 1'i okut | `Ç Ş İ Ü Ö ı ş ğ` doğru; `İstanbul` büyük noktalı İ ile | |
| 4 | Sayılar | Hazırlık 2'yi okut | `12.500 TL`, `%20`, `11/09/2026`, `3,25 m²` korunur (m² üst simgesi `m2` okunabilir) | |
| 5 | PDF → metin | Hazırlık 3 | Çok hızlı çıkar, bilgi satırında "metin doğrudan okundu" | |
| 5b | Taranmış PDF | Hazırlık 4 | "Sayfa 1 görüntü olarak okunuyor…" görünür, metin OCR ile çıkar | |
| 6 | Çok sayfalı PDF | Hazırlık 5 | `3 / 12 sayfa` sayacı ve yüzde ilerler; sonuçta `Sayfa 1`, `Sayfa 2`… başlıkları | |
| 6b | İptal | Çok sayfalı PDF işlenirken **İptal** | Ana ekrana dönülür, uygulama donmaz veya çökmez | |
| 7 | Bozuk dosya | Hazırlık 6'yı seç | "PDF açılamadı. Dosyanın geçerli bir PDF olduğundan emin olun." + Geri / Tekrar dene | |
| 8 | Düzenleme | Sonuçta bir kelimeyi değiştir | Karakter/kelime sayacı güncellenir | |
| 9 | Kaydetme | Kaydet → "Fatura 12" yaz → Kaydet | "Belge kaydedildi."; düğme "Kaydedildi" olur | |
| 9b | Otomatik ad | Kaydet → adı boş bırak → Kaydet | Başlık `Belge - GG.AA.YYYY` | |
| 10 | Geçmişten açma | Geçmiş → kayda dokun | Düzenlenmiş metin açılır | |
| 11 | Kopyalama | Kopyala → başka uygulamaya yapıştır | Metnin tamamı yapışır | |
| 12 | Paylaşma | Paylaş → WhatsApp/Telegram/E-posta | Metin hedef uygulamada görünür | |
| 13 | Kalıcılık | Uygulamayı son uygulamalardan tamamen kapat → tekrar aç | Kayıtlar Geçmiş'te ve Son Belgeler'de duruyor | |

## Ek kontroller

| # | Test | Beklenen | Sonuç |
|---|---|---|---|
| E1 | TXT kaydet → İndirilenler'i seç | Dosya yöneticisinde `.txt` dosyası, Türkçe karakterler doğru | |
| E2 | Temizle → Geri al | Metin silinir, Geri al ile döner | |
| E3 | Kaydetmeden geri tuşu | "Kaydedilmemiş değişiklikler" onayı | |
| E4 | Kayıtlı belgeyi düzenle → Değişiklikleri kaydet | Aynı kayıt güncellenir (kopya oluşmaz) | |
| E5 | Geçmiş'te "sirket" ara | "Şirket" içeren belge bulunur | |
| E6 | Belge sil / Ayarlar → Tüm belgeleri sil | Onay sorulur, silinir, yeniden açınca geri gelmez | |
| E7 | Galeriden 3 fotoğraf seç | `Görsel 1..3` başlıkları, "3 fotoğraf · OCR ile okundu" | |
| E8 | Yazısız fotoğraf (ör. manzara) | "Metin okunamadı. Fotoğrafı daha net çekmeyi deneyin." | |
| E9 | Kamera açıkken vazgeç / galeriden seçmeden geri dön | Sessizce ana ekrana dönülür, hata yok | |
| E10 | Tema: Koyu / Açık / Sistem | Anında değişir, uygulama yeniden açılınca korunur | |
| E11 | Uçak modunda A ve B akışları | İnternetsiz sorunsuz çalışır | |
| E12 | Ekranı yatay çevir (işlem sırasında) | İşlem sürer, çökme yok | |
| E13 | Uygulama bilgisi → İzinler | Kamera/depolama izni listelenmez | |
| E14 | Eski/orta seviye telefonda 50+ sayfalık PDF | Çökme yok; yavaş olabilir | |

## H. El yazısı modu (PARTIAL — doğruluk garantisi yoktur)

> **Önemli:** Uygulamada ayrı bir el yazısı motoru yoktur. "El yazısı modu" yalnızca
> **görüntü ön işlemesini** (gri tonlama, kontrast, eğiklik düzeltme) değiştirir; tanıma
> yine ML Kit'in basılı metin modeliyle yapılır. Bu yüzden el yazısında sonuç
> **düşük doğrulukta olabilir veya hiç metin çıkmayabilir**. Bu testlerin amacı
> "doğru okudu mu" değil, **"mod çalışıyor, çökmüyor ve basılı metni bozmuyor mu"**.

Ayarlar → **El yazısı modu** anahtarı ile açılır.

| # | Test | Beklenen | Sonuç |
|---|---|---|---|
| H1 | Ayarlar → El yazısı modu AÇ → uygulamayı kapat/aç | Anahtar açık kalır (ayar kalıcı) | |
| H2 | El yazısı modu KAPALI iken Hazırlık 1'i okut | V1 ile **aynı** sonuç (basılı metin davranışı değişmemiş) | |
| H3 | El yazısı modu AÇIK iken Hazırlık 1'i (basılı) okut | Metin yine çıkar; ön işleme basılı metni bozmaz | |
| H4 | El yazısı modu AÇIK iken Hazırlık 7'yi okut | İşlem tamamlanır; metin **kısmen** çıkabilir veya "Metin okunamadı." mesajı gelir — çökme/donma olmamalı | |
| H5 | H4'ü el yazısı modu KAPALI iken tekrarla | İki sonucu not edin; hangisi daha iyi okuduysa yazın (beklenti yok, ölçüm var) | |
| H6 | Eğik çekilmiş el yazısı sayfası (Hazırlık 7, 2. kopya) | Satırlar düzeltilmeye çalışılır; sonuç düz kopyadan kötü olmamalı | |
| H7 | El yazısı modu AÇIK + 3 fotoğraf birlikte | Üç görsel de işlenir, ilerleme doğru sayar, çökme yok | |
| H8 | El yazısı modu AÇIK + büyük fotoğraf (12 MP+) | Ön işleme arayüzü **dondurmaz** (isolate), işlem birkaç saniye sürebilir | |
| H9 | H4 sırasında **İptal** | İşlem durur, hak harcanmaz, geçici dosya kalmaz | |
| H10 | El yazısı modu AÇIK iken PDF Aç (taranmış PDF) | Akış bozulmaz; PDF sayfaları yine okunur | |
| H11 | H4 sonrası cihazın geçici klasörü (dosya yöneticisi / `adb shell`) | Ön işlenmiş `.jpg` artıkları **birikmez** | |

## N. Karakter düzeltme (Z ↔ 2, S ↔ 5)

Düzeltme **bağlama duyarlıdır**: yalnızca harflerin arasında kalan rakamlar düzeltilir.
Sayılar, tarihler, telefonlar, para tutarları ve seri kodları **değiştirilmez**.

| # | Test | Beklenen | Sonuç |
|---|---|---|---|
| N1 | Hazırlık 8'i okut | Sonuç ekranında "**N düzeltme · ham metne dön**" bilgi çipi görünür (düzeltme yapıldıysa) | |
| N2 | OCR `ME2AR` okuduysa | Metinde `MEZAR` görünür | |
| N3 | OCR `5ELAM` okuduysa | Metinde `SELAM` görünür | |
| N4 | `12.500 TL` satırı | **Aynen** `12.500 TL` (harfe çevrilmez) | |
| N5 | `%20` satırı | **Aynen** `%20` | |
| N6 | `11/09/2026` satırı | **Aynen** `11/09/2026` | |
| N7 | `0532 123 45 67` satırı | **Aynen** kalır | |
| N8 | `SERI NO: A5B2C` satırı | Seri kod **bozulmaz** (harf+rakam karışık kod korunur) | |
| N9 | Türkçe karakterler (Hazırlık 1) | `Ç Ş İ Ü Ö ı ş ğ` düzeltmeden sonra da doğru | |
| N10 | "N düzeltme · ham metne dön" çipine dokun | Metin OCR'ın **ham** çıktısına döner (düzeltmeler geri alınır) | |
| N11 | N10'dan sonra Kaydet | Ekranda görünen metin kaydedilir (ham metin) | |
| N12 | Metin PDF'i (Hazırlık 3) okut | Metin katmanı **birebir** kalır; düzeltme uygulanmaz, düzeltme çipi çıkmaz | |
| N13 | Hiç düzeltme gerekmeyen net bir belge | Düzeltme çipi **görünmez** (sahte düzeltme yok) | |

## T. Tablo algılama

Tablo algılama **sezgiseldir**: kesinlik garantisi yoktur. Tablo bulunamazsa uygulama
normal düz metin verir (hata değildir).

| # | Test | Beklenen | Sonuç |
|---|---|---|---|
| T1 | Hazırlık 9'u okut | Sonuç ekranında "**Tablo: 4 satır × 3 kolon**" benzeri bilgi çipi | |
| T2 | T1'deki çipe dokun | Tablo önizleme ekranı açılır; hücreler ızgara halinde | |
| T3 | Tablo önizlemede bir hücreyi düzenle | Yazı değişir, ekrandan çıkınca kaybolmaz | |
| T4 | Tablo önizleme → **Metne dönüştür** | Sonuç metni hizalanmış tablo metnine dönüşür | |
| T4b | Tablo önizleme → **Tamam** | Düzenlenen hücreler korunur, sonuç metni değişmez | |
| T5 | Düz paragraf metni (Hazırlık 1) okut | Tablo çipi **görünmez** (yanlış tablo uydurulmaz) | |
| T6 | Tek kolonlu liste okut | Tablo çipi görünmez (1 kolon tablo sayılmaz) | |
| T7 | Market fişi okut | Ürün / fiyat kolonları ayrışır; `2.500 TL` **tek hücrede** kalır (bölünmez) | |
| T8 | Geniş tablo (Hazırlık 10) | Kolonlar algılanır veya düz metne düşer; çökme yok | |
| T9 | Tablo önizleme → geri | Sonuç ekranı korunur, metin kaybolmaz | |
| T10 | Tablo algılanan belgeyi Kaydet → Geçmiş'ten aç | Metin korunur (tablo metni olarak) | |
| T11 | Tablo modu için ayrı limit | Tablo algılama **ek kota tüketmez** (Pro ekranında sayı aynı) | |
| T12 | Tablo önizleme → sağ üstteki **PDF simgesi** | Düzenlenmiş hücrelerle tablo PDF'i oluşur (bkz. O6) | |

## O. PDF çıktısı (metin / tablo / fotoğraf → PDF)

Tamamen çevrimdışıdır. Yazı tipi uygulamanın içinde gömülüdür.

| # | Test | Adımlar | Beklenen | Sonuç |
|---|---|---|---|---|
| O1 | Metin → PDF | Herhangi bir OCR sonucu → **Metni PDF Yap** → Cihaza kaydet | PDF oluşur; açıldığında başlık + metin görünür | |
| O2 | Türkçe karakter | O1'in PDF'ini aç | `ş ğ İ ı Ç Ü Ö` **doğru** görünür (kutu/soru işareti yok) | |
| O3 | Uzun metin sayfalama | Hazırlık 11 → PDF | Metin birden fazla sayfaya bölünür; **taşma ve boş sayfa yok**; sağ altta sayfa numarası | |
| O4 | Paylaş | O1 → **Paylaş** | WhatsApp/E-posta'ya PDF olarak gider, karşı taraf açabilir | |
| O5 | Boş metin | Metni tamamen sil → Metni PDF Yap | Anlaşılır hata; boş PDF oluşmaz | |
| O6 | Tablo → PDF | Hazırlık 9 → Metni PDF Yap → **Tablo olarak** | Gerçek tablo: satır/kolon **kenarlıkları** görünür, başlık satırı gri | |
| O7 | Aynı belgeyi metin olarak | Hazırlık 9 → Metni PDF Yap → **Metin olarak** | Tablo yerine düz metin basılır (seçim çalışıyor) | |
| O8 | Geniş tablo → PDF | Hazırlık 10 → Tablo olarak | Sayfa **yatay** (landscape) basılır, kolonlar sığar | |
| O9 | Uzun tablo → PDF | 40+ satırlık tablo | Birden fazla sayfa; **başlık satırı her sayfada tekrarlanır** | |
| O10 | Fotoğraf → PDF | Ana ekran → **Fotoğrafı PDF Yap** → 1 dikey fotoğraf | Tek sayfalık PDF, sayfa dikey, fotoğraf **oranı bozulmaz** | |
| O11 | Yatay fotoğraf | O10'u yatay fotoğrafla | Sayfa **yatay**, kırpılma yok | |
| O12 | Çoklu fotoğraf → tek PDF | Fotoğrafı PDF Yap → 3 fotoğraf (dikey+yatay karışık) | **Tek** PDF, 3 sayfa, **seçim sırası korunur**, her sayfa kendi yönünde | |
| O13 | EXIF yönü | Telefonu yan tutarak çekilmiş fotoğrafı PDF yap | Fotoğraf **doğru yönde** (yan yatmaz) | |
| O14 | Büyük fotoğraf / bellek | 12 MP+ 3 fotoğraf → PDF | Çökme yok, dosya makul boyutta (küçültme çalışıyor) | |
| O15 | PDF adı | O1'de başlık "Fatura 12" | Dosya adı `Fatura 12 - GG.AA.YYYY.pdf` | |
| O16 | Geçici dosya temizliği | Birkaç PDF paylaş → geçici klasörü kontrol et | Artık dosyalar birikmez | |
| O17 | Uçak modu | O1, O6, O12'yi internetsiz yap | Hepsi çalışır (tam çevrimdışı) | |
| O18 | İşlem sırasında geri tuşu | PDF oluşturulurken geri | Uygulama donmaz/çökmez | |
| O19 | Fotoğraf seçmeden vazgeç | Fotoğrafı PDF Yap → seçiciyi kapat | Sessizce ana ekrana dönülür, hata yok, hak harcanmaz | |

## Z. Bu turun düzeltmeleri (gerçek cihaz doğrulaması)

Bu bölüm, gerçek cihaz testinde bulunan üç sorunun gerçekten düzeldiğini ölçer.
**Her satır cihazda denenmeden PASS yazılmaz.**

### Z1–Z6 · Tablo algılama

| # | Test | Beklenen | Sonuç |
|---|---|---|---|
| Z1 | Çizgili 3 kolonlu tablo (Hazırlık 9) | "Tablo: N satır × 3 kolon" çipi çıkar; hücreler doğru ayrışır | |
| Z2 | Çizgisiz 3 kolonlu tablo | Aynı şekilde 3 kolon algılanır (çizgi şart değil) | |
| Z3 | Eğik çekilmiş tablo (Hazırlık 15) | Satır sayısı **gerçek satır sayısıyla aynı** olmalı; satırlar bölünmemeli | |
| Z4 | Market fişi (Hazırlık 12) | Kolon sayısı **2** olmalı (tutarlar sağa dayalı olsa da bölünmemeli) | |
| Z5 | Başlıklı tablo (Hazırlık 13) | Başlık tek hücrede kalır, kolonlara parçalanmaz | |
| Z6 | 4+ kolonlu tablo (Hazırlık 10) | Kolonlar algılanır veya düz metne düşer; **veri kaybolmaz** | |
| Z6b | Tablo algılanamayan karmaşık tablo | "Tablo algılanamadı, metin olarak gösteriliyor" bilgisi çıkar ve metin tam görünür | |
| Z6c | Düz paragraf | Ne tablo çipi ne "algılanamadı" bilgisi çıkar (gereksiz uyarı yok) | |

### Z7–Z10 · Fotoğraf PDF / Metin PDF ayrımı

| # | Test | Beklenen | Sonuç |
|---|---|---|---|
| Z7 | Ana ekran → **Fotoğrafı PDF Yap** → 1 fotoğraf | PDF'te **fotoğrafın kendisi** var; metin seçilemez | |
| Z8 | Fotoğraf Çek → OCR → düzenle → **Metni PDF Yap** → "Metin olarak" | PDF'te **seçilebilir metin** var; fotoğraf **yok**. PDF görüntüleyicide metni işaretleyip kopyalayın | |
| Z9 | Tablo algılanan belge → **Metni PDF Yap** → "Tablo olarak" | Gerçek tablo (kenarlıklar) + metin seçilebilir; fotoğraf yok | |
| Z10 | Kapıda "AHMET / 12.05.2026 / 3500 TL" yazısı → OCR → Metni PDF Yap | Üç satır PDF'te kopyalanabilir metin olarak çıkar | |

### Z11–Z16 · El yazısı ve perspektif (PARTIAL — doğruluk garantisi yok)

Amaç "doğru okudu mu" değil; **çökmüyor mu, basılı metni bozmuyor mu, eskiye göre daha iyi mi**.

| # | Test | Beklenen | Sonuç |
|---|---|---|---|
| Z11 | El yazısı modu KAPALI iken Hazırlık 14(a) | Sonucu **not edin** (karşılaştırma tabanı) | |
| Z12 | El yazısı modu AÇIK iken Hazırlık 14(a) | İşlem tamamlanır; sonucu Z11 ile karşılaştırıp **hangisinin daha iyi olduğunu yazın** | |
| Z13 | El yazısı modu AÇIK iken Hazırlık 14(b) (perspektif) | Çökme yok; sonuç Z12'den kötü olmamalı | |
| Z14 | El yazısı modu AÇIK iken Hazırlık 14(c) (gölge/düşük ışık) | Çökme yok; aydınlatma normalizasyonu sayesinde gölgeli taraf da okunmaya çalışılır | |
| Z15 | El yazısı modu AÇIK iken **basılı** belge (Hazırlık 1) | Basılı metin sonucu bozulmamalı | |
| Z16 | El yazısı modu AÇIK, 12 MP fotoğraf | Arayüz donmaz; işlem birkaç saniye sürebilir; iki geçiş yapılsa bile **tek OCR hakkı** düşer | |

### Z17–Z19 · Karakter düzeltme (bozulmadı mı)

| # | Test | Beklenen | Sonuç |
|---|---|---|---|
| Z17 | `ME2AR` okunan belge | Metinde `MEZAR` | |
| Z18 | `5ELAM` okunan belge | Metinde `SELAM` | |
| Z19 | `2025`, `02.05.2026`, `5551234567`, `2500 TL`, `%20` | **Hiçbiri değişmez** | |
| Z19b | Tablo hücrelerinde aynı düzeltme | Hücrede `ME2AR` kalmaz; metinle tutarlı | |

## P. Free / Pro (debug APK ile)

`flutter run` veya debug APK ile yapılır.

**Limitleri hızlı test etme:** Ayarlar → Pro Durumu → sayfanın en altındaki **Geliştirici araçları**:
- **Free sayaçlarını limite doldur** → günlük OCR, PDF okuma ve PDF oluşturma hakları anında biter. 10 fotoğraf çekmeden P1, P5 ve P16 test edilebilir.
- **Bugünkü Free sayaçlarını sıfırla** → haklar geri gelir, testi baştan yaparsınız.
- **Mock Pro** → Pro özelliklerini ödemesiz açar.

Bu araçlar yalnızca debug derlemededir; release APK'da bulunmazlar (bkz. R bölümü).

| # | Test | Beklenen | Sonuç |
|---|---|---|---|
| P0 | Geliştirici araçları → "Free sayaçlarını limite doldur" | "Günlük haklar doldu."; Pro ekranında "Bugün kalan OCR: 0 / 10", "Bugün kalan PDF: 0 / 3", "Bugün kalan PDF oluşturma: 0 / 2" | |
| P1 | P0'dan sonra Fotoğraf Çek (veya 10 gerçek OCR yapıp 11.'yi dene) | Kamera AÇILMADAN "Günlük OCR limitin doldu." + İptal / Pro'yu İncele | |
| P1b | Sayaçları sıfırla → 1 OCR tamamla | Pro ekranında kalan OCR 10 → 9 olur (gerçek sayım doğru) | |
| P2 | P1'de İptal | Pencere kapanır, uygulama normal | |
| P3 | P1'de Pro'yu İncele → geri | Pro ekranı açılır; "Bugün kalan OCR: 0 / 10"; geri dönünce kamera açılmaz | |
| P4 | OCR işlemini iptal et veya yazısız fotoğraf okut | Hak harcanmaz (Pro ekranında sayı değişmez) | |
| P5 | P0'dan sonra (veya 3 PDF işleyip 4.'yü dene) PDF Aç | Dosya seçici AÇILMADAN "Günlük PDF limitin doldu." | |
| P5b | Sayaçları sıfırla → 1 PDF işle | Kalan PDF 3 → 2 olur; OCR hakkı değişmez | |
| P6 | 24 sayfalık PDF | "Bu PDF 24 sayfa." → "İlk 10 sayfayı işle" → yalnızca Sayfa 1–10; bilgi satırı "ilk 10 / 24 sayfa" | |
| P7 | P6'da İptal | İşlem ekranı kapanır, hak harcanmaz | |
| P8 | Galeriden 5 fotoğraf | "5 fotoğraf seçtin." → "İlk 3 fotoğrafı işle" → Görsel 1–3 | |
| P9 | 25 MB'tan büyük PDF | "Bu PDF çok büyük (… MB)." | |
| P10 | Geliştirici araçları → Mock Pro AÇ | Ana ekrandaki Pro kartı kaybolur; Ayarlar'da rozet "Pro"; P1, P5, P6, P8, P9 sınırları uygulanmaz | |
| P11 | Mock Pro açıkken uygulamayı tamamen kapat / aç | Free'ye döner (Mock Pro kalıcı değil) | |
| P12 | Limit dolu iken limit penceresi → Pro'yu İncele → Mock Pro aç → geri | İşlem kaldığı yerden devam eder (kamera / seçici açılır) | |
| P13 | Uçak modunda P1–P10 | İnternetsiz aynı davranış | |
| P14 | Limit doldur → telefon saatini yarına al → uygulamayı aç | Haklar yenilenir | |
| P15 | P14'ten sonra saati bugüne geri al → uygulamayı aç | Yeni hak **kazanılmaz** (yarının sayacı geçerli kalır) | |
| P16 | Sayaçları sıfırla → 2 PDF oluştur → 3.'yü dene | 3.'de **PDF oluşturulmadan** "Günlük PDF oluşturma limitin doldu." + İptal / Pro'yu İncele | |
| P16b | P16'dan sonra Pro ekranı | "Bugün kalan PDF oluşturma: 0 / 2" | |
| P17 | Sayaçları sıfırla → 1 PDF oluştur | Kalan PDF oluşturma 2 → 1; **OCR ve PDF okuma hakları değişmez** | |
| P18 | 10 OCR + 3 PDF okuma yap | PDF **oluşturma** hakkı hâlâ 2 (ayrı kota) | |
| P19 | PDF oluşturmayı iptal et veya hata aldır (ör. boş metin) | Hak **harcanmaz** (Pro ekranında sayı değişmez) | |
| P20 | "Fotoğrafı PDF Yap"da seçiciyi kapat | Hak harcanmaz | |
| P21 | El yazısı modu AÇIK iken 1 OCR | Yalnızca OCR hakkı düşer; **ek kota yok** | |
| P22 | Tablo algılanan belgede tablo önizleme aç/kapat | Hiçbir hak harcanmaz | |
| P23 | Mock Pro AÇ → 5 PDF oluştur | Sınır uygulanmaz; Free'ye dönünce **Free sayacı 0** (Pro kullanımı Free'ye yazılmaz) | |
| P24 | Limit doldur → yarına al | PDF oluşturma hakkı da yenilenir (2) | |

### Release APK güvenlik kontrolü (zorunlu)

`flutter build apk --release` ile üretilen APK'yı kurun.

| # | Test | Beklenen | Sonuç |
|---|---|---|---|
| R1 | Ayarlar → Pro Durumu → sayfanın en altı | "Geliştirici araçları" / "Mock Pro" **YOK** | |
| R2 | Pro ekranındaki düğme | "Pro'ya Geç · Yakında", dokunulamaz; hiçbir ödeme ekranı açılmaz | |
| R3 | Rozet | "Free" | |
| R4 | Ana ekran ve Geçmiş'in altı | Reklam alanı görünmez, boşluk yok | |
| R5 | Release APK'da 10 OCR tamamla, 11.'yi dene | Limit release'te de geçerli: "Günlük OCR limitin doldu." | |
| R6 | Release APK'da Pro ekranını baştan sona kaydır | Hiçbir yerde Mock Pro / sayaç sıfırlama / test satın alma yok | |
| R7 | Release APK'da 2 PDF oluştur, 3.'yü dene | "Günlük PDF oluşturma limitin doldu." (limit release'te de geçerli) | |
| R8 | Release APK'da el yazısı modu + tablo + PDF çıktısı | Hepsi çalışır; hiçbiri geliştirici aracı gerektirmez | |
| R9 | Release APK'da uçak modu | OCR, tablo, PDF okuma ve PDF oluşturma internetsiz çalışır | |

Otomatik ön kontrol (isteğe bağlı, bilgisayarda):

```bash
bash tool/verify_release_guards.sh build/app/outputs/flutter-apk/app-release.apk
```

Bu betik kaynak koddaki release korumalarını doğrular ve APK içinde geliştirici arayüzü metni kalıp kalmadığını tarar. GitHub Actions'ta da her derlemede otomatik çalışır. Yine de R1–R6'yı cihazda gözle doğrulayın.

## Hata bildirimi

Bir test kalırsa şunları not edin: senaryo numarası, cihaz ve Android sürümü, adımlar, ekranda görünen mesaj. Mümkünse USB hata ayıklamayla `flutter run` çalıştırıp konsoldaki `debugPrint` çıktısını ekleyin.
