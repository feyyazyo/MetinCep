#!/usr/bin/env bash
# MetinCep — release güvenlik doğrulaması
#
# İki bölüm:
#   1) KAYNAK KONTROLLERİ (zorunlu): Mock Pro ve geliştirici araçlarının
#      kDebugMode koruması yerinde mi? Koruma kaldırılırsa bu betik HATA verir.
#   2) APK TARAMASI (bilgilendirme): release APK içindeki derlenmiş kodda
#      geliştirici arayüzü metinleri kalmış mı?
#
# Kullanım:
#   bash tool/verify_release_guards.sh [release-apk-yolu]
#
# APK yolu verilmezse yalnızca kaynak kontrolleri çalışır.

set -uo pipefail
cd "$(dirname "$0")/.."

fail=0
pass() { printf '  [PASS] %s\n' "$1"; }
err()  { printf '  [FAIL] %s\n' "$1"; fail=1; }
warn() { printf '  [UYARI] %s\n' "$1"; }

echo "=============================================="
echo "1) KAYNAK KONTROLLERİ (release güvenliği)"
echo "=============================================="

ENTITLEMENT="lib/services/entitlement_service.dart"
PRO_SCREEN="lib/screens/pro/pro_screen.dart"
USAGE="lib/services/usage_tracker.dart"
MAIN="lib/main.dart"

# 1.1 Mock Pro'ya izin veren TEK alan kDebugMode ile korunmalı.
if grep -q '(kDebugMode || AppConstants.isTestBuild) && allowMockPro' "$ENTITLEMENT"; then
  pass "Mock Pro izni kDebugMode / işaretli test derlemesi ile korunuyor ($ENTITLEMENT)"
else
  err "Mock Pro izninin derleme zamanı koruması bulunamadı ($ENTITLEMENT)"
fi

# 1.1b Test derlemesi bayrağı VARSAYILAN OLARAK KAPALI olmalı.
#      bool.fromEnvironment tanımsızken false döner; defaultValue: true yazılırsa
#      mağaza derlemesi de sınırsız olurdu.
CONSTANTS="lib/core/constants/app_constants.dart"
if grep -q "static const bool isTestBuild = bool.fromEnvironment('METINCEP_TEST_BUILD');" "$CONSTANTS"; then
  pass "Test derlemesi bayrağı varsayılan olarak KAPALI ($CONSTANTS)"
else
  err "isTestBuild tanımı beklenen biçimde değil ($CONSTANTS)"
fi
if grep -q "METINCEP_TEST_BUILD'," "$CONSTANTS" || grep -q 'defaultValue: true' "$CONSTANTS"; then
  err "isTestBuild için varsayılan değer verilmiş; mağaza derlemesi sınırsız olabilir"
else
  pass "isTestBuild'e varsayılan değer verilmemiş"
fi

# 1.1c MAĞAZA derlemesi test bayrağını GEÇMEMELİ.
WORKFLOW=".github/workflows/build-apk.yml"
if [ -f "$WORKFLOW" ]; then
  store_line=$(grep -n 'flutter build apk --release' "$WORKFLOW" | grep -v 'METINCEP_TEST_BUILD' || true)
  tainted=$(grep -n 'flutter build apk --release' "$WORKFLOW" | grep 'METINCEP_TEST_BUILD' || true)
  if [ -z "$store_line" ]; then
    err "İş akışında test bayrağı OLMAYAN bir release derlemesi yok ($WORKFLOW)"
  elif [ -z "$tainted" ]; then
    pass "Mağaza derlemesi test bayrağı geçmiyor (test APK'sı ayrı adımda)"
  else
    pass "Mağaza derlemesi ayrı; test APK'sı yalnızca işaretli adımda üretiliyor"
  fi
fi

# 1.2 Mock Pro durumu okunurken de izin kontrol edilmeli (izin yoksa her zaman false).
if grep -q 'bool get isMockProEnabled => _mockProAllowed && _mockProEnabled;' "$ENTITLEMENT"; then
  pass "isMockProEnabled izin olmadan asla true olamaz"
else
  err "isMockProEnabled koruması değişmiş ($ENTITLEMENT)"
fi

# 1.3 setMockPro izin yoksa hiçbir şey yapmamalı.
if grep -q 'if (!_mockProAllowed || _mockProEnabled == enabled) {' "$ENTITLEMENT"; then
  pass "setMockPro izin yokken etkisiz"
else
  err "setMockPro koruması bulunamadı ($ENTITLEMENT)"
fi

# 1.4 Geliştirici araçları kartı kDebugMode arkasında olmalı.
if grep -q 'if (kDebugMode && entitlement.isMockProAvailable) ...\[' "$PRO_SCREEN"; then
  pass "Geliştirici araçları kartı kDebugMode arkasında"
else
  err "Geliştirici araçları kartının kDebugMode koruması bulunamadı ($PRO_SCREEN)"
fi

