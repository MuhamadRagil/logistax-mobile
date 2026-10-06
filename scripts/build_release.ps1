# Build rilis aman Logistax Mobile (Windows PowerShell 5.1+).
# Memastikan APK rilis SELALU berisi fitur intern. Aturan: lihat CLAUDE.md.
#
#   .\scripts\build_release.ps1                     # build rilis penuh
#   .\scripts\build_release.ps1 -CheckOnly          # berhenti setelah analyze (tanpa build)
#   .\scripts\build_release.ps1 -CheckOnly -AllowDirty   # uji skrip saat ada perubahan belum commit
#
# URL backend magang SENGAJA tetap (tidak ada parameter untuk mengubahnya).
param(
    [switch]$CheckOnly,
    [switch]$AllowDirty
)

$ErrorActionPreference = 'Stop'
$InternUrl = 'https://logistax-magang-production.up.railway.app/api'
$InternHost = 'logistax-magang-production.up.railway.app'
$Root = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location $Root

function Fail([string]$msg) {
    Write-Host ''
    Write-Host "GAGAL: $msg" -ForegroundColor Red
    exit 1
}
function Step([string]$msg) { Write-Host ''; Write-Host "== $msg" -ForegroundColor Cyan }
function Ok([string]$msg) { Write-Host "   OK  $msg" -ForegroundColor Green }

if ($AllowDirty -and -not $CheckOnly) {
    Fail '-AllowDirty hanya boleh dipakai bersama -CheckOnly (rilis harus dari working tree bersih).'
}

# --- a. branch, working tree, sinkron dengan origin ---
Step 'a. Git: branch master, bersih, sinkron dengan origin/master'
$branch = (git branch --show-current).Trim()
if ($branch -ne 'master') { Fail "Branch sekarang '$branch'. Rilis hanya boleh dari master." }
Ok 'branch master'

