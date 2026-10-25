<?php
// Stato del server e lista delle cose che mancano per pubblicare la piattaforma (app Admin, scheda Server).
declare(strict_types=1);

function setting(string $key, ?string $default = null): ?string
{
    $st = db()->prepare('SELECT v FROM settings WHERE k = ?');
    $st->execute([$key]);
    $v = $st->fetchColumn();
    return $v === false ? $default : (string) $v;
}

function set_setting(string $key, ?string $value): void
{
    db()->prepare('DELETE FROM settings WHERE k = ?')->execute([$key]);
    if ($value !== null) {
        db()->prepare('INSERT INTO settings (k, v) VALUES (?, ?)')->execute([$key, $value]);
    }
}

function dir_usage(string $dir): array
{
    $n = 0;
    $bytes = 0;
    if (is_dir($dir)) {
        $it = new RecursiveIteratorIterator(new RecursiveDirectoryIterator($dir, FilesystemIterator::SKIP_DOTS));
        foreach ($it as $f) {
            if ($f->isFile() && !str_starts_with($f->getFilename(), '.')) {
                $n++;
                $bytes += $f->getSize();
            }
        }
    }
    return ['files' => $n, 'bytes' => $bytes];
}

function ini_bytes(string $v): int
{
    $v = trim($v);
    $n = (int) $v;
    return match (strtolower(substr($v, -1))) { 'g' => $n << 30, 'm' => $n << 20, 'k' => $n << 10, default => $n };
}

/** Cose da fare prima di pubblicare: quelle verificabili si controllano da sole, le altre le spunti tu. */
const LAUNCH_MANUAL = [
    ['privacy', 'Privacy policy e cookie', 'legale',
        "Serve perché il sito conta le visite e salva telefoni e indirizzi dei piazzali. Il modo più rapido: iubenda.com (circa 30 €/anno) genera privacy e cookie policy in italiano; scegli \"sito web e app\", servizi usati: hosting Hostinger, Anthropic (analisi foto), statistiche interne. Poi mandami i link e li metto nel sito, nella Gestione e nelle app."],
    ['terms', 'Termini di servizio', 'legale',
        "Due testi brevi: per i piazzali (cosa offre SfascioHub, prezzi, che il venditore dei ricambi è il piazzale e non tu) e per i clienti (le informazioni sulle auto le mette il piazzale, i pezzi si comprano da lui). Anche questi si fanno con iubenda o con un avvocato. Mandameli e li collego."],
    ['dpa', 'Accordo dati con ogni piazzale (DPA)', 'legale',
        "Tratti dati per conto dei piazzali (le loro auto, i contatti dei clienti): serve una nomina a responsabile del trattamento firmata da ognuno. iubenda e molti studi hanno un modello; si firma insieme al contratto quando entra un piazzale."],
    ['vat', 'Partita IVA o società', 'azienda',
        "Per far pagare i piazzali e fatturare. Parlane con un commercialista: per iniziare spesso basta una partita IVA in regime forfettario. Serve anche per Stripe e per il Play Store a nome dell'attività."],
    ['playstore', 'App sul Play Store', 'distribuzione',
        "1) play.google.com/console → crea l'account sviluppatore (25 \$ una volta, serve un documento). 2) Crea le app \"SfascioHub\" e \"SfascioHub Gestione\". 3) Per gli account nuovi Google chiede un test chiuso con almeno 12 persone per 14 giorni (bastano amici e piazzali con un indirizzo Gmail). 4) Dimmi quando l'account è pronto: preparo io i pacchetti AAB, le schede, le schermate e la scheda sulla sicurezza dei dati."],
    ['appstore', 'App per iPhone (App Store)', 'distribuzione',
        "Facoltativo all'inizio: su iPhone il sito funziona già. Per l'app vera servono un account Apple Developer (99 \$/anno) e un Mac per compilarla (anche un Mac mini usato, o un servizio cloud come Codemagic). Quando vuoi farlo te lo preparo."],
    ['stripe', 'Pagamenti e abbonamenti', 'azienda',
        "Quando decidi i prezzi: crea un account su stripe.com (serve la partita IVA), poi dimmi i piani (es. gratis fino a 20 auto, poi X €/mese) e aggiungo abbonamento, limiti per piano e blocco automatico se non pagano."],
    ['pilot', 'Primi piazzali (zona pilota)', 'mercato',
        "Prima di aprire ai clienti servono auto vere: scegli una provincia, convinci di persona 5–10 piazzali e aiutali a caricare le prime auto. Poi promuovi il sito ai clienti solo in quella zona."],
];