# 1.5 "...ForDebug" ile biten TÜM metotlar kDebugMode ile korunmalı.
#     (Yeni bir geliştirici aracı eklenip koruma unutulursa burada yakalanır.)
debug_methods=$(grep -c 'ForDebug(' "$USAGE" || true)
unguarded=$(awk '
  /ForDebug\(/ {
    name = $0; found = 0
    # Pencere, çok satırlı imzaları da kapsar; koruma yine metodun başında olmalı.
    for (i = 0; i < 10; i++) {
      if ((getline line) > 0 && line ~ /kDebugMode/) { found = 1; break }
    }
    if (!found) print name
  }' "$USAGE")
if [ "$debug_methods" -eq 0 ]; then
  warn "Geliştirici (ForDebug) metodu bulunamadı; kontrol atlandı ($USAGE)"
elif [ -z "$unguarded" ]; then
  pass "Geliştirici metotlarının tamamı ($debug_methods adet) kDebugMode ile korunuyor"
else
  err "kDebugMode koruması olmayan geliştirici metodu:"
  printf '%s\n' "$unguarded" | sed 's/^/         /'
fi

# 1.6 Uygulama, Mock Pro'yu açıkça etkinleştiren bir parametre geçmemeli.
if grep -q 'allowMockPro' "$MAIN"; then
  err "main.dart içinde allowMockPro geçiliyor; varsayılan davranış kullanılmalı"
else
  pass "main.dart Mock Pro'yu açıkça etkinleştirmiyor"
fi

# 1.7 Gerçek satın alma bağlanana kadar uygulama satın alma sağlayıcısı kullanmamalı.
if grep -q 'UnavailablePurchaseService()' "$MAIN"; then
  pass "Satın alma sağlayıcısı yok (hiçbir ödeme alınmaz)"
else
  warn "main.dart farklı bir PurchaseService kullanıyor; Google Play Billing bağlandıysa bu beklenendir"
fi

# 1.8 Mock Pro'ya başka bir yoldan ulaşılmamalı.
stray=$(grep -rn 'setMockPro' lib --include='*.dart' | grep -v "$ENTITLEMENT" | grep -v "$PRO_SCREEN" || true)
if [ -z "$stray" ]; then
  pass "setMockPro yalnızca korumalı yerlerden çağrılıyor"
else
  err "setMockPro beklenmeyen bir yerden çağrılıyor:"
  printf '%s\n' "$stray" | sed 's/^/         /'
fi

APK="${1:-}"
if [ -n "$APK" ]; then
  echo
  echo "=============================================="
  echo "2) APK TARAMASI"
  echo "=============================================="
  if [ ! -f "$APK" ]; then
    err "APK bulunamadı: $APK"
  else
    printf '  APK: %s (%s)\n' "$APK" "$(du -h "$APK" | cut -f1)"
    workdir="$(mktemp -d)"
    # shellcheck disable=SC2064
    trap "rm -rf '$workdir'" EXIT

    if unzip -q -o "$APK" 'lib/*/libapp.so' -d "$workdir" 2>/dev/null; then
      found=0
      # Bu metinler YALNIZCA geliştirici araçları kartında geçer.
      # ("Test Pro (yalnızca debug derleme)" bilinçli olarak taranmaz; o metin
      #  Pro durumu satırında da kullanıldığı için release'te bulunması normaldir.)
      while IFS= read -r marker; do
        if grep -aqF "$marker" "$workdir"/lib/*/libapp.so 2>/dev/null; then
          warn "Derlenmiş kodda geliştirici arayüzü metni bulundu: \"$marker\""
          found=1
        fi
      done <<'MARKERS'
Geliştirici araçları
Mock Pro
Bugünkü Free sayaçlarını sıfırla
Free sayaçlarını limite doldur
MARKERS

      # Mağaza APK'sında "TEST" şeridi OLMAMALI. (Test APK'sında olması normaldir.)
      case "$APK" in
        *TEST*) warn "Bu bir TEST APK'sı; sınırsız olması beklenir" ;;
        *)
          if grep -aqF 'METINCEP_TEST_BUILD' "$workdir"/lib/*/libapp.so 2>/dev/null; then
            warn "Derlenmiş kodda test bayrağı adı görünüyor (sabit adı; tek başına açık olduğu anlamına gelmez)"
          fi
          ;;
      esac

      if [ "$found" -eq 0 ]; then
        pass "Geliştirici arayüzü metinleri release kodunda yok (ağaç budama çalışmış)"
      else
        warn "Bu metinlerin bulunması TEK BAŞINA güvenlik açığı değildir:"
        warn "kDebugMode release'te false olduğu için Mock Pro yine de etkisizdir"
        warn "ve kart çizilmez. Yine de cihazda R1 testini mutlaka yapın."
      fi
    else
      warn "libapp.so çıkarılamadı (debug APK veya beklenmeyen APK yapısı); tarama atlandı"
    fi
  fi
fi

echo
echo "=============================================="
if [ "$fail" -eq 0 ]; then
  echo "SONUÇ: Release güvenlik korumaları YERİNDE (PASS)"
  echo "Not: Cihazda R1-R4 testleri yine de yapılmalıdır (docs/TEST_PLANI.md)."
else
  echo "SONUÇ: HATA — release güvenlik koruması eksik (FAIL)"
fi
echo "=============================================="
exit "$fail"
