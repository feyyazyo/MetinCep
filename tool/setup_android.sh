#!/usr/bin/env bash
# MetinCep Android klasörünü hazırlar (macOS / Linux / GitHub Actions).
# Var olan dosyalara dokunmaz; yalnızca eksik Flutter Android dosyalarını üretir.
set -euo pipefail
cd "$(dirname "$0")/.."

flutter create . --org com.metincep --project-name metincep --platforms android --no-pub

# flutter create, var olmayan varsayılan sayaç testini üretir; MetinCep'te MyApp olmadığı için siliyoruz.
if [ -f test/widget_test.dart ] && grep -q "MyApp" test/widget_test.dart; then
  rm test/widget_test.dart
fi

KTS="android/app/build.gradle.kts"
GROOVY="android/app/build.gradle"

if [ -f "$KTS" ]; then
  perl -pi -e 's/applicationId = "com\.metincep\.metincep"/applicationId = "com.metincep.app"/' "$KTS"
  perl -pi -e 's/minSdk = flutter\.minSdkVersion/minSdk = 24/' "$KTS"
  if ! grep -q "proguard-rules.pro" "$KTS"; then
    perl -pi -e 's/(signingConfig = signingConfigs\.getByName\("debug"\))/$1\n            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")/' "$KTS"
  fi
elif [ -f "$GROOVY" ]; then
  perl -pi -e 's/applicationId "com\.metincep\.metincep"/applicationId "com.metincep.app"/' "$GROOVY"
  perl -pi -e 's/applicationId = "com\.metincep\.metincep"/applicationId = "com.metincep.app"/' "$GROOVY"
  perl -pi -e 's/minSdkVersion flutter\.minSdkVersion/minSdkVersion 24/' "$GROOVY"
  perl -pi -e 's/minSdk = flutter\.minSdkVersion/minSdk = 24/' "$GROOVY"
fi

# Yamaların gerçekten uygulandığını doğrula.
# Flutter şablonu değişirse perl komutları sessizce hiçbir şey yapmaz; bu durumda
# yanlış applicationId veya eksik R8 kuralıyla release APK üretilmesin diye burada dururuz.
GRADLE_FILE=""
if [ -f "$KTS" ]; then
  GRADLE_FILE="$KTS"
elif [ -f "$GROOVY" ]; then
  GRADLE_FILE="$GROOVY"
fi

if [ -z "$GRADLE_FILE" ]; then
  echo "HATA: android/app/build.gradle(.kts) bulunamadı." >&2
  exit 1
fi

setup_failed=0
if ! grep -q 'com\.metincep\.app' "$GRADLE_FILE"; then
  echo "HATA: applicationId com.metincep.app olarak ayarlanamadı ($GRADLE_FILE)." >&2
  setup_failed=1
fi
if ! grep -qE 'minSdk(Version)? = 24|minSdkVersion 24' "$GRADLE_FILE"; then
  echo "HATA: minSdk 24 olarak ayarlanamadı ($GRADLE_FILE)." >&2
  setup_failed=1
fi
if [ -f "$KTS" ] && ! grep -q 'proguard-rules.pro' "$KTS"; then
  echo "HATA: R8 kuralları (proguard-rules.pro) eklenemedi ($KTS)." >&2
  echo "      ML Kit sınıfları için bu kurallar olmadan release derlemesi başarısız olabilir." >&2
  setup_failed=1
fi

if [ "$setup_failed" -ne 0 ]; then
  echo "Flutter şablonu değişmiş olabilir. tool/setup_android.sh içindeki yamaları güncelleyin." >&2
  exit 1
fi

echo "MetinCep Android dosyaları hazır (applicationId: com.metincep.app, minSdk: 24, R8 kuralları eklendi)."
