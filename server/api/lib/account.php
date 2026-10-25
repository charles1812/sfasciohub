<?php
// Email di sistema (conferma dell'indirizzo, password dimenticata, nuovi piazzali) ed errori delle app.
declare(strict_types=1);

const RESET_MINUTES = 60;
const VERIFY_DAYS = 7;
const ERRORS_PER_HOUR = 60;   // segnalazioni di errore per IP

/** Limite generico per IP: $key distingue gli usi (login, errori, email). */
function rate_limit(string $key, int $max, int $seconds): void
{
    $ip = $key . ':' . ($_SERVER['REMOTE_ADDR'] ?? '?');
    db()->prepare('DELETE FROM login_attempts WHERE attempted_at < ?')->execute([gmdate('Y-m-d H:i:s', time() - 86400)]);
    db()->prepare('DELETE FROM login_attempts WHERE ip = ? AND attempted_at < ?')->execute([$ip, gmdate('Y-m-d H:i:s', time() - $seconds)]);
    $st = db()->prepare('SELECT COUNT(*) FROM login_attempts WHERE ip = ?');
    $st->execute([$ip]);
    if ((int) $st->fetchColumn() >= $max) {
        throw new HttpError(429, 'Troppi tentativi. Riprova tra qualche minuto.');
    }
    db()->prepare('INSERT INTO login_attempts (ip, attempted_at) VALUES (?, ?)')->execute([$ip, now()]);
}

/** Indirizzo pubblico della cartella api/, per i link nelle email. */
function api_url(): string
{
    $cfg = config();
    if (!empty($cfg['site_url'])) {
        return rtrim((string) $cfg['site_url'], '/') . '/api/';
    }
    $https = !empty($_SERVER['HTTPS']) || ($_SERVER['HTTP_X_FORWARDED_PROTO'] ?? '') === 'https';
    $dir = rtrim(str_replace('\\', '/', dirname($_SERVER['SCRIPT_NAME'] ?? '/api/index.php')), '/');
    return ($https ? 'https' : 'http') . '://' . ($_SERVER['HTTP_HOST'] ?? 'localhost') . $dir . '/';
}

/**
 * Manda un'email di testo con mail() di PHP (su Hostinger funziona senza configurare nulla).
 * Il mittente si può cambiare con 'mail_from' in config.php. In locale le email finiscono in api/mail.log.
 */
function send_mail(string $to, string $subject, string $text): bool
{
    $cfg = config();
    $host = preg_replace('/:\d+$/', '', $_SERVER['HTTP_HOST'] ?? 'localhost');
    $from = (string) ($cfg['mail_from'] ?? "noreply@$host");
    if (!empty($cfg['mail_log']) || in_array($host, ['localhost', '127.0.0.1'], true)) {
        file_put_contents(__DIR__ . '/../mail.log', "To: $to\nSubject: $subject\n\n$text\n-----\n", FILE_APPEND | LOCK_EX);
        return true;
    }
    $headers = "From: SfascioHub <$from>\r\nReply-To: $from\r\nContent-Type: text/plain; charset=utf-8\r\nContent-Transfer-Encoding: 8bit";
    $ok = @mail($to, '=?UTF-8?B?' . base64_encode($subject) . '?=', $text, $headers, "-f$from");
    if (!$ok) {
        record_error('server', 'Email non inviata a ' . preg_replace('/^(.).*@/', '$1…@', $to) . ": $subject", '');
    }
    return $ok;
}

function email_token(string $userId, string $purpose, int $seconds): string
{
    db()->prepare('DELETE FROM email_tokens WHERE (user_id = ? AND purpose = ?) OR expires_at < ?')->execute([$userId, $purpose, now()]);
    $token = bin2hex(random_bytes(32));
    db()->prepare('INSERT INTO email_tokens (token_hash, user_id, purpose, expires_at, created_at) VALUES (?, ?, ?, ?, ?)')
        ->execute([hash('sha256', $token), $userId, $purpose, gmdate('Y-m-d H:i:s', time() + $seconds), now()]);
    return $token;
}