$dirty = git status --porcelain
if ($dirty) {
    if ($AllowDirty) { Write-Host '   !!  working tree TIDAK bersih (diizinkan hanya untuk -CheckOnly)' -ForegroundColor Yellow }
    else { Fail "Working tree tidak bersih. Commit atau stash dulu:`n$($dirty -join "`n")" }
} else { Ok 'working tree bersih' }

git fetch origin master --quiet
if ($LASTEXITCODE -ne 0) { Fail 'git fetch origin gagal (cek koneksi).' }
$local = (git rev-parse HEAD).Trim()
$remote = (git rev-parse origin/master).Trim()
if ($local -ne $remote) {
    Fail "master lokal ($($local.Substring(0,7))) tidak sama dengan origin/master ($($remote.Substring(0,7))). Jalankan git pull / git push dulu."
}
Ok "sinkron dengan origin/master ($($local.Substring(0,7)))"

# --- b. fitur intern ada ---
Step 'b. Fitur intern ada'
$internDir = Join-Path $Root 'lib\features\intern'
if (-not (Test-Path $internDir)) { Fail 'lib/features/intern/ tidak ada.' }
$internFiles = @(Get-ChildItem $internDir -Recurse -Filter *.dart)
if ($internFiles.Count -eq 0) { Fail 'lib/features/intern/ kosong (tidak ada file .dart).' }
Ok "lib/features/intern/ berisi $($internFiles.Count) file .dart"
foreach ($f in 'lib\features\intern\intern_config.dart', 'lib\features\intern\data\intern_api_client.dart') {
    if (-not (Test-Path (Join-Path $Root $f))) { Fail "$f tidak ada." }
    Ok $f
}

# --- c. sisa trial ---
Step 'c. Tidak ada sisa TrialReminder'
$trial = Get-ChildItem (Join-Path $Root 'lib'), (Join-Path $Root 'test') -Recurse -Filter *.dart |
    Select-String -Pattern 'TrialReminder'
if ($trial) { Fail "Ditemukan referensi TrialReminder:`n$($trial | ForEach-Object { $_.ToString() } | Out-String)" }
Ok 'grep TrialReminder kosong'

# --- d. analyze ---
Step 'd. flutter analyze (error = berhenti)'
flutter analyze --no-fatal-infos --no-fatal-warnings
if ($LASTEXITCODE -ne 0) { Fail 'flutter analyze menemukan error.' }
Ok 'analyze tanpa error'

if ($CheckOnly) {
    Write-Host ''
    Write-Host 'Mode -CheckOnly: pemeriksaan a-d lolos. Build TIDAK dijalankan.' -ForegroundColor Green
    exit 0
}

# --- e. build ---
Step 'e. Build rilis (perintah resmi)'
$pubspec = Get-Content (Join-Path $Root 'pubspec.yaml') -Raw
if ($pubspec -notmatch '(?m)^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$') { Fail 'Tidak bisa membaca version: X.Y.Z+N dari pubspec.yaml.' }
$versionName = $Matches[1]
$buildNumber = $Matches[2]
Write-Host "   versi pubspec: $versionName+$buildNumber"

flutter build apk --release --dart-define=INTERN_API_URL=$InternUrl
if ($LASTEXITCODE -ne 0) { Fail 'flutter build apk gagal.' }
$built = Join-Path $Root 'build\app\outputs\flutter-apk\app-release.apk'
if (-not (Test-Path $built)) { Fail "APK tidak ditemukan di $built" }

# --- f. salin ke nama berversi ---
Step 'f. Salin ke nama berversi'
$final = Join-Path (Split-Path $built) "logistax-absen-$versionName.apk"
if (Test-Path $final) { Fail "$final sudah ada. Naikkan versi di pubspec.yaml atau hapus file itu secara manual." }
Copy-Item $built $final
Ok $final

# --- g. verifikasi isi APK ---
Step 'g. Verifikasi URL magang ada di libapp.so'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$latin1 = [Text.Encoding]::GetEncoding(28591)
$found = @()
$missing = @()
$zip = [IO.Compression.ZipFile]::OpenRead($final)
try {
    foreach ($e in $zip.Entries | Where-Object { $_.FullName -like 'lib/*/libapp.so' }) {
        $ms = New-Object IO.MemoryStream
        $s = $e.Open(); $s.CopyTo($ms); $s.Dispose()
        if ($latin1.GetString($ms.ToArray()).Contains($InternHost)) { $found += $e.FullName } else { $missing += $e.FullName }
        $ms.Dispose()
    }
} finally { $zip.Dispose() }
if (($found.Count + $missing.Count) -eq 0 -or $missing.Count -gt 0) {
    Remove-Item $final -Force
    Fail "String '$InternHost' TIDAK ada di libapp.so ($($missing -join ', ')). Build dianggap GAGAL, salinan berversi dihapus."
}
foreach ($f in $found) { Ok "$f mengandung $InternHost" }

# --- h. ringkasan ---
Step 'h. Ringkasan'
$sdk = $env:ANDROID_HOME
if (-not $sdk) { $sdk = $env:ANDROID_SDK_ROOT }
$lp = Join-Path $Root 'android\local.properties'
if (-not $sdk -and (Test-Path $lp)) {
    $line = Get-Content $lp | Where-Object { $_ -like 'sdk.dir=*' } | Select-Object -First 1
    if ($line) { $sdk = ($line -replace '^sdk.dir=', '') -replace '\\\\', '\' }
}
$bt = $null
if ($sdk -and (Test-Path (Join-Path $sdk 'build-tools'))) {
    $bt = Get-ChildItem (Join-Path $sdk 'build-tools') -Directory | Sort-Object { [version]($_.Name -replace '[^\d.].*$', '') } | Select-Object -Last 1
}

$vName = $versionName; $vCode = $buildNumber
if ($bt -and (Test-Path (Join-Path $bt.FullName 'aapt.exe'))) {
    $badge = (& (Join-Path $bt.FullName 'aapt.exe') dump badging $final | Select-String '^package:' | Select-Object -First 1).ToString()
    Write-Host "   $badge"
} else { Write-Host "   (aapt tidak tersedia; dari pubspec: versionName=$vName versionCode=$vCode)" }

$size = (Get-Item $final).Length
Write-Host ("   Ukuran       : {0:N0} byte ({1:N1} MB)" -f $size, ($size / 1MB))
Write-Host "   SHA-256 file : $((Get-FileHash $final -Algorithm SHA256).Hash.ToLower())"

$certDigest = 'tidak tersedia (apksigner/java tidak ditemukan)'
if ($bt -and (Test-Path (Join-Path $bt.FullName 'apksigner.bat'))) {
    if (-not $env:JAVA_HOME -and -not (Get-Command java -ErrorAction SilentlyContinue)) {
        foreach ($j in 'C:\Program Files\Android\Android Studio\jbr', 'C:\Program Files\Android\Android Studio1\jbr') {
            if (Test-Path (Join-Path $j 'bin\java.exe')) { $env:JAVA_HOME = $j; break }
        }
    }
    $ErrorActionPreference = 'Continue'
    $out = & (Join-Path $bt.FullName 'apksigner.bat') verify --print-certs $final 2>&1 | Select-String 'Signer #1 certificate SHA-256 digest'
    $ErrorActionPreference = 'Stop'
    if ($out) { $certDigest = ($out.ToString() -replace '^.*digest:\s*', '').Trim() }
}
Write-Host "   SHA-256 sertifikat penandatangan: $certDigest"
Write-Host "   File akhir   : $final"
Write-Host ''
Write-Host 'BUILD RILIS LOLOS SEMUA PEMERIKSAAN.' -ForegroundColor Green
Write-Host 'Pastikan SHA-256 sertifikat sama dengan rilis sebelumnya (keystore yang sama).'
