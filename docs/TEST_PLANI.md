# MetinCep V1 — Gerçek Cihaz Test Planı

Otomatik testler (`flutter test`) saf mantığı ve arayüz akışını doğrular. Kamera, ML Kit OCR, PDF çizimi, paylaşım ve dosya kaydetme ise **gerçek Android cihazda** test edilmelidir.

Her satırı işaretleyin: ✅ geçti · ❌ kaldı (not düşün).

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

## P. Free / Pro (debug APK ile)

`flutter run` veya debug APK ile yapılır.

**Limitleri hızlı test etme:** Ayarlar → Pro Durumu → sayfanın en altındaki **Geliştirici araçları**:
- **Free sayaçlarını limite doldur** → günlük OCR ve PDF hakları anında biter. 10 fotoğraf çekmeden P1 ve P5 test edilebilir.
- **Bugünkü Free sayaçlarını sıfırla** → haklar geri gelir, testi baştan yaparsınız.
- **Mock Pro** → Pro özelliklerini ödemesiz açar.

Bu araçlar yalnızca debug derlemededir; release APK'da bulunmazlar (bkz. R bölümü).

| # | Test | Beklenen | Sonuç |
|---|---|---|---|
| P0 | Geliştirici araçları → "Free sayaçlarını limite doldur" | "Günlük haklar doldu."; Pro ekranında "Bugün kalan OCR: 0 / 10", "Bugün kalan PDF: 0 / 3" | |
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

Otomatik ön kontrol (isteğe bağlı, bilgisayarda):

```bash
bash tool/verify_release_guards.sh build/app/outputs/flutter-apk/app-release.apk
```

Bu betik kaynak koddaki release korumalarını doğrular ve APK içinde geliştirici arayüzü metni kalıp kalmadığını tarar. GitHub Actions'ta da her derlemede otomatik çalışır. Yine de R1–R6'yı cihazda gözle doğrulayın.

## Hata bildirimi

Bir test kalırsa şunları not edin: senaryo numarası, cihaz ve Android sürümü, adımlar, ekranda görünen mesaj. Mümkünse USB hata ayıklamayla `flutter run` çalıştırıp konsoldaki `debugPrint` çıktısını ekleyin.