/** Utente del link, o null se il link è scaduto o già usato. */
function email_token_user(string $token, string $purpose): ?array
{
    if (!preg_match('/^[a-f0-9]{64}$/', $token)) {
        return null;
    }
    $st = db()->prepare('SELECT u.id, u.email FROM email_tokens t JOIN users u ON u.id = t.user_id
                         WHERE t.token_hash = ? AND t.purpose = ? AND t.expires_at > ? AND u.disabled = 0');
    $st->execute([hash('sha256', $token), $purpose, now()]);
    return $st->fetch() ?: null;
}

function drop_email_token(string $token): void
{
    db()->prepare('DELETE FROM email_tokens WHERE token_hash = ?')->execute([hash('sha256', $token)]);
}

function send_verify_email(string $userId, string $email): void
{
    $link = api_url() . 'account.php?verify=' . email_token($userId, 'verify', VERIFY_DAYS * 86400);
    send_mail($email, 'Conferma il tuo indirizzo email', "Ciao,\n\nper confermare il tuo account SfascioHub apri questo link:\n$link\n\n"
        . "Il link vale " . VERIFY_DAYS . " giorni. Se non hai creato tu l'account, ignora questa email.\n\nSfascioHub");
}

/** POST /auth/forgot: risponde sempre allo stesso modo, così non si scopre chi è iscritto. */
function auth_forgot(): array
{
    $email = normalize_email(body());
    rate_limit('forgot', 5, 3600);
    $st = db()->prepare('SELECT id FROM users WHERE email = ? AND disabled = 0');
    $st->execute([$email]);
    if ($id = $st->fetchColumn()) {
        $link = api_url() . 'account.php?reset=' . email_token($id, 'reset', RESET_MINUTES * 60);
        send_mail($email, 'Nuova password per SfascioHub', "Ciao,\n\nper scegliere una nuova password apri questo link:\n$link\n\n"
            . "Il link vale " . RESET_MINUTES . " minuti e si può usare una volta sola. "
            . "Se non l'hai chiesto tu, ignora questa email: la password resta quella di prima.\n\nSfascioHub");
    }
    return ['ok' => true];
}

/** POST /me/verify/resend */
function resend_verify(): array
{
    $u = require_user();
    rate_limit('verify', 3, 3600);
    $st = db()->prepare('SELECT email_verified FROM users WHERE id = ?');
    $st->execute([$u['id']]);
    if (!(int) $st->fetchColumn()) {
        send_verify_email($u['id'], $u['email']);
    }
    return ['ok' => true];
}

/** Avvisa gli amministratori (quelli scritti in api/admins.php) che c'è un piazzale da approvare. */
function notify_new_yard(string $name, string $city, string $email): void
{
    foreach (admin_emails() as $admin) {
        send_mail($admin, "Nuovo piazzale da approvare: $name", "Si è iscritto un nuovo sfasciacarrozze.\n\n"
            . "Nome: $name\nCittà: " . ($city ?: '—') . "\nAccount: $email\n\n"
            . "Finché non lo approvi dall'app Admin (scheda Piazzali) le sue auto non sono visibili ai clienti.");
    }
}

// ---------------------------------------------------------------------------
// Errori delle app e del server
// ---------------------------------------------------------------------------

/** Salva un errore; lo stesso errore ripetuto aumenta solo il contatore. */
function record_error(string $source, string $message, string $stack, string $version = '', string $platform = '', string $email = ''): void
{
    try {
        $message = mb_substr(trim($message), 0, 500) ?: 'Errore senza messaggio';
        // la prima riga utile dello stack distingue errori con lo stesso messaggio
        $where = '';
        foreach (preg_split('/\R/', $stack) as $line) {
            if (preg_match('#package:sfasciohub/|/api/#', $line)) {
                $where = trim($line);
                break;
            }
        }
        $fp = substr(hash('sha256', "$source|$version|" . preg_replace(['/[0-9a-f]{8}-[0-9a-f-]{27}/i', '/\d+/'], ['ID', '#'], $message) . "|$where"), 0, 16);
        $n = db()->prepare('UPDATE app_errors SET count = count + 1, last_at = ?, user_email = ? WHERE fingerprint = ?');
        $n->execute([now(), $email, $fp]);
        if ($n->rowCount() === 0) {
            db()->prepare('INSERT INTO app_errors (fingerprint, source, version, platform, message, stack, user_email, count, first_at, last_at)
                           VALUES (?, ?, ?, ?, ?, ?, ?, 1, ?, ?)')
                ->execute([$fp, $source, $version, $platform, $message, mb_substr($stack, 0, 8000), $email, now(), now()]);
        }
    } catch (Throwable $e) {
        error_log('[sfasciohub] errore non registrato: ' . $e->getMessage());
    }
}

/** POST /errors: le app mandano qui le eccezioni non gestite. */
function report_error(): array
{
    rate_limit('errors', ERRORS_PER_HOUR, 3600);
    $b = body();
    $source = preg_replace('/[^a-z_]/', '', strtolower((string) ($b['app'] ?? ''))) ?: 'app';
    $u = current_user();
    record_error(
        mb_substr($source, 0, 20),
        (string) ($b['message'] ?? ''),
        (string) ($b['stack'] ?? ''),
        mb_substr((string) ($b['version'] ?? ''), 0, 20),
        mb_substr((string) ($b['platform'] ?? ''), 0, 20),
        $u['email'] ?? '',
    );
    return ['ok' => true];
}

/** GET /admin/errors: gli errori più recenti per primi. */
function admin_errors(): array
{
    require_admin();
    $rows = db()->query('SELECT * FROM app_errors ORDER BY last_at DESC LIMIT 200')->fetchAll();
    return array_map(fn($r) => [
        'id' => (int) $r['id'],
        'source' => $r['source'],
        'version' => $r['version'],
        'platform' => $r['platform'],
        'message' => $r['message'],
        'stack' => $r['stack'] ?? '',
        'user_email' => $r['user_email'],
        'count' => (int) $r['count'],
        'first_at' => $r['first_at'],
        'last_at' => $r['last_at'],
    ], $rows);
}

/** DELETE /admin/errors/{id}: errore risolto (id "all" li toglie tutti). */
function admin_delete_error(string $id): array
{
    require_admin();
    $id === 'all'
        ? db()->exec('DELETE FROM app_errors')
        : db()->prepare('DELETE FROM app_errors WHERE id = ?')->execute([(int) $id]);
    return ['ok' => true];
}
