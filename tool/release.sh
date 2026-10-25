#!/usr/bin/env bash
# Compila le tre app Android e la Gestione per Windows, scrive version.json e pubblica la release su GitHub.
# Le app installate la trovano da sole (controllano version.json dell'ultima release).
# Gli APK vanno anche nella cartella app/ del sito: da lì li scaricano la pagina di download e gli aggiornamenti.
#
#   tool/release.sh "note della versione"
#
# Versione e numero di build si prendono da pubspec.yaml (version: 1.7.0+10).
# Gli APK si firmano con la chiave in ~/.sfasciohub/ (vedi android/app/build.gradle.kts).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
NOTES="${1:?Scrivi le note della versione}"
SITE="${SFASCIOHUB_SITE:-https://white-ferret-597873.hostingersite.com/sfasciohub/}"
REPO="charles1812/sfasciohub"
VER=$(sed -n 's/^version: \([0-9.]*\)+\([0-9]*\).*/\1/p' pubspec.yaml)
BUILD=$(sed -n 's/^version: \([0-9.]*\)+\([0-9]*\).*/\2/p' pubspec.yaml)
[[ -f "$HOME/.sfasciohub/release.properties" ]] || { echo "Manca la chiave di firma in ~/.sfasciohub/" >&2; exit 1; }
D=(--dart-define=API_URL="${SITE}api/" --dart-define=SITE_URL="$SITE")
OUT=build/release
mkdir -p "$OUT"

# Due APK per app: uno per tutti i telefoni (arm e arm64), che usa l'aggiornamento dentro l'app,
# e uno più leggero solo arm64 (quasi tutti i telefoni dal 2017), per la pagina di download sito/app/.
apk() { # flavor, entry point, nome del file senza .apk
  flutter build apk --release --flavor "$1" -t "lib/$2.dart" --target-platform android-arm,android-arm64 "${D[@]}" \
    | grep -q "Built" || { echo "Build $1 non riuscita" >&2; exit 1; }
  cp "build/app/outputs/flutter-apk/app-$1-release.apk" "$OUT/$3.apk"
  flutter build apk --release --flavor "$1" -t "lib/$2.dart" --split-per-abi --target-platform android-arm64 "${D[@]}" \
    | grep -q "Built" || { echo "Build $1 arm64 non riuscita" >&2; exit 1; }
  cp "build/app/outputs/flutter-apk/app-arm64-v8a-$1-release.apk" "$OUT/$3-arm64.apk"
  echo "$1 ok"
}
apk admin main_admin SfascioHub-Admin
apk gestione main_yard SfascioHub-Gestione
apk explore main_explore SfascioHub

flutter build windows --release -t lib/main_yard.dart "${D[@]}" | grep -q "Built" || { echo "Build Windows non riuscita" >&2; exit 1; }
powershell -NoProfile -Command "Compress-Archive -Path 'build/windows/x64/runner/Release/*' -DestinationPath '$OUT/SfascioHub-Gestione-Windows.zip' -Force"
echo "windows ok"

# gli APK si scaricano dal nostro sito (da GitHub su alcuni telefoni il download si blocca al 100%)
bash "$ROOT/tool/upload_apks.sh"
URL="${SITE}app"
python - "$OUT/version.json" "$VER" "$BUILD" "$NOTES" "$URL" <<'PY'
import json, sys
out, ver, build, notes, url = sys.argv[1:]
json.dump({'version': ver, 'build': int(build), 'notes': notes, 'apks': {
    'it.sfasciohub.gestione': f'{url}/SfascioHub-Gestione.apk',
    'it.sfasciohub.esplora': f'{url}/SfascioHub.apk',
    'it.sfasciohub.admin': f'{url}/SfascioHub-Admin.apk',
}}, open(out, 'w', encoding='utf-8'), indent=2, ensure_ascii=False)
PY

gh release create "v$VER" --repo "$REPO" --title "SfascioHub $VER" --notes "$NOTES" \
  "$OUT/SfascioHub.apk" "$OUT/SfascioHub-Gestione.apk" "$OUT/SfascioHub-Admin.apk" \
  "$OUT/SfascioHub-arm64.apk" "$OUT/SfascioHub-Gestione-arm64.apk" "$OUT/SfascioHub-Admin-arm64.apk" \
  "$OUT/SfascioHub-Gestione-Windows.zip" "$OUT/version.json"
curl -sL "https://github.com/$REPO/releases/latest/download/version.json" | grep '"build"'
