#!/usr/bin/env bash
# Build rilis aman Logistax Mobile (Git Bash / Linux / macOS). Aturan: lihat CLAUDE.md.
#
#   bash scripts/build_release.sh                       # build rilis penuh
#   bash scripts/build_release.sh --check-only          # berhenti setelah analyze
#   bash scripts/build_release.sh --check-only --allow-dirty
#
# URL backend magang SENGAJA tetap (tidak ada opsi untuk mengubahnya).
set -u

INTERN_URL='https://logistax-magang-production.up.railway.app/api'
INTERN_HOST='logistax-magang-production.up.railway.app'
CHECK_ONLY=0
ALLOW_DIRTY=0
for a in "$@"; do
  case "$a" in
    --check-only) CHECK_ONLY=1 ;;
    --allow-dirty) ALLOW_DIRTY=1 ;;
    *) echo "Opsi tidak dikenal: $a" >&2; exit 2 ;;
  esac
done

cd "$(dirname "$0")/.." || exit 1
ROOT="$(pwd)"

fail() { echo; echo "GAGAL: $1" >&2; exit 1; }
step() { echo; echo "== $1"; }
ok() { echo "   OK  $1"; }

[ "$ALLOW_DIRTY" = 1 ] && [ "$CHECK_ONLY" = 0 ] && fail '--allow-dirty hanya boleh dipakai bersama --check-only.'

step 'a. Git: branch master, bersih, sinkron dengan origin/master'
branch="$(git branch --show-current)"
[ "$branch" = master ] || fail "Branch sekarang '$branch'. Rilis hanya boleh dari master."
ok 'branch master'
dirty="$(git status --porcelain)"
if [ -n "$dirty" ]; then
  if [ "$ALLOW_DIRTY" = 1 ]; then echo '   !!  working tree TIDAK bersih (diizinkan hanya untuk --check-only)'
  else fail "Working tree tidak bersih. Commit atau stash dulu:
$dirty"; fi
else ok 'working tree bersih'; fi
git fetch origin master --quiet || fail 'git fetch origin gagal (cek koneksi).'
local_sha="$(git rev-parse HEAD)"; remote_sha="$(git rev-parse origin/master)"
[ "$local_sha" = "$remote_sha" ] || fail "master lokal (${local_sha:0:7}) tidak sama dengan origin/master (${remote_sha:0:7}). Jalankan git pull / git push dulu."
ok "sinkron dengan origin/master (${local_sha:0:7})"

step 'b. Fitur intern ada'
[ -d lib/features/intern ] || fail 'lib/features/intern/ tidak ada.'
n="$(find lib/features/intern -name '*.dart' | wc -l | tr -d ' ')"
[ "$n" -gt 0 ] || fail 'lib/features/intern/ kosong (tidak ada file .dart).'
ok "lib/features/intern/ berisi $n file .dart"
for f in lib/features/intern/intern_config.dart lib/features/intern/data/intern_api_client.dart; do
  [ -f "$f" ] || fail "$f tidak ada."
  ok "$f"
done

step 'c. Tidak ada sisa TrialReminder'
if grep -rn 'TrialReminder' lib test --include='*.dart'; then fail 'Ditemukan referensi TrialReminder (lihat di atas).'; fi
ok 'grep TrialReminder kosong'

step 'd. flutter analyze (error = berhenti)'
flutter analyze --no-fatal-infos --no-fatal-warnings || fail 'flutter analyze menemukan error.'
ok 'analyze tanpa error'

if [ "$CHECK_ONLY" = 1 ]; then
  echo; echo 'Mode --check-only: pemeriksaan a-d lolos. Build TIDAK dijalankan.'; exit 0
fi

