# 🚗 SfascioHub

**Il magazzino online degli sfasciacarrozze.** Chi lavora nel piazzale fotografa l'auto appena arriva,
segna anno, modello e dove è incidentata. Il veicolo compare subito sul sito, e chi cerca un ricambio vede
in quale sfasciacarrozze c'è l'auto giusta e quali parti sono integre.

| | Per chi | Dove |
|---|---|---|
| 🌐 **Sito pubblico** | chi cerca ricambi | **[white-ferret-597873.hostingersite.com/sfasciohub/](https://white-ferret-597873.hostingersite.com/sfasciohub/)** |
| 📱 **App SfascioHub** (Android) | chi gira per sfasciacarrozze | [Scarica l'APK](https://github.com/charles1812/sfasciohub/releases/latest) |
| 🛠️ **SfascioHub Gestione** | chi lavora nel piazzale | [Android](https://github.com/charles1812/sfasciohub/releases/latest) · [Windows](https://github.com/charles1812/sfasciohub/releases/latest) · [Web](https://white-ferret-597873.hostingersite.com/sfasciohub/gestione/) |
| 🛡️ **SfascioHub Admin** (Android) | chi gestisce la piattaforma | [Scarica l'APK](apk/) |

> **Provala subito:** apri la [gestione web](https://white-ferret-597873.hostingersite.com/sfasciohub/gestione/) (o l'app Gestione), tocca
> **"Entra come sfasciacarrozze di prova"** (`demo@sfasciohub.it` / `demo1234`) e aggiungi un veicolo con le foto.
> Compare subito sul [sito pubblico](https://white-ferret-597873.hostingersite.com/sfasciohub/) e nell'app SfascioHub, da qualsiasi dispositivo.
>
> Gira su un server PHP + MySQL proprio (Hostinger). Su [GitHub Pages](https://charles1812.github.io/sfasciohub/) resta una
> versione demo offline, con dati salvati solo nel browser.

## Cosa fa

**Gestione** (Android, Windows, browser)
- Foto dalla fotocamera o dalla galleria, riordinabili. La prima è la copertina.
- Marca con autocompletamento, modello, versione, anno, alimentazione, km, colore, codice motore.
- **Mappa dei danni**: l'auto vista dall'alto, tocchi le zone incidentate (frontale, fiancate, tetto, vetri, motore, interni…).
- Stato *Disponibile / Riservato / Demolito-venduto* e interruttore "visibile sul sito".
- **Compila dalle foto (AI)**: Claude Haiku guarda le foto e riempie marca, modello, anno, alimentazione, colore e zone danneggiate. Si controlla e si salva.
- **Aggiornamenti dall'app** (Android): quando esce una versione nuova compare la barra *Aggiorna*, che scarica e installa l'APK.
- Anteprima della scheda pubblica, dati del piazzale (indirizzo, orari, telefono, WhatsApp).

**Sito e app pubblica**
- Ricerca per testo (anche per codice motore), marca, provincia e anno.
- Filtro **"Mi serve…"**: mostra solo le auto con quella zona integra (es. *frontale* → fari, cofano, radiatore).
- Scheda veicolo con galleria, mappa dei danni, elenco dei ricambi probabilmente recuperabili.
- Chiama, scrivi su WhatsApp (messaggio già compilato) o apri le indicazioni stradali.
- Elenco degli sfasciacarrozze iscritti, ognuno con la sua pagina e il suo piazzale.

> 📱 **Tutte le app Android**: cartella [`apk/`](apk/) · 🗺️ **Piano della piattaforma**: [`docs/PIANO.md`](docs/PIANO.md)

## Architettura

```
                ┌──────────────────────────────┐
  Gestione  ──▶ │   Server PHP (es. Hostinger) │ ◀── Sito / app pubblica
 (Flutter:      │   api/  → API REST in PHP    │     (Flutter web e Android,
  Android,      │   MySQL → veicoli, account   │      solo lettura)
  Windows, web) │   uploads/ → foto            │
                └──────────────────────────────┘
```

- **Un solo codice Flutter**, due app: `lib/main_explore.dart` (pubblica) e `lib/main_yard.dart` (gestione).
  Su Android sono due flavor installabili insieme: `it.sfasciohub.esplora` e `it.sfasciohub.gestione`.
- **Backend tuo**: [`server/api/`](server/api/) è PHP puro (8.1+), senza framework né Composer. Database MySQL/MariaDB,
  password bcrypt, token di sessione, query preparate, foto controllate (solo JPEG/PNG/WebP) e niente PHP eseguibile in `uploads/`.
- **Piattaforma multi-sfasciacarrozze**: chiunque si iscrive crea il proprio piazzale e può modificare solo i propri veicoli
  (il controllo è sul server).
- **Modalità demo**: compilata senza `API_URL`, l'app usa dati di esempio sul dispositivo (è la versione su GitHub Pages).

```
lib/
  data/        modelli, Repository, PhpRepository (server) e DemoRepository
  ui/explore/  sito e app pubblica
  ui/yard/     app di gestione
server/
  api/         index.php (rotte), install.php (installazione guidata), lib/
  uploads/     foto (protetta da .htaccess)
tool/build_deploy.sh   crea il pacchetto da caricare sul server
```

## Mettere online sul tuo server (Hostinger o qualsiasi hosting PHP)

1. **hPanel → Database → MySQL**: crea un database e un utente (annota nome, utente e password).
2. Crea il pacchetto: `tool/build_deploy.sh /` (o `/sfasciohub/` se va in una sottocartella).
   Esce `build/sfasciohub-server.zip`.
3. **File Manager**: carica lo zip in `public_html` (o nella sottocartella) ed estrailo.
4. Apri `https://tuodominio.it/api/install.php`, inserisci i dati del database → **Installa**.
   La pagina crea le tabelle, salva `api/config.php` e poi si blocca.
5. Fatto: sito pubblico alla radice, gestione in `/gestione/`.
6. *(facoltativo)* Riconoscimento dalle foto: crea una chiave su [platform.claude.com](https://platform.claude.com) e salvala in
   `api/ai_key.php` (vedi `api/ai_key.example.php`). Costa circa 0,1 centesimi per auto; massimo 40 analisi al giorno per piazzale.

> Il File Manager di Hostinger, estraendo uno zip, **non sovrascrive** i file già presenti: per un aggiornamento
> cancella prima i vecchi `api/index.php` e `api/lib/`, oppure caricali singolarmente.

Per le app Android/Windows collegate al server:

```bash
flutter build apk --release --flavor gestione -t lib/main_yard.dart   --dart-define=API_URL=https://tuodominio.it/api/ --dart-define=SITE_URL=https://tuodominio.it/
```

### API

Tutte le rotte passano da `api/index.php?r=…` (funziona anche senza riscrittura URL).

| Metodo | Rotta | |
|---|---|---|
| GET | `/vehicles` `?make=&province=&year_from=&year_to=&yard_id=` | veicoli pubblicati |
| GET | `/vehicles/{id}` · `/yards` · `/yards/{id}` · `/counts` | pubblico |
| POST | `/auth/signup` · `/auth/login` · `/auth/logout`, GET `/auth/me` | account (token `Bearer`) |
| GET/POST/PUT | `/me/yard` | il mio sfasciacarrozze |
| GET | `/me/vehicles` · PUT/DELETE `/me/vehicles/{id}` | i miei veicoli |
| POST | `/me/vehicles/{id}/photos?position=` (corpo = immagine) · DELETE `/me/photos/{id}` | foto |
| GET | `/me/ai` · POST `/me/ai/analyze` `{images: [base64], photo_ids: []}` | riconoscimento dalle foto |

## Compilare

```bash
flutter pub get
flutter build apk --release --flavor explore  -t lib/main_explore.dart   # + --dart-define=API_URL=…
flutter build apk --release --flavor gestione -t lib/main_yard.dart
flutter build windows --release -t lib/main_yard.dart
tool/build_deploy.sh /                                                   # sito + gestione + API
```

Test del backend in locale (SQLite invece di MySQL): `php server/api/install.php --sqlite=server/api/test.sqlite --demo`
e poi `php -S 127.0.0.1:8088 -t server`.

---

Un progetto di **Charles** · [@charles1812](https://github.com/charles1812)
