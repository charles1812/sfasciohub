#!/usr/bin/env bash
# Pubblica build/deploy sul server tramite api/deploy.php (niente File Manager).
#
#   tool/deploy.sh          sito + gestione + api, senza canvaskit (non cambia se non si aggiorna Flutter)
#   tool/deploy.sh --full   anche canvaskit
#
# La chiave sta fuori dal repository, in ~/.sfasciohub/deploy_key (oppure SFASCIOHUB_DEPLOY_KEY).
# Prima esegui tool/build_deploy.sh per creare build/deploy.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
URL="${SFASCIOHUB_DEPLOY_URL:-https://white-ferret-597873.hostingersite.com/sfasciohub/api/deploy.php}"
KEY="${SFASCIOHUB_DEPLOY_KEY:-$(cat "$HOME/.sfasciohub/deploy_key" 2>/dev/null || true)}"
[[ -n "$KEY" ]] || { echo "Manca la chiave: ~/.sfasciohub/deploy_key" >&2; exit 1; }
[[ -d "$ROOT/build/deploy" ]] || { echo "Manca build/deploy: esegui prima tool/build_deploy.sh" >&2; exit 1; }
FULL="${1:-}"
ZIP="$ROOT/build/deploy-package.zip"

python - "$ROOT/build/deploy" "$ZIP" "$FULL" <<'PY'
import os, sys, zipfile
src, out, full = sys.argv[1], sys.argv[2], sys.argv[3] == '--full'
skip = {'api/config.php', 'api/ai_key.php', 'api/admins.php', 'api/deploy_key.php', 'api/deploy.php'}
n = 0
with zipfile.ZipFile(out, 'w', zipfile.ZIP_DEFLATED) as z:
    for r, _, fs in os.walk(src):
        for f in fs:
            p = os.path.join(r, f); rel = os.path.relpath(p, src).replace(os.sep, '/')
            if rel in skip or rel.startswith('uploads/') or rel.endswith('.sqlite') or rel.endswith('.flag'):
                continue
            if not full and '/canvaskit/' in '/' + rel:
                continue
            z.write(p, rel); n += 1
print(f'{n} file, {os.path.getsize(out) // 1024} KB')
PY

curl -sS --fail-with-body -X POST "$URL" -H "X-Deploy-Key: $KEY" -H "Content-Type: application/zip" --data-binary "@$ZIP"
echo
