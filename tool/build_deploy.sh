#!/usr/bin/env bash
# Crea build/deploy/ e build/sfasciohub-server.zip: tutto ciò che va caricato sul server PHP.
#
#   tool/build_deploy.sh [percorso] [indirizzo-pubblico]
#
#   percorso            dove sarà il sito sul server, es. "/" (radice del dominio) o "/sfasciohub/"
#   indirizzo-pubblico  es. https://tuodominio.it/sfasciohub/  (serve per i link condivisi)
#
# Struttura sul server:
#   index.html …   sito pubblico (Esplora)
#   gestione/      app di gestione web
#   api/           API PHP (apri api/install.php una volta per collegare il database)
#   uploads/       foto dei veicoli
set -euo pipefail
export MSYS_NO_PATHCONV=1

BASE="${1:-/}"
SITE="${2:-}"
[[ "$BASE" == /* ]] || BASE="/$BASE"
[[ "$BASE" == */ ]] || BASE="$BASE/"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/build/deploy"
DEMO="${DEMO_LOGIN:-true}"

cd "$ROOT"
defines=(--dart-define=DEMO_LOGIN="$DEMO")
[[ -n "$SITE" ]] && defines+=(--dart-define=SITE_URL="$SITE")

flutter build web -t lib/main_explore.dart --base-href "$BASE" -o build/web_explore \
  --dart-define=API_URL=api/ ${SITE:+} "${defines[@]}"
flutter build web -t lib/main_yard.dart --base-href "${BASE}gestione/" -o build/web_gestione \
  --dart-define=API_URL=../api/ "${defines[@]}"

rm -rf "$OUT"
mkdir -p "$OUT"
cp -r build/web_explore/. "$OUT/"
mkdir -p "$OUT/gestione"
cp -r build/web_gestione/. "$OUT/gestione/"
sed -i 's#<title>SfascioHub · Ricambi usati dagli sfasciacarrozze</title>#<title>SfascioHub Gestione</title>#' "$OUT/gestione/index.html"

# API e cartella foto, senza configurazioni o database locali
mkdir -p "$OUT/api" "$OUT/uploads"
cp -r server/api/. "$OUT/api/"
rm -f "$OUT/api/config.php" "$OUT/api/ai_key.php" "$OUT"/api/*.sqlite "$OUT"/api/*.bak
cp server/uploads/.htaccess "$OUT/uploads/"

# Sito: niente elenco dei file, cache lunga per gli asset
cat > "$OUT/.htaccess" <<'EOF'
Options -Indexes
DirectoryIndex index.html index.php
<IfModule mod_headers.c>
  <FilesMatch "\.(js|wasm|otf|ttf|png|jpg|webp|json)$">
    Header set Cache-Control "public, max-age=604800"
  </FilesMatch>
  <FilesMatch "(index\.html|flutter_service_worker\.js|version\.json)$">
    Header set Cache-Control "no-cache"
  </FilesMatch>
</IfModule>
EOF

rm -f build/sfasciohub-server.zip
(cd "$OUT" && powershell -NoProfile -Command "Compress-Archive -Path * -DestinationPath '../sfasciohub-server.zip' -Force" 2>/dev/null \
  || zip -qr ../sfasciohub-server.zip .)
echo "Pronto: $OUT  ·  build/sfasciohub-server.zip"
