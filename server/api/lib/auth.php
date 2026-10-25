<?php
// Account e sessioni: password bcrypt, token casuali (nel DB solo l'hash SHA-256).
declare(strict_types=1);

const TOKEN_DAYS = 90;
const LOGIN_MAX_ATTEMPTS = 10;   // per IP ogni 15 minuti

function request_token(): ?string
{
    $h = $_SERVER['HTTP_AUTHORIZATION'] ?? $_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? '';
    if ($h === '' && function_exists('getallheaders')) {
        foreach (getallheaders() as $k => $v) {
            if (strcasecmp($k, 'Authorization') === 0) {
                $h = $v;
            }
        }
    }
    if (preg_match('/^Bearer\s+([a-f0-9]{64})$/i', trim($h), $m)) {
        return strtolower($m[1]);
    }
    // alcuni hosting tolgono l'header Authorization: c'è anche X-Auth-Token
    $x = $_SERVER['HTTP_X_AUTH_TOKEN'] ?? '';
    return preg_match('/^[a-f0-9]{64}$/i', $x) ? strtolower($x) : null;
}

/** @return array{id:string,email:string,is_admin:int,email_verified:int}|null */
function current_user(): ?array
{
    static $user = false;
    if ($user === false) {
        $user = null;
        $token = request_token();
        if ($token !== null) {
            $st = db()->prepare('SELECT u.id, u.email, u.is_admin, u.email_verified FROM auth_tokens t JOIN users u ON u.id = t.user_id
                                 WHERE t.token_hash = ? AND t.expires_at > ? AND u.disabled = 0');
            $st->execute([hash('sha256', $token), now()]);
            $user = $st->fetch() ?: null;
            if ($user) {
                $user['is_admin'] = (int) ($user['is_admin'] || in_array($user['email'], admin_emails(), true));
            }
        }
    }
    return $user;
}

/** Email degli amministratori scritte a mano sul server in api/admins.php (oltre a chi è promosso dall'app). */
function admin_emails(): array
{
    $file = __DIR__ . '/../admins.php';
    $list = is_file($file) ? require $file : [];
    return array_map(fn($e) => strtolower(trim((string) $e)), is_array($list) ? $list : []);
}

function require_admin(): array
{
    $u = require_user();
    if (!$u['is_admin']) {
        throw new HttpError(403, 'Serve un account amministratore.');
    }
    return $u;
}

function require_user(): array
{
    return current_user() ?? throw new HttpError(401, 'Accedi per continuare.');
}

function issue_token(string $userId): string
{
    $token = bin2hex(random_bytes(32));
    db()->prepare('INSERT INTO auth_tokens (token_hash, user_id, expires_at, created_at) VALUES (?, ?, ?, ?)')
        ->execute([hash('sha256', $token), $userId, gmdate('Y-m-d H:i:s', time() + TOKEN_DAYS * 86400), now()]);
    return $token;
}

function check_login_rate(): void
{
    rate_limit('login', LOGIN_MAX_ATTEMPTS, 900);
}

function normalize_email(array $b): string
{
    $email = mb_strtolower(str_field($b, 'email', 190, true, 'L\'email'));
    if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
        throw new HttpError(422, 'Inserisci un indirizzo email valido.');
    }
    return $email;
}

function auth_signup(): array
{
    $b = body();
    $email = normalize_email($b);
    $password = (string) ($b['password'] ?? '');
    if (strlen($password) < 8) {
        throw new HttpError(422, 'La password deve avere almeno 8 caratteri.');
    }
    check_login_rate();
    $st = db()->prepare('SELECT 1 FROM users WHERE email = ?');
    $st->execute([$email]);
    if ($st->fetchColumn()) {
        throw new HttpError(409, 'Esiste già un account con questa email.');
    }
    $id = uuid();
    db()->prepare('INSERT INTO users (id, email, password_hash, email_verified, created_at) VALUES (?, ?, ?, 0, ?)')
        ->execute([$id, $email, password_hash($password, PASSWORD_DEFAULT), now()]);
    send_verify_email($id, $email);
    return ['token' => issue_token($id), 'user' => ['id' => $id, 'email' => $email, 'email_verified' => false]];
}

function auth_login(): array
{
    $b = body();
    $email = normalize_email($b);
    check_login_rate();
    $st = db()->prepare('SELECT id, email, password_hash, disabled, email_verified FROM users WHERE email = ?');
    $st->execute([$email]);
    $u = $st->fetch();
    if (!$u || !password_verify((string) ($b['password'] ?? ''), $u['password_hash'])) {
        throw new HttpError(401, 'Email o password non corretti.');
    }
    if ($u['disabled']) {
        throw new HttpError(403, 'Questo account è sospeso. Contatta SfascioHub.');
    }
    if (password_needs_rehash($u['password_hash'], PASSWORD_DEFAULT)) {
        db()->prepare('UPDATE users SET password_hash = ? WHERE id = ?')
            ->execute([password_hash((string) $b['password'], PASSWORD_DEFAULT), $u['id']]);
    }
    return ['token' => issue_token($u['id']), 'user' => ['id' => $u['id'], 'email' => $u['email'], 'email_verified' => (bool) $u['email_verified']]];
}

function auth_logout(): array
{
    $token = request_token();
    if ($token !== null) {
        db()->prepare('DELETE FROM auth_tokens WHERE token_hash = ?')->execute([hash('sha256', $token)]);
    }
    return ['ok' => true];
}

function auth_me(): array
{
    $u = require_user();
    return ['user' => ['id' => $u['id'], 'email' => $u['email'], 'is_admin' => (bool) $u['is_admin'],
        'email_verified' => (bool) $u['email_verified']]];
}
