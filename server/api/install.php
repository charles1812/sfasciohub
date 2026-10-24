<?php
// SfascioHub · installazione guidata. Si apre una volta dal browser, poi si blocca da sola.
// Da riga di comando (test in locale): php install.php --sqlite=percorso/db.sqlite [--demo]
declare(strict_types=1);

require __DIR__ . '/lib/bootstrap.php';
require __DIR__ . '/lib/schema.php';
require __DIR__ . '/lib/seed.php';

const CONFIG_FILE = __DIR__ . '/config.php';

function write_config(array $db, array $cors): void
{
    $cfg = [
        'db' => $db,
        // siti esterni che possono usare l'API (es. GitHub Pages); lo stesso dominio è sempre ammesso
        'cors_origins' => $cors,
        // lascia vuoto: viene ricavato dall'indirizzo della richiesta
        'base_url' => '',
        'debug' => false,
    ];
    $php = "<?php\n// Generato da install.php il " . gmdate('Y-m-d H:i') . " UTC. Non condividere questo file.\nreturn "
        . var_export($cfg, true) . ";\n";
    if (file_put_contents(CONFIG_FILE, $php, LOCK_EX) === false) {
        throw new RuntimeException('Non riesco a scrivere api/config.php: controlla i permessi della cartella.');
    }
    @chmod(CONFIG_FILE, 0640);
}

function install(array $db, bool $demo, array $cors): void
{
    $pdo = connect($db);
    create_schema($pdo, ($db['driver'] ?? 'mysql') === 'sqlite');
    @unlink(__DIR__ . '/schema.flag');
    @unlink(__DIR__ . '/schema_v2.flag');
    migrate_schema($pdo, ($db['driver'] ?? 'mysql') === 'sqlite');
    if ($demo) {
        seed_demo($pdo);
    }
    if (!is_dir(uploads_dir())) {
        @mkdir(uploads_dir(), 0755, true);
    }
    write_config($db, $cors);
}

// ---- riga di comando ----
if (PHP_SAPI === 'cli') {
    $opts = getopt('', ['sqlite:', 'demo']);
    if (empty($opts['sqlite'])) {
        fwrite(STDERR, "Uso: php install.php --sqlite=db.sqlite [--demo]\n");
        exit(1);
    }
    install(['driver' => 'sqlite', 'path' => $opts['sqlite']], isset($opts['demo']), ['*']);
    echo "Installato in {$opts['sqlite']}\n";
    exit(0);
}

// ---- browser ----
header('Content-Type: text/html; charset=utf-8');
header('X-Frame-Options: DENY');
header('Cache-Control: no-store');

$done = is_file(CONFIG_FILE);
$error = '';
$ok = false;

