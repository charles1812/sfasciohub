# SfascioHub · piano della piattaforma

Obiettivo: una piattaforma distribuibile a più sfasciacarrozze (si parte da una decina), con un lato **business**
(il piazzale carica le auto) e un lato **clienti** (chi cerca un ricambio lo trova). Tu, come gestore, crei gli account,
controlli i costi e decidi i limiti.

## 1. Le tre app

| | Per chi | Cosa fa | Dove |
|---|---|---|---|
| **A · Admin** | tu | crea account e piazzali, blocca chi non paga, vede costi AI per account, imposta i limiti | Android (`it.sfasciohub.admin`) |
| **B · Gestione** | sfasciacarrozze | foto → AI compila la scheda → pubblica; lista pezzi | Android, Windows, web `/gestione/` |
| **C · SfascioHub** | clienti | cerca auto e pezzi, chiama o scrive su WhatsApp al piazzale | Android, web `/` |

Tutte e tre leggono lo stesso server (PHP + MySQL su Hostinger) e si aggiornano dall'app (barra **Aggiorna**).

```
   A · Admin ─┐                      ┌──────────────────────────────┐
   B · Gestione ─┼──── HTTPS ──────▶ │ Server PHP + MySQL (Hostinger)│ ──▶ Claude API (Haiku)
   C · Clienti ─┘                      │ api/  · uploads/ (foto)       │     la chiave sta solo qui
                                       └──────────────────────────────┘
   aggiornamenti app: GitHub Releases (version.json + APK)
```

## 2. Gli agenti AI

### 2.1 Riconoscimento dalle foto (fatto)
Le foto vanno a Claude Haiku tramite il server, che restituisce marca, modello, anno, alimentazione, colore, zone danneggiate e una nota.
**Costo misurato: ~0,0009 $ ad analisi** (4–5 foto). 1 € ≈ 1.000 auto.

### 2.2 Lista dei pezzi probabilmente sani (prossimo)
Non serve un catalogo da migliaia di righe. Uno sfasciacarrozze non vende le viti: vende **circa 150–250 ricambi**
(fari, paraurti, portiere, specchietti, centraline, motore, cambio, alternatore, airbag, sedili, cerchi…).

Come funziona:
1. **Elenco base dei ricambi vendibili**, scritto una volta sola e diviso per zona dell'auto (frontale, fiancata sx, motore,
   interni…). È la stessa mappa dei danni che c'è già.
2. Per ogni auto l'agente parte da quell'elenco e lo **adatta al modello**: per una Peugeot 208 II serie sa, per esempio,
   che ci sono versioni con fari full LED o alogeni, e sa quali parti hanno l'elettrico e quali no.
   Poi segna ogni pezzo come **probabilmente sano / danneggiato / da verificare**, guardando le zone danneggiate e le foto.
3. Il piazzale conferma o corregge con un tocco (✓ / ✗). Il dato confermato vale più di quello stimato.
4. Lato clienti si cerca per pezzo: *"faro anteriore sinistro Peugeot 208 2019"* → elenco dei piazzali che ce l'hanno.

Più avanti, per i **codici OE/ricambio esatti** servirebbe un catalogo professionale (es. TecDoc, a pagamento).
Va valutato solo quando la piattaforma funziona.

**Costo stimato**: con Haiku ~0,002 $ per auto (circa 3.000 token di risposta per 150 pezzi).

### 2.3 Agente "trova il pezzo" per i clienti (prossimo)
Il cliente scrive come parlerebbe al banco: *"mi serve il cofano di una Punto Evo grigia"*. L'agente usa degli strumenti sul
nostro database (cerca auto, filtra per zona integra, per pezzo, per provincia) e risponde con le auto giuste, dove sono e
il pulsante per chiamare. Ogni domanda richiede 2–3 passaggi del modello.

**Costo stimato**: ~0,001–0,002 $ a domanda con Haiku. Essendo pubblico, va limitato per indirizzo (es. 20 domande al giorno)
e con un tetto giornaliero totale, così nessuno può farti spendere.

### 2.4 Più precisione: quanto cambia il costo

| | Haiku 5.5 (ora) | Sonnet 5.5 (più preciso) |
|---|---|---|
| prezzo per milione di token, entrata / uscita | 0,10 $ / 0,50 $ | 2 $ / 10 $ |
| analisi foto | ~0,0009 $ | ~0,018 $ |
| lista pezzi | ~0,002 $ | ~0,04 $ |
| **per auto, totale** | **~0,003 $** | **~0,06 $** |
| 10 piazzali × 110 auto al mese | **~3,3 $/mese** | **~66 $/mese** |

Proposta: Haiku di default, e un pulsante **"Riprova con più precisione"** (Sonnet) solo quando l'auto è rara o Haiku
è poco sicuro. Così il costo resta quello di Haiku, salvo poche eccezioni. L'Admin mostra la spesa per account, quindi
si può decidere quanto far pagare l'abbonamento.

## 3. Gestione (app Admin) — in questa versione
- **Panoramica**: piazzali, account, veicoli, analisi AI e spesa di oggi, del mese e totale.
- **Account**: crei un account per un piazzale (email e nome; la password la genera l'app e la mandi tu),
  reimposti la password, blocchi o sblocchi l'accesso, nomini un altro admin.
- **Piazzali**: veicoli, spesa AI del mese e totale, limite di analisi al giorno, visibile o nascosto sul sito.
- Chi è admin: l'email scritta in `api/admins.php` sul server, oppure chi viene promosso dall'app.

## 4. Cosa serve per distribuire a 10 sfasciacarrozze
1. **Firma delle app**: oggi gli APK sono firmati con una chiave di prova. Prima di darli ai clienti va creata una chiave
   definitiva e conservata con cura. Si fa **una volta**: chi ha già installato deve reinstallare una sola volta, poi
   gli aggiornamenti continuano dall'app. Senza quella chiave non si possono più pubblicare aggiornamenti.
2. **Privacy e condizioni d'uso**: informativa GDPR (email degli account, foto, telefono del piazzale) e condizioni
   per i piazzali. Nelle foto vanno oscurate le targhe: si può far fare all'AI.
3. **Dominio vero** (es. sfasciohub.it) al posto di `white-ferret-597873.hostingersite.com`.
4. **Backup** giornaliero del database e della cartella `uploads/` (hPanel → Backup).

## 5. Quando il server va ingrandito
Hostinger condiviso basta per 10 piazzali. Il primo limite saranno le **foto**: ~4–5 MB per auto, quindi 1.000 auto
≈ 5 GB. Il percorso di crescita:
1. VPS (Hostinger o simile) con lo stesso PHP + MySQL: si sposta copiando i file e il database.
2. Foto su object storage con CDN (Cloudflare R2 / S3): costa poco ed è veloce ovunque.
3. Play Store per B e C, quando ci sono clienti veri (25 $ una tantum); A resta fuori dallo store.

## 6. Ordine di lavoro proposto
1. ✅ Riconoscimento dalle foto, aggiornamenti dall'app.
2. ✅ App Admin: account, piazzali, costi per account (questa versione).
3. Lista pezzi (agente 2.2) e conferma ✓/✗ nella Gestione; ricerca per pezzo nel lato clienti.
4. Agente "trova il pezzo" (2.3) nel lato clienti, con i limiti di spesa.
5. Chiave di firma definitiva, dominio, privacy → consegna ai primi piazzali.
6. Abbonamenti (quanto far pagare, in base ai costi che l'Admin mostra).
