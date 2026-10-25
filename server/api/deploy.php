<?php
// SfascioHub · aggiornamento del server senza File Manager.
//
//   POST api/deploy.php   header  X-Deploy-Key: <chiave>   corpo: file .zip (sito, gestione/, api/)
//
// La chiave vera resta sul PC di chi pubblica; qui c'è solo la sua impronta SHA-256 (api/deploy_key.php).
// Non tocca mai configurazione, chiave AI, elenco admin né le foto in uploads/.
// Prima di sovrascrivere salva i file vecchi in api/deploy_backups/<data>/.
declare(strict_types=1);

const DEPLOY_MAX_BYTES = 60 * 1024 * 1024;
const DEPLOY_MAX_FAILS = 5;            // tentativi sbagliati per IP…
const DEPLOY_FAIL_WINDOW = 3600;       // …in un'ora
const DEPLOY_KEEP_BACKUPS = 5;
const DEPLOY_PROTECTED = ['api/config.php', 'api/ai_key.php', 'api/admins.php', 'api/deploy_key.php'];
const DEPLOY_EXTENSIONS = ['php', 'js', 'mjs', 'html', 'json', 'css', 'png', 'jpg', 'svg', 'ico', 'webp', 'otf', 'ttf', 'woff', 'woff2',
    'wasm', 'symbols', 'frag', 'bin', 'txt', 'md', 'htaccess', 'last_build_id'];

header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store');

function out(int $status, array $data): never
{
    http_response_code($status);
    echo json_encode($data, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    exit;
}

$root = realpath(__DIR__ . '/..');            // la cartella del sito (public_html/sfasciohub)
$work = __DIR__ . '/deploy_backups';
if (!is_dir($work)) {
    @mkdir($work, 0750, true);
}
if (!is_file("$work/.htaccess")) {
    file_put_contents("$work/.htaccess", "Require all denied\n");
}

if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
    out(405, ['error' => 'Usa POST.']);
}
if (empty($_SERVER['HTTPS']) && ($_SERVER['HTTP_X_FORWARDED_PROTO'] ?? '') !== 'https' && PHP_SAPI !== 'cli-server') {
    out(403, ['error' => 'Solo HTTPS.']);
}

// ---- blocco dei tentativi sbagliati ----
$ip = $_SERVER['REMOTE_ADDR'] ?? '?';
$failsFile = "$work/fails.json";
$fails = is_file($failsFile) ? (json_decode((string) file_get_contents($failsFile), true) ?: []) : [];
$fails = array_filter($fails, fn($f) => $f['t'] > time() - DEPLOY_FAIL_WINDOW);
if (count(array_filter($fails, fn($f) => $f['ip'] === $ip)) >= DEPLOY_MAX_FAILS) {
    out(429, ['error' => 'Troppi tentativi, riprova tra un\'ora.']);
}

// ---- chiave ----
$hashFile = __DIR__ . '/deploy_key.php';
$expected = is_file($hashFile) ? (string) require $hashFile : '';
$given = (string) ($_SERVER['HTTP_X_DEPLOY_KEY'] ?? '');
if ($expected === '' || !preg_match('/^[a-f0-9]{64}$/', $given) || !hash_equals($expected, hash('sha256', $given))) {
    $fails[] = ['ip' => $ip, 't' => time()];
    file_put_contents($failsFile, json_encode(array_values($fails)), LOCK_EX);
    out(401, ['error' => 'Chiave non valida.']);
}

// ---- pacchetto ----
if (!class_exists('ZipArchive')) {
    out(500, ['error' => 'Sul server manca ZipArchive.']);
}
$data = file_get_contents('php://input', false, null, 0, DEPLOY_MAX_BYTES + 1) ?: '';
if ($data === '' || strlen($data) > DEPLOY_MAX_BYTES) {
    out(413, ['error' => 'Pacchetto vuoto o troppo grande.']);
}
$tmp = tempnam($work, 'pkg');
file_put_contents($tmp, $data);
$zip = new ZipArchive();
if ($zip->open($tmp) !== true) {
    @unlink($tmp);
    out(400, ['error' => 'Il pacchetto non è uno zip valido.']);
}

// controllo di tutti i percorsi prima di scrivere qualsiasi cosa
$entries = [];
for ($i = 0; $i < $zip->numFiles; $i++) {
    $name = str_replace('\\', '/', (string) $zip->getNameIndex($i));
    if (str_ends_with($name, '/')) {
        continue;
    }
    $base = basename($name);
    $ext = str_starts_with($base, '.') ? ltrim($base, '.') : strtolower(pathinfo($base, PATHINFO_EXTENSION));
    if ($base === 'NOTICES') {
        $ext = 'txt';
    }
    $bad = $name === '' || str_starts_with($name, '/') || preg_match('#(^|/)\.\.(/|$)#', $name) || str_contains($name, ':')
        || str_starts_with($name, 'uploads/') || str_starts_with($name, 'api/deploy_backups/')
        || in_array($name, DEPLOY_PROTECTED, true) || $name === 'api/deploy.php' || !in_array($ext, DEPLOY_EXTENSIONS, true);
    if ($bad) {
        $zip->close();
        @unlink($tmp);
        out(422, ['error' => "File non ammesso nel pacchetto: $name"]);
    }
    $entries[$i] = $name;
}

// copia di sicurezza dei file che verranno sostituiti, poi scrittura
$stamp = gmdate('Ymd-His');
$backup = "$work/$stamp";
$written = 0;
$order = $entries;
// api/index.php per ultimo: fino all'ultimo il sito usa la versione vecchia completa
uasort($order, fn($a, $b) => ($a === 'api/index.php') <=> ($b === 'api/index.php'));
foreach ($order as $i => $name) {
    $dest = "$root/$name";
    if (is_file($dest)) {
        @mkdir(dirname("$backup/$name"), 0750, true);
        copy($dest, "$backup/$name");
    }
    @mkdir(dirname($dest), 0755, true);
    $content = $zip->getFromIndex($i);
    if ($content === false || file_put_contents("$dest.tmp", $content) === false || !rename("$dest.tmp", $dest)) {
        $zip->close();
        @unlink($tmp);
        out(500, ['error' => "Scrittura non riuscita: $name", 'written' => $written, 'backup' => $stamp]);
    }
    $written++;
}
$zip->close();
@unlink($tmp);
if (function_exists('opcache_reset')) {
    @opcache_reset();
}

// tiene solo le ultime copie di sicurezza
$dirs = glob("$work/2*", GLOB_ONLYDIR) ?: [];
rsort($dirs);
foreach (array_slice($dirs, DEPLOY_KEEP_BACKUPS) as $old) {
    $it = new RecursiveIteratorIterator(new RecursiveDirectoryIterator($old, FilesystemIterator::SKIP_DOTS), RecursiveIteratorIterator::CHILD_FIRST);
    foreach ($it as $f) {
        $f->isDir() ? @rmdir($f->getPathname()) : @unlink($f->getPathname());
    }
    @rmdir($old);
}

out(200, ['ok' => true, 'written' => $written, 'backup' => $stamp]);