if (!$done && ($_SERVER['REQUEST_METHOD'] ?? '') === 'POST') {
    $db = [
        'driver' => 'mysql',
        'host' => trim((string) ($_POST['host'] ?? 'localhost')) ?: 'localhost',
        'port' => (int) ($_POST['port'] ?? 3306) ?: 3306,
        'name' => trim((string) ($_POST['name'] ?? '')),
        'user' => trim((string) ($_POST['user'] ?? '')),
        'pass' => (string) ($_POST['pass'] ?? ''),
    ];
    $cors = array_values(array_filter(array_map('trim', explode("\n", (string) ($_POST['cors'] ?? '')))));
    try {
        if ($db['name'] === '' || $db['user'] === '') {
            throw new RuntimeException('Inserisci nome del database e utente.');
        }
        install($db, isset($_POST['demo']), $cors);
        $ok = true;
        $done = true;
    } catch (PDOException $e) {
        $error = 'Connessione al database non riuscita: ' . $e->getMessage();
    } catch (Throwable $e) {
        $error = $e->getMessage();
    }
}
$h = fn(string $s) => htmlspecialchars($s, ENT_QUOTES, 'UTF-8');
?>
<!doctype html>
<html lang="it">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex">
<title>Installa SfascioHub</title>
<style>
  :root { --asphalt:#1E2326; --orange:#F26B1D; --paper:#F6F4F0; --line:#DAD4C8; --ok:#2E8B57; --err:#D64545; }
  * { box-sizing: border-box; }
  body { margin: 0; min-height: 100vh; display: grid; place-items: center; padding: 24px 16px; background: var(--asphalt); font: 15px/1.5 system-ui, -apple-system, "Segoe UI", sans-serif; color: #222; }
  .card { width: min(560px, 100%); background: #fff; border-radius: 18px; padding: 28px; box-shadow: 0 20px 60px rgba(0,0,0,.35); }
  h1 { margin: 0 0 4px; font-size: 24px; } h1 span { color: var(--orange); }
  p.sub { margin: 0 0 20px; color: #666; }
  label { display: block; font-weight: 600; font-size: 13px; margin: 14px 0 6px; }
  input[type=text], input[type=password], input[type=number], textarea { width: 100%; padding: 11px 13px; border: 1.5px solid var(--line); border-radius: 10px; font: inherit; }
  input:focus, textarea:focus { outline: none; border-color: var(--orange); }
  .row { display: grid; grid-template-columns: 1fr 110px; gap: 12px; }
  .check { display: flex; gap: 10px; align-items: flex-start; margin-top: 16px; font-weight: 500; }
  .check input { margin-top: 4px; }
  button { margin-top: 22px; width: 100%; padding: 14px; border: 0; border-radius: 12px; background: var(--orange); color: #fff; font: 700 15px system-ui; cursor: pointer; }
  .note { font-size: 12.5px; color: #777; margin-top: 4px; }
  .box { padding: 12px 14px; border-radius: 10px; margin-bottom: 16px; }
  .err { background: #FADBD8; color: #8a1f1f; } .ok { background: #DDF2E5; color: #1e5c39; }
  code { background: #f1efe9; padding: 1px 6px; border-radius: 5px; }
  ol { padding-left: 20px; } li { margin: 4px 0; }
</style>
</head>
<body>
<main class="card">
  <h1>🚗 Sfascio<span>Hub</span></h1>
<?php if ($done): ?>
  <?php if ($ok): ?><div class="box ok"><b>Installazione completata.</b></div><?php endif; ?>
  <p class="sub">SfascioHub è installato e collegato al database.</p>
  <ol>
    <li>Il sito pubblico è nella cartella principale, la gestione in <code>gestione/</code>.</li>
    <li>Per sicurezza puoi eliminare questo file (<code>api/install.php</code>): è comunque bloccato.</li>
    <li>Per reinstallare elimina <code>api/config.php</code> e riapri questa pagina.</li>
  </ol>
  <?php if ($ok && isset($_POST['demo'])): ?>
    <p>Account di prova: <code><?= $h(DEMO_EMAIL) ?></code> / <code><?= $h(DEMO_PASSWORD) ?></code>
      <br><span class="note">Gestisce lo sfasciacarrozze "Autodemolizioni Martesana (demo)".</span></p>
  <?php endif; ?>
<?php else: ?>
  <p class="sub">Collega il database MySQL creato in hPanel → <b>Database MySQL</b>.</p>
  <?php if ($error): ?><div class="box err"><?= $h($error) ?></div><?php endif; ?>
  <form method="post" autocomplete="off">
    <div class="row">
      <div><label for="host">Host</label><input id="host" name="host" type="text" value="<?= $h($_POST['host'] ?? 'localhost') ?>"></div>
      <div><label for="port">Porta</label><input id="port" name="port" type="number" value="<?= $h((string) ($_POST['port'] ?? '3306')) ?>"></div>
    </div>
    <p class="note">Su Hostinger di solito è <code>localhost</code>.</p>
    <label for="name">Nome del database</label>
    <input id="name" name="name" type="text" required placeholder="u123456789_sfasciohub" value="<?= $h($_POST['name'] ?? '') ?>">
    <label for="user">Utente</label>
    <input id="user" name="user" type="text" required placeholder="u123456789_sfascio" value="<?= $h($_POST['user'] ?? '') ?>">
    <label for="pass">Password del database</label>
    <input id="pass" name="pass" type="password" required>
    <label for="cors">Altri siti ammessi (facoltativo)</label>
    <textarea id="cors" name="cors" rows="2" placeholder="https://charles1812.github.io"><?= $h($_POST['cors'] ?? 'https://charles1812.github.io') ?></textarea>
    <p class="note">Uno per riga. Il dominio di questo server è sempre ammesso.</p>
    <label class="check"><input type="checkbox" name="demo" <?= ($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST' || isset($_POST['demo']) ? 'checked' : '' ?>>
      <span>Carica i dati di esempio<br><span class="note">3 sfasciacarrozze, 16 auto e un account di prova. Potrai cancellarli.</span></span></label>
    <button type="submit">Installa</button>
  </form>
<?php endif; ?>
</main>
</body>
</html>
