# Google ML Kit metin tanıma: yalnızca Latin modeli kullanılıyor.
# Diğer alfabe modellerinin sınıfları APK'da yok; R8 uyarılarını sustur.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# Flutter deferred components (kullanılmıyor)
-dontwarn com.google.android.play.core.**
