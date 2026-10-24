# 🚗 SfascioHub

**Il magazzino online degli sfasciacarrozze.** Chi lavora nel piazzale fotografa l'auto appena arriva,
segna anno, modello e dove è incidentata. Il veicolo compare subito sul sito, e chi cerca un ricambio vede
in quale sfasciacarrozze c'è l'auto giusta e quali parti sono integre.

| | Per chi | Dove |
|---|---|---|
| 🌐 **Sito pubblico** | chi cerca ricambi | **[charles1812.github.io/sfasciohub](https://charles1812.github.io/sfasciohub/)** |
| 📱 **App SfascioHub** (Android) | chi gira per sfasciacarrozze | [Scarica l'APK](https://github.com/charles1812/sfasciohub/releases/latest) |
| 🛠️ **SfascioHub Gestione** | chi lavora nel piazzale | [Android](https://github.com/charles1812/sfasciohub/releases/latest) · [Windows](https://github.com/charles1812/sfasciohub/releases/latest) · [Web](https://charles1812.github.io/sfasciohub/gestione/) |

> **Provala subito:** apri la [gestione web](https://charles1812.github.io/sfasciohub/gestione/), tocca
> **"Entra come sfasciacarrozze di prova"** (`demo@sfasciohub.it` / `demo123`) e aggiungi un veicolo.
> Poi apri il [sito pubblico](https://charles1812.github.io/sfasciohub/) nello stesso browser: lo trovi già lì.

## Cosa fa

**Gestione** (Android, Windows, browser)
- Foto dalla fotocamera o dalla galleria, riordinabili. La prima è la copertina.
- Marca con autocompletamento, modello, versione, anno, alimentazione, km, colore, codice motore.
- **Mappa dei danni**: l'auto vista dall'alto, tocchi le zone incidentate (frontale, fiancate, tetto, vetri, motore, interni…).
- Stato *Disponibile / Riservato / Demolito-venduto* e interruttore "visibile sul sito".
- Anteprima della scheda pubblica, dati del piazzale (indirizzo, orari, telefono, WhatsApp).

**Sito e app pubblica**
- Ricerca per testo (anche per codice motore), marca, provincia e anno.
- Filtro **"Mi serve…"**: mostra solo le auto con quella zona integra (es. *frontale* → fari, cofano, radiatore).
- Scheda veicolo con galleria, mappa dei danni, elenco dei ricambi probabilmente recuperabili.
- Chiama, scrivi su WhatsApp (messaggio già compilato) o apri le indicazioni stradali.
- Elenco degli sfasciacarrozze iscritti, ognuno con la sua pagina e il suo piazzale.

## Architettura

```
                ┌──────────────────────────┐
  Gestione  ──▶ │        Supabase          │ ◀── Sito / app pubblica
 (Flutter:      │  Postgres + Auth + foto  │     (Flutter web e Android,
  Android,      │  Row Level Security:     │      solo lettura)
  Windows, web) │  ognuno scrive solo i    │
                │  propri veicoli          │
                └──────────────────────────┘
```

- **Un solo codice Flutter**, due app: `lib/main_explore.dart` (pubblica) e `lib/main_yard.dart` (gestione).
  Su Android sono due flavor installabili insieme: `it.sfasciohub.esplora` e `it.sfasciohub.gestione`.
- **Piattaforma multi-sfasciacarrozze**: chiunque si iscrive crea il proprio piazzale. Le regole di accesso
  sono nel database ([`supabase/schema.sql`](supabase/schema.sql)), non nell'app.
- **Modalità demo**: senza chiavi Supabase le app usano dati di esempio salvati sul dispositivo. Nel browser
  sito e gestione condividono gli stessi dati, così si prova il giro completo.

```
lib/
  data/        modelli, Repository (interfaccia), Supabase e demo
  ui/explore/  sito e app pubblica
  ui/yard/     app di gestione
  ui/widgets/  mappa dei danni, card, contatti
supabase/      schema del database e regole di sicurezza
```

## Collegare Supabase (piattaforma vera)

1. Crea un progetto gratuito su [supabase.com](https://supabase.com).
2. **SQL Editor** → incolla [`supabase/schema.sql`](supabase/schema.sql) → **Run**.
3. **Project Settings → API**: copia *Project URL* e la chiave *anon / publishable*.
4. Compila passando le chiavi:

```bash
flutter build web -t lib/main_explore.dart --base-href /sfasciohub/ \
  --dart-define=SUPABASE_URL=https://xxxx.supabase.co --dart-define=SUPABASE_ANON_KEY=...
```

La chiave *anon* è pubblica per costruzione: la sicurezza la fanno le policy RLS dello schema.

## Compilare

```bash
flutter pub get
# Android
flutter build apk --release --flavor explore  -t lib/main_explore.dart
flutter build apk --release --flavor gestione -t lib/main_yard.dart
# Windows (gestione)
flutter build windows --release -t lib/main_yard.dart
# Web: sito alla radice, gestione in /gestione/
flutter build web -t lib/main_explore.dart --base-href /sfasciohub/ -o build/site
flutter build web -t lib/main_yard.dart --base-href /sfasciohub/gestione/ -o build/site_gestione
```

---

Un progetto di **Charles** · [@charles1812](https://github.com/charles1812)
