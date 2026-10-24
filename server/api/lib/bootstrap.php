<?php
// SfascioHub API · avvio comune: configurazione, database, risposte JSON, CORS.
declare(strict_types=1);

const API_VERSION = '1';
const DAMAGE_ZONES = ['front', 'front_left', 'front_right', 'left', 'right', 'rear', 'rear_left', 'rear_right', 'roof', 'interior', 'engine', 'glass'];
const FUELS = ['', 'benzina', 'diesel', 'gpl', 'metano', 'ibrida', 'elettrica'];
const STATUSES = ['available', 'reserved', 'gone'];

final class HttpError extends Exception
{
    public function __construct(public readonly int $status, string $message)
    {
        parent::__construct($message);
    }
}

function config(): array
{
    static $cfg = null;
    if ($cfg === null) {
        $file = __DIR__ . '/../config.php';
        if (!is_file($file)) {
            throw new HttpError(503, 'SfascioHub non è ancora installato: apri api/install.php');
        }
        $cfg = require $file;
    }
    return $cfg;
}

function db(): PDO
{
    static $pdo = null;
    if ($pdo === null) {
        $pdo = connect(config()['db']);
        if (function_exists('migrate_schema')) {
            migrate_schema($pdo, is_sqlite());
        }
    }
    return $pdo;
}

/** @param array{driver:string,host?:string,port?:int,name?:string,user?:string,pass?:string,path?:string} $c */
function connect(array $c): PDO
{
    $opts = [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        PDO::ATTR_EMULATE_PREPARES => false,
    ];
    if (($c['driver'] ?? 'mysql') === 'sqlite') {
        $pdo = new PDO('sqlite:' . $c['path'], null, null, $opts);
        $pdo->exec('PRAGMA foreign_keys = ON');
        return $pdo;
    }
    $dsn = sprintf('mysql:host=%s;port=%d;dbname=%s;charset=utf8mb4', $c['host'], $c['port'] ?? 3306, $c['name']);
    return new PDO($dsn, $c['user'], $c['pass'], $opts);
}

function is_sqlite(): bool
{
    return (config()['db']['driver'] ?? 'mysql') === 'sqlite';
}

function now(): string
{
    return gmdate('Y-m-d H:i:s');
}

function uuid(): string
{
    $b = random_bytes(16);
    $b[6] = chr((ord($b[6]) & 0x0f) | 0x40);
    $b[8] = chr((ord($b[8]) & 0x3f) | 0x80);
    return vsprintf('%s%s-%s-%s-%s-%s%s%s', str_split(bin2hex($b), 4));
}

// ---------------------------------------------------------------------------
// Richiesta / risposta
// ---------------------------------------------------------------------------

function send_json(mixed $data, int $status = 200): never
{
    http_response_code($status);
    header('Content-Type: application/json; charset=utf-8');
    header('Cache-Control: no-store');
    echo json_encode($data, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    exit;
}

function body(): array
{
    static $data = null;
    if ($data === null) {
        $raw = file_get_contents('php://input') ?: '';
        $data = $raw === '' ? [] : json_decode($raw, true);
        if (!is_array($data)) {
            throw new HttpError(400, 'Richiesta non valida (JSON atteso).');
        }
    }
    return $data;
}

function str_field(array $src, string $key, int $max, bool $required = false, string $label = ''): string
{
    $v = $src[$key] ?? '';
    if (!is_string($v)) {
        $v = is_scalar($v) ? (string) $v : '';
    }
    $v = trim($v);
    if ($required && $v === '') {
        throw new HttpError(422, ($label ?: $key) . ' è obbligatorio.');
    }
    if (mb_strlen($v) > $max) {
        throw new HttpError(422, ($label ?: $key) . " è troppo lungo (max $max caratteri).");
    }
    return $v;
}

function int_field(array $src, string $key, int $min, int $max): ?int
{
    $v = $src[$key] ?? null;
    if ($v === null || $v === '') {
        return null;
    }
    if (!is_numeric($v) || (int) $v != $v || $v < $min || $v > $max) {
        throw new HttpError(422, "Valore non valido per $key.");
    }
    return (int) $v;
}

function cors(): void
{
    $origin = $_SERVER['HTTP_ORIGIN'] ?? '';
    if ($origin === '') {
        return;
    }
    $allowed = config()['cors_origins'] ?? [];
    $self = (is_https() ? 'https://' : 'http://') . ($_SERVER['HTTP_HOST'] ?? '');
    if ($origin === $self || in_array($origin, $allowed, true) || in_array('*', $allowed, true)) {
        header('Access-Control-Allow-Origin: ' . $origin);
        header('Vary: Origin');
        header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Auth-Token');
        header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
        header('Access-Control-Max-Age: 86400');
    }
}

function is_https(): bool
{
    return (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off')
        || ($_SERVER['HTTP_X_FORWARDED_PROTO'] ?? '') === 'https';
}

/** URL pubblico della cartella che contiene api/ e uploads/. */
function base_url(): string
{
    $cfg = config();
    if (!empty($cfg['base_url'])) {
        return rtrim($cfg['base_url'], '/');
    }
    $scheme = is_https() ? 'https' : 'http';
    $dir = rtrim(str_replace('\\', '/', dirname($_SERVER['SCRIPT_NAME'] ?? '/api/index.php', 2)), '/');
    return $scheme . '://' . ($_SERVER['HTTP_HOST'] ?? 'localhost') . $dir;
}

function uploads_dir(): string
{
    return __DIR__ . '/../../uploads';
}
