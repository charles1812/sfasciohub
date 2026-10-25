<?php
// SfascioHub · carica gli APK nella cartella app/ del sito, così si scaricano dal nostro indirizzo
// e non da GitHub (dove su alcuni telefoni il download si blocca al 100%).
//
//   POST api/apk_upload.php?name=SfascioHub-arm64.apk&part=0&last=0   header X-Deploy-Key   corpo: un pezzo del file
//
// Il file arriva a pezzi (l'hosting limita la dimensione di ogni richiesta). Con last=1 il file
// completo prende il posto di quello vecchio. Stessa chiave di deploy.php.
declare(strict_types=1);

header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store');

function done(int $status, array $data): never
{
    http_response_code($status);
    echo json_encode($data, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    exit;
}

if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
    done(405, ['error' => 'Usa POST.']);
}
if (empty($_SERVER['HTTPS']) && ($_SERVER['HTTP_X_FORWARDED_PROTO'] ?? '') !== 'https' && PHP_SAPI !== 'cli-server') {
    done(403, ['error' => 'Solo HTTPS.']);
}
$hashFile = __DIR__ . '/deploy_key.php';
$expected = is_file($hashFile) ? (string) require $hashFile : '';
$given = (string) ($_SERVER['HTTP_X_DEPLOY_KEY'] ?? '');
if ($expected === '' || !preg_match('/^[a-f0-9]{64}$/', $given) || !hash_equals($expected, hash('sha256', $given))) {
    sleep(2);
    done(401, ['error' => 'Chiave non valida.']);
}

$name = (string) ($_GET['name'] ?? '');
if (!preg_match('/^SfascioHub(-Gestione|-Admin)?(-arm64)?\.apk$/', $name)) {
    done(422, ['error' => 'Nome non ammesso.']);
}
$part = (int) ($_GET['part'] ?? 0);
$dir = realpath(__DIR__ . '/..') . '/app';
if (!is_dir($dir)) {
    mkdir($dir, 0755, true);
}
$tmp = "$dir/.$name.part";

$data = file_get_contents('php://input') ?: '';
if ($data === '') {
    done(400, ['error' => 'Pezzo vuoto: forse supera il limite della richiesta.', 'post_max_size' => ini_get('post_max_size')]);
}
if ($part === 0) {
    @unlink($tmp);
} elseif (!is_file($tmp)) {
    done(409, ['error' => 'Manca l\'inizio del file: ricomincia da part=0.']);
}
file_put_contents($tmp, $data, FILE_APPEND | LOCK_EX);

if (!empty($_GET['last'])) {
    clearstatcache();
    $size = filesize($tmp);
    $want = isset($_GET['size']) ? (int) $_GET['size'] : $size;
    $sha = hash_file('sha256', $tmp);
    if ($size !== $want || (isset($_GET['sha256']) && !hash_equals((string) $_GET['sha256'], $sha))) {
        @unlink($tmp);
        done(422, ['error' => 'Il file arrivato è diverso da quello mandato.', 'size' => $size]);
    }
    rename($tmp, "$dir/$name");
    done(200, ['ok' => true, 'name' => $name, 'size' => $size, 'sha256' => $sha]);
}
done(200, ['ok' => true, 'part' => $part, 'received' => strlen($data)]);
