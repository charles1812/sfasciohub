#!/usr/bin/env bash
# Copia di sicurezza del server sul PC: database (SQL compresso) e foto.
#
#   tool/backup.sh [cartella]     di default C:\Users\<te>\SfascioHub-Backup
#
#   <cartella>/db/sfasciohub-AAAA-MM-GG.sql.gz   un file al giorno, tiene gli ultimi 30
#   <cartella>/uploads/                          le foto (scarica solo quelle nuove)
#
# Il database si ripristina importando il .sql (decompresso) da phpMyAdmin su Hostinger.
# Le foto arrivano da api/backup.php e non dall'indirizzo pubblico, che il CDN ricomprime.
# Usa la stessa chiave di tool/deploy.sh (~/.sfasciohub/deploy_key). Gira da solo ogni giorno
# con l'attività pianificata "SfascioHub backup" (vedi tool/backup_schedule.ps1).
set -euo pipefail
SITE="${SFASCIOHUB_SITE:-https://white-ferret-597873.hostingersite.com/sfasciohub}"
KEY="${SFASCIOHUB_DEPLOY_KEY:-$(cat "$HOME/.sfasciohub/deploy_key" 2>/dev/null || true)}"
[[ -n "$KEY" ]] || { echo "Manca la chiave: ~/.sfasciohub/deploy_key" >&2; exit 1; }
OUT="${1:-$HOME/SfascioHub-Backup}"
mkdir -p "$OUT/db" "$OUT/uploads"
LOG="$OUT/backup.log"
day=$(date +%F)

db="$OUT/db/sfasciohub-$day.sql.gz"
curl -sS --fail -H "X-Deploy-Key: $KEY" "$SITE/api/backup.php?what=db" -o "$db.part"
gzip -t "$db.part" && mv "$db.part" "$db"
ls -1t "$OUT"/db/sfasciohub-*.sql.gz | tail -n +31 | while read -r old; do rm -f -- "$old"; done

list=$(curl -sS --fail -H "X-Deploy-Key: $KEY" "$SITE/api/backup.php?what=uploads")
new=0
while IFS=$'\t' read -r file size; do
  size=${size//[^0-9]/}   # python su Windows chiude le righe con 
  [[ -z "$file" || "$file" == *..* ]] && continue
  dest="$OUT/uploads/$file"
  if [[ ! -f "$dest" || $(stat -c %s "$dest") != "$size" ]]; then
    mkdir -p "$(dirname "$dest")"
    curl -sS --fail -H "X-Deploy-Key: $KEY" -G "$SITE/api/backup.php" --data-urlencode "what=file" --data-urlencode "f=$file" -o "$dest.part" && mv "$dest.part" "$dest" && new=$((new + 1))
  fi
done < <(python -c "import json,sys; [print(f['file'], f['size'], sep='\t') for f in json.load(sys.stdin)['files']]" <<<"$list")

msg="$(date '+%F %T')  database $(( $(stat -c %s "$db") / 1024 )) KB · $new foto nuove · $(find "$OUT/uploads" -type f | wc -l) foto in tutto"
echo "$msg" | tee -a "$LOG"
