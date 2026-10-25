#!/usr/bin/env bash
# Carica gli APK di build/release nella cartella app/ del sito (api/apk_upload.php), a pezzi da 4 MB.
#
#   tool/upload_apks.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SITE="${SFASCIOHUB_SITE:-https://white-ferret-597873.hostingersite.com/sfasciohub}"
KEY="${SFASCIOHUB_DEPLOY_KEY:-$(cat "$HOME/.sfasciohub/deploy_key" 2>/dev/null || true)}"
[[ -n "$KEY" ]] || { echo "Manca la chiave: ~/.sfasciohub/deploy_key" >&2; exit 1; }
CHUNK=$((4 * 1024 * 1024))
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

for name in SfascioHub SfascioHub-Gestione SfascioHub-Admin SfascioHub-arm64 SfascioHub-Gestione-arm64 SfascioHub-Admin-arm64; do
  f="$ROOT/build/release/$name.apk"
  [[ -f "$f" ]] || { echo "Manca $f" >&2; exit 1; }
  size=$(stat -c %s "$f")
  sha=$(sha256sum "$f" | cut -c1-64)
  parts=$(( (size + CHUNK - 1) / CHUNK ))
  for ((i = 0; i < parts; i++)); do
    dd if="$f" of="$TMP/part" bs=$CHUNK skip=$i count=1 status=none
    last=$(( i == parts - 1 ? 1 : 0 ))
    out=$(curl -sS --fail-with-body --retry 3 -X POST -H "X-Deploy-Key: $KEY" -H "Content-Type: application/octet-stream" \
      --data-binary "@$TMP/part" "$SITE/api/apk_upload.php?name=$name.apk&part=$i&last=$last&size=$size&sha256=$sha")
  done
  echo "$name.apk  $((size / 1024 / 1024)) MB  $out"
done