function launch_checklist(array $s): array
{
    $temporary = str_ends_with($s['host'], '.hostingersite.com');
    $lastBackup = $s['last_backup'];
    $backupAge = $lastBackup ? (time() - strtotime($lastBackup . ' UTC')) / 86400 : null;
    $auto = [
        ['https', 'Sito in HTTPS', 'tecnico', $s['https'] ? 'done' : 'todo',
            'In hPanel → Sicurezza → SSL attiva il certificato gratuito.'],
        ['domain', 'Dominio vero', 'tecnico', $temporary ? 'todo' : 'done',
            $temporary
                ? "Il sito usa ancora l'indirizzo provvisorio {$s['host']}. In hPanel → Domini compra il dominio (es. sfasciohub.it, circa 10 €/anno) e collegalo a questo sito. Poi dimmi il nome: aggiorno io gli indirizzi nelle app e pubblico una versione nuova. Va fatto prima di distribuire, perché l'indirizzo è scritto dentro le app."
                : 'Il sito usa ' . $s['host'] . '.'],
        ['mail', 'Email che non finiscono nello spam', 'tecnico', $temporary ? 'todo' : (!empty(config()['mail_from']) ? 'done' : 'warn'),
            "Le email (conferma, nuova password, nuovi piazzali) oggi partono da {$s['mail_from']} e Gmail le mette nello spam. Dopo il dominio: hPanel → Email → crea la casella noreply@tuodominio (Hostinger imposta da solo SPF e DKIM). Dimmelo e imposto il mittente."],
        ['backup', 'Backup giornaliero', 'tecnico',
            $backupAge === null ? 'todo' : ($backupAge <= 2 ? 'done' : 'warn'),
            ($lastBackup ? "Ultimo backup: $lastBackup UTC. " : 'Nessun backup ancora. ')
            . "Per farlo partire da solo ogni giorno, sul PC apri PowerShell e lancia: & \"C:\\Users\\charl\\Progetti\\sfasciohub\\tool\\backup_schedule.ps1\". I file finiscono in C:\\Users\\charl\\SfascioHub-Backup."],
        ['ai', 'Chiave AI per le foto', 'tecnico', $s['ai_key'] ? 'done' : 'todo',
            "Senza chiave l'analisi delle foto e la lista ricambi non funzionano. Si crea su console.anthropic.com e va nel file api/ai_key.php sul server."],
        ['signing', 'Firma definitiva delle app Android', 'tecnico', 'done',
            'Fatto dalla versione 1.7.0. La chiave è in C:\\Users\\charl\\.sfasciohub\\ (release.jks e release.properties): copiala su una chiavetta, senza quella non si possono più aggiornare le app.'],
        ['errors', 'Errori da controllare', 'tecnico', $s['errors_open'] > 0 ? 'warn' : 'done',
            $s['errors_open'] > 0 ? "{$s['errors_open']} errori nella scheda Errori: guardali o segnali come risolti." : 'Nessun errore aperto.'],
        ['yards', 'Piazzali da approvare', 'mercato', $s['yards_pending'] > 0 ? 'warn' : 'done',
            $s['yards_pending'] > 0 ? "{$s['yards_pending']} piazzali aspettano: scheda Piazzali." : 'Nessuno in attesa.'],
    ];
    $done = json_decode(setting('launch_done', '{}') ?? '{}', true) ?: [];
    $out = [];
    foreach ($auto as [$id, $title, $group, $status, $how]) {
        $out[] = ['id' => $id, 'title' => $title, 'group' => $group, 'status' => $status, 'how' => $how, 'auto' => true];
    }
    foreach (LAUNCH_MANUAL as [$id, $title, $group, $how]) {
        $out[] = ['id' => $id, 'title' => $title, 'group' => $group, 'status' => !empty($done[$id]) ? 'done' : 'todo', 'how' => $how, 'auto' => false];
    }
    return $out;
}

