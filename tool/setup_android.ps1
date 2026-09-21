# MetinCep Android klasörünü hazırlar (Windows PowerShell).
# Kullanım: powershell -ExecutionPolicy Bypass -File tool\setup_android.ps1
$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..")

flutter create . --org com.metincep --project-name metincep --platforms android --no-pub

# flutter create varsayilan sayac testini uretir; MetinCep'te MyApp olmadigi icin siliniyor.
$widgetTest = Join-Path (Get-Location) "test/widget_test.dart"
if ((Test-Path $widgetTest) -and ((Get-Content $widgetTest -Raw) -match "MyApp")) {
    Remove-Item $widgetTest
}

$kts = Join-Path (Get-Location) "android/app/build.gradle.kts"
if (Test-Path $kts) {
    $content = [System.IO.File]::ReadAllText($kts)
    $content = $content.Replace('applicationId = "com.metincep.metincep"', 'applicationId = "com.metincep.app"')
    $content = $content.Replace('minSdk = flutter.minSdkVersion', 'minSdk = 24')
    if (-not $content.Contains('proguard-rules.pro')) {
        $old = 'signingConfig = signingConfigs.getByName("debug")'
        $new = $old + "`n            " + 'proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")'
        $content = $content.Replace($old, $new)
    }
    [System.IO.File]::WriteAllText($kts, $content)

    # Yamalarin gercekten uygulandigini dogrula (Flutter sablonu degismis olabilir).
    $problems = @()
    if (-not $content.Contains('com.metincep.app')) {
        $problems += "applicationId com.metincep.app olarak ayarlanamadi."
    }
    if (-not $content.Contains('minSdk = 24')) {
        $problems += "minSdk 24 olarak ayarlanamadi."
    }
    if (-not $content.Contains('proguard-rules.pro')) {
        $problems += "R8 kurallari (proguard-rules.pro) eklenemedi; ML Kit icin release derlemesi basarisiz olabilir."
    }
    if ($problems.Count -gt 0) {
        foreach ($p in $problems) { Write-Error $p }
        Write-Error "tool/setup_android.ps1 icindeki yamalari guncelleyin."
        exit 1
    }
} else {
    Write-Error "android/app/build.gradle.kts bulunamadi."
    exit 1
}

Write-Host "MetinCep Android dosyalari hazir (applicationId: com.metincep.app, minSdk: 24, R8 kurallari eklendi)."
