<?php
// Pagine aperte dai link nelle email: conferma dell'indirizzo e nuova password.
//   account.php?verify=<token>   conferma l'email
//   account.php?reset=<token>    modulo per la nuova password
declare(strict_types=1);

require __DIR__ . '/lib/bootstrap.php';
require __DIR__ . '/lib/auth.php';
require __DIR__ . '/lib/schema.php';
require __DIR__ . '/lib/account.php';

header('Content-Type: text/html; charset=utf-8');
header('Cache-Control: no-store');
header('Referrer-Policy: no-referrer');
header("Content-Security-Policy: default-src 'none'; style-src 'unsafe-inline'; form-action 'self'");

function page(string $title, string $body): never
{
    $t = htmlspecialchars($title);
    echo <<<HTML
<!doctype html>
<html lang="it"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex"><title>$t · SfascioHub</title>
<style>
  body{margin:0;min-height:100vh;display:grid;place-items:center;background:#0F1A1C;color:#EAF2EF;font:16px/1.5 system-ui,-apple-system,"Segoe UI",sans-serif;padding:16px;box-sizing:border-box}
  main{width:100%;max-width:400px;background:#16262A;border:1px solid #2A4045;border-radius:20px;padding:28px}
  h1{font-size:22px;margin:0 0 8px} p{color:#8FA6A2;margin:0 0 16px}
  .logo{width:44px;height:44px;border-radius:12px;background:#F26B1D;display:grid;place-items:center;font-weight:800;margin-bottom:16px}
  label{display:block;font-size:14px;margin:12px 0 6px;color:#8FA6A2}
  input{width:100%;box-sizing:border-box;padding:13px 14px;border-radius:12px;border:1px solid #2A4045;background:#1E3338;color:#EAF2EF;font-size:16px}
  button{margin-top:20px;width:100%;padding:14px;border:0;border-radius:14px;background:#F26B1D;color:#fff;font-size:16px;font-weight:700}
  .err{color:#FF8A75} .ok{color:#5FD3A1}
</style></head>
<body><main><div class="logo">S</div><h1>$t</h1>$body</main></body></html>
HTML;
    exit;
}

try {
    // ---- conferma email ----
    if (isset($_GET['verify'])) {
        $token = (string) $_GET['verify'];
        $u = email_token_user($token, 'verify');
        if (!$u) {
            page('Link non valido', '<p>Il link è scaduto o è già stato usato. Se il tuo indirizzo non è ancora confermato, '
                . 'dall\'app puoi farti mandare un\'altra email.</p>');
        }
        db()->prepare('UPDATE users SET email_verified = 1 WHERE id = ?')->execute([$u['id']]);
        drop_email_token($token);
        page('Email confermata', '<p class="ok">Grazie! L\'indirizzo <b>' . htmlspecialchars($u['email']) . '</b> è confermato.</p>'
            . '<p>Puoi tornare all\'app.</p>');
    }

    // ---- nuova password ----
    $token = (string) ($_POST['reset'] ?? $_GET['reset'] ?? '');
    if ($token === '') {
        page('SfascioHub', '<p>Apri il link che hai ricevuto per email.</p>');
    }
    $u = email_token_user($token, 'reset');
    if (!$u) {
        page('Link non valido', '<p>Il link è scaduto o è già stato usato. Dall\'app tocca di nuovo "Password dimenticata?" '
            . 'per riceverne uno nuovo.</p>');
    }
    $error = '';
    if (($_SERVER['REQUEST_METHOD'] ?? '') === 'POST') {
        $p1 = (string) ($_POST['password'] ?? '');
        $p2 = (string) ($_POST['password2'] ?? '');
        if (strlen($p1) < 8) {
            $error = 'La password deve avere almeno 8 caratteri.';
        } elseif ($p1 !== $p2) {
            $error = 'Le due password non coincidono.';
        } else {
            db()->prepare('UPDATE users SET password_hash = ?, email_verified = 1 WHERE id = ?')
                ->execute([password_hash($p1, PASSWORD_DEFAULT), $u['id']]);
            // esce da tutti i dispositivi: chi aveva la password vecchia non resta dentro
            db()->prepare('DELETE FROM auth_tokens WHERE user_id = ?')->execute([$u['id']]);
            drop_email_token($token);
            page('Password cambiata', '<p class="ok">Fatto! Ora accedi all\'app con la nuova password.</p>');
        }
    }
    $t = htmlspecialchars($token);
    page('Nuova password', '<p>Account <b>' . htmlspecialchars($u['email']) . '</b></p>'
        . ($error ? '<p class="err">' . htmlspecialchars($error) . '</p>' : '')
        . '<form method="post" action="account.php"><input type="hidden" name="reset" value="' . $t . '">'
        . '<label for="p1">Nuova password (almeno 8 caratteri)</label>'
        . '<input id="p1" name="password" type="password" minlength="8" required autocomplete="new-password">'
        . '<label for="p2">Ripeti la password</label>'
        . '<input id="p2" name="password2" type="password" minlength="8" required autocomplete="new-password">'
        . '<button type="submit">Salva la password</button></form>');
} catch (Throwable $e) {
    error_log('[sfasciohub] account.php: ' . $e);
    page('Errore', '<p class="err">Qualcosa non ha funzionato. Riprova tra poco.</p>');
}
