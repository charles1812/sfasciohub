<?php
// SfascioHub · copia di sicurezza, scaricata dal PC con tool/backup.sh.
//
//   GET api/backup.php?what=db        header X-Deploy-Key   → tutto il database in SQL (gzip)
//   GET api/backup.php?what=uploads   header X-Deploy-Key   → elenco delle foto (nome, dimensione)
//
// Stessa chiave di deploy.php. Il file .sql si reimporta da phpMyAdmin.
declare(strict_types=1);

require __DIR__ . '/lib/bootstrap.php';
require __DIR__ . '/lib/schema.php';
require __DIR__ . '/lib/status.php';

header('Cache-Control: no-store');

function fail(int $status, string $msg): never
{
    http_response_code($status);
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode(['error' => $msg], JSON_UNESCAPED_UNICODE);
    exit;
}

if (empty($_SERVER['HTTPS']) && ($_SERVER['HTTP_X_FORWARDED_PROTO'] ?? '') !== 'https' && PHP_SAPI !== 'cli-server') {
    fail(403, 'Solo HTTPS.');
}
$hashFile = __DIR__ . '/deploy_key.php';
$expected = is_file($hashFile) ? (string) require $hashFile : '';
$given = (string) ($_SERVER['HTTP_X_DEPLOY_KEY'] ?? '');
if ($expected === '' || !preg_match('/^[a-f0-9]{64}$/', $given) || !hash_equals($expected, hash('sha256', $given))) {
    sleep(2);
    fail(401, 'Chiave non valida.');
}

$what = (string) ($_GET['what'] ?? '');

if ($what === 'uploads') {
    header('Content-Type: application/json; charset=utf-8');
    $dir = realpath(__DIR__ . '/../uploads');
    $files = [];
    if ($dir) {
        $it = new RecursiveIteratorIterator(new RecursiveDirectoryIterator($dir, FilesystemIterator::SKIP_DOTS));
        foreach ($it as $f) {
            if ($f->isFile() && !str_starts_with($f->getFilename(), '.')) {
                $files[] = ['file' => str_replace('\\', '/', substr($f->getPathname(), strlen($dir) + 1)), 'size' => $f->getSize()];
            }
        }
    }
    echo json_encode(['files' => $files], JSON_UNESCAPED_SLASHES);
    exit;
}

if ($what !== 'db') {
    fail(400, 'Usa what=db oppure what=uploads.');
}

$pdo = db();
$sqlite = is_sqlite();
$tables = $sqlite
    ? $pdo->query("SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%'")->fetchAll(PDO::FETCH_COLUMN)
    : $pdo->query('SHOW TABLES')->fetchAll(PDO::FETCH_COLUMN);
// sessioni e tentativi di accesso non servono in un ripristino
$tables = array_values(array_diff($tables, ['auth_tokens', 'login_attempts', 'email_tokens']));

header('Content-Type: application/gzip');
header('Content-Disposition: attachment; filename="sfasciohub-' . gmdate('Y-m-d') . '.sql.gz"');
// compressione a pezzi direttamente in uscita, senza tenere tutto il dump in memoria
$gz = deflate_init(ZLIB_ENCODING_GZIP, ['level' => 6]);
function gzwrite_out(DeflateContext $gz, string $data, int $flush = ZLIB_NO_FLUSH): void
{
    echo deflate_add($gz, $data, $flush);
}
gzwrite_out($gz, "-- SfascioHub backup " . gmdate('Y-m-d H:i:s') . " UTC\nSET NAMES utf8mb4;\nSET FOREIGN_KEY_CHECKS = 0;\n\n");
foreach ($tables as $t) {
    if (!$sqlite) {
        $create = $pdo->query("SHOW CREATE TABLE `$t`")->fetch(PDO::FETCH_NUM)[1];
        gzwrite_out($gz, "DROP TABLE IF EXISTS `$t`;\n$create;\n\n");
    }
    $st = $pdo->query("SELECT * FROM `$t`");
    $batch = [];
    $cols = null;
    while ($row = $st->fetch(PDO::FETCH_ASSOC)) {
        $cols ??= '(`' . implode('`, `', array_keys($row)) . '`)';
        $batch[] = '(' . implode(', ', array_map(fn($v) => $v === null ? 'NULL' : $pdo->quote((string) $v), $row)) . ')';
        if (count($batch) >= 200) {
            gzwrite_out($gz, "INSERT INTO `$t` $cols VALUES\n" . implode(",\n", $batch) . ";\n");
            $batch = [];
        }
    }
    if ($batch) {
        gzwrite_out($gz, "INSERT INTO `$t` $cols VALUES\n" . implode(",\n", $batch) . ";\n");
    }
    gzwrite_out($gz, "\n");
}
gzwrite_out($gz, "SET FOREIGN_KEY_CHECKS = 1;\n", ZLIB_FINISH);
// la scheda Server dell'app Admin mostra quando è stato fatto l'ultimo backup
set_setting('last_backup', now());