step 'e. Build rilis (perintah resmi)'
ver_line="$(grep -E '^version:[[:space:]]*[0-9]+\.[0-9]+\.[0-9]+\+[0-9]+' pubspec.yaml | head -1 | tr -d '\r')"
[ -n "$ver_line" ] || fail 'Tidak bisa membaca version: X.Y.Z+N dari pubspec.yaml.'
ver="$(echo "$ver_line" | sed -E 's/^version:[[:space:]]*//')"
version_name="${ver%%+*}"; build_number="${ver##*+}"
echo "   versi pubspec: $version_name+$build_number"
flutter build apk --release --dart-define=INTERN_API_URL="$INTERN_URL" || fail 'flutter build apk gagal.'
built="$ROOT/build/app/outputs/flutter-apk/app-release.apk"
[ -f "$built" ] || fail "APK tidak ditemukan di $built"

step 'f. Salin ke nama berversi'
final="$(dirname "$built")/logistax-absen-$version_name.apk"
[ -e "$final" ] && fail "$final sudah ada. Naikkan versi di pubspec.yaml atau hapus file itu secara manual."
cp "$built" "$final" || fail 'Gagal menyalin APK.'
ok "$final"

step 'g. Verifikasi URL magang ada di libapp.so'
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
unzip -q -o "$final" 'lib/*/libapp.so' -d "$tmp" || { rm -f "$final"; fail 'Tidak bisa mengekstrak libapp.so dari APK. Salinan berversi dihapus.'; }
count=0; missing=0
for so in "$tmp"/lib/*/libapp.so; do
  [ -f "$so" ] || continue
  count=$((count + 1))
  if grep -aq "$INTERN_HOST" "$so"; then ok "${so#"$tmp"/} mengandung $INTERN_HOST"
  else echo "   !!  ${so#"$tmp"/} TIDAK mengandung $INTERN_HOST"; missing=$((missing + 1)); fi
done
if [ "$count" -eq 0 ] || [ "$missing" -gt 0 ]; then
  rm -f "$final"
  fail "String '$INTERN_HOST' TIDAK ada di libapp.so. Build dianggap GAGAL, salinan berversi dihapus."
fi

step 'h. Ringkasan'
sdk="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
if [ -z "$sdk" ] && [ -f android/local.properties ]; then
  sdk="$(grep '^sdk.dir=' android/local.properties | head -1 | sed -e 's/^sdk.dir=//' -e 's/\\\\/\//g' -e 's/\\//g' | tr -d '\r')"
fi
bt=''
[ -n "$sdk" ] && [ -d "$sdk/build-tools" ] && bt="$sdk/build-tools/$(ls "$sdk/build-tools" | sort -V | tail -1)"
aapt=''; [ -n "$bt" ] && { [ -x "$bt/aapt" ] && aapt="$bt/aapt"; [ -x "$bt/aapt.exe" ] && aapt="$bt/aapt.exe"; }
if [ -n "$aapt" ]; then "$aapt" dump badging "$final" | grep '^package:' | head -1 | sed 's/^/   /'
else echo "   (aapt tidak tersedia; dari pubspec: versionName=$version_name versionCode=$build_number)"; fi
size="$(wc -c < "$final" | tr -d ' ')"
echo "   Ukuran       : $size byte"
echo "   SHA-256 file : $(sha256sum "$final" | cut -d' ' -f1)"
cert='tidak tersedia (apksigner/java tidak ditemukan)'
if [ -n "$bt" ]; then
  signer=''; [ -x "$bt/apksigner" ] && signer="$bt/apksigner"; [ -f "$bt/apksigner.bat" ] && signer="$bt/apksigner.bat"
  if [ -n "$signer" ]; then
    d="$("$signer" verify --print-certs "$final" 2>/dev/null | grep 'Signer #1 certificate SHA-256 digest' | sed 's/.*digest:[[:space:]]*//' | tr -d '\r')"
    [ -n "$d" ] && cert="$d"
  fi
fi
echo "   SHA-256 sertifikat penandatangan: $cert"
echo "   File akhir   : $final"
echo; echo 'BUILD RILIS LOLOS SEMUA PEMERIKSAAN.'
echo 'Pastikan SHA-256 sertifikat sama dengan rilis sebelumnya (keystore yang sama).'