/** GET /admin/server */
function admin_server(): array
{
    require_admin();
    $pdo = db();
    $sqlite = is_sqlite();
    $dbVersion = $sqlite ? 'SQLite ' . $pdo->query('SELECT sqlite_version()')->fetchColumn() : (string) $pdo->query('SELECT VERSION()')->fetchColumn();
    $dbBytes = 0;
    $tables = [];
    if ($sqlite) {
        $dbBytes = (int) @filesize(config()['db']['path']);
        foreach ($pdo->query("SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%'")->fetchAll(PDO::FETCH_COLUMN) as $t) {
            $tables[] = ['name' => $t, 'rows' => (int) $pdo->query("SELECT COUNT(*) FROM `$t`")->fetchColumn(), 'bytes' => null];
        }
    } else {
        foreach ($pdo->query('SELECT table_name n, table_rows r, data_length + index_length b FROM information_schema.tables
                              WHERE table_schema = DATABASE() ORDER BY b DESC')->fetchAll() as $t) {
            $tables[] = ['name' => $t['n'], 'rows' => (int) $pdo->query("SELECT COUNT(*) FROM `{$t['n']}`")->fetchColumn(), 'bytes' => (int) $t['b']];
            $dbBytes += (int) $t['b'];
        }
    }
    $root = realpath(__DIR__ . '/../..');
    $uploads = dir_usage("$root/uploads");
    $free = @disk_free_space($root);
    $total = @disk_total_space($root);
    $deploys = glob(__DIR__ . '/../deploy_backups/2*', GLOB_ONLYDIR) ?: [];
    rsort($deploys);
    $lastDeploy = $deploys ? preg_replace('/^(\d{4})(\d\d)(\d\d)-(\d\d)(\d\d)(\d\d)$/', '$1-$2-$3 $4:$5:$6', basename($deploys[0])) : null;
    $host = preg_replace('/:\d+$/', '', $_SERVER['HTTP_HOST'] ?? 'localhost');
    $one = fn(string $sql) => (int) $pdo->query($sql)->fetchColumn();

    $s = [
        'host' => $host,
        'https' => !empty($_SERVER['HTTPS']) || ($_SERVER['HTTP_X_FORWARDED_PROTO'] ?? '') === 'https',
        'php' => PHP_VERSION,
        'server_software' => (string) ($_SERVER['SERVER_SOFTWARE'] ?? ''),
        'database' => $dbVersion,
        'db_bytes' => $dbBytes,
        'tables' => $tables,
        'schema_version' => SCHEMA_VERSION,
        'uploads' => $uploads,
        'disk_free_bytes' => $free === false ? null : (int) $free,
        'disk_total_bytes' => $total === false ? null : (int) $total,
        'limits' => [
            'upload_max' => ini_bytes((string) ini_get('upload_max_filesize')),
            'post_max' => ini_bytes((string) ini_get('post_max_size')),
            'memory' => (string) ini_get('memory_limit'),
            'max_execution_seconds' => (int) ini_get('max_execution_time'),
        ],
        'extensions' => array_values(array_filter(['curl', 'gd', 'zip', 'mbstring', 'openssl', 'pdo_mysql', 'fileinfo', 'zlib'], 'extension_loaded')),
        'missing_extensions' => array_values(array_filter(['curl', 'zip', 'mbstring', 'openssl', 'fileinfo', 'zlib'], fn($e) => !extension_loaded($e))),
        'ai_key' => function_exists('ai_key') && ai_key() !== '',
        'mail_from' => (string) (config()['mail_from'] ?? "noreply@$host"),
        'last_deploy' => $lastDeploy,
        'last_backup' => setting('last_backup'),
        'sessions_active' => $pdo->query("SELECT COUNT(*) FROM auth_tokens WHERE expires_at > '" . now() . "'")->fetchColumn() + 0,
        'errors_open' => $one('SELECT COUNT(*) FROM app_errors'),
        'errors_24h' => (int) ($pdo->query("SELECT COALESCE(SUM(count), 0) FROM app_errors WHERE last_at >= '" . gmdate('Y-m-d H:i:s', time() - 86400) . "'")->fetchColumn()),
        'yards_pending' => $one('SELECT COUNT(*) FROM yards WHERE approved = 0'),
        'users_unverified' => $one('SELECT COUNT(*) FROM users WHERE email_verified = 0'),
        'server_time' => now(),
    ];
    $s['checklist'] = launch_checklist($s);
    return $s;
}

/** PUT /admin/checklist/{id}   {"done": true}  (solo le voci da spuntare a mano) */
function admin_checklist(string $id): array
{
    require_admin();
    if (!in_array($id, array_column(LAUNCH_MANUAL, 0), true)) {
        throw new HttpError(422, 'Questa voce si controlla da sola.');
    }
    $done = json_decode(setting('launch_done', '{}') ?? '{}', true) ?: [];
    $done[$id] = !empty(body()['done']);
    set_setting('launch_done', json_encode($done));
    return ['ok' => true];
}
