<?php
// Pannello del gestore della piattaforma (app SfascioHub Admin): account, piazzali, costi AI.
declare(strict_types=1);

function month_start(): string
{
    return gmdate('Y-m-01 00:00:00');
}

/** Spesa AI raggruppata per una colonna (yard_id o user_id): totale, mese, oggi. */
function ai_costs_by(string $column): array
{
    $sql = "SELECT $column k,
                   COUNT(*) n, SUM(input_tokens) i, SUM(output_tokens) o,
                   SUM(CASE WHEN used_at >= ? THEN 1 ELSE 0 END) n_month,
                   SUM(CASE WHEN used_at >= ? THEN input_tokens ELSE 0 END) i_month,
                   SUM(CASE WHEN used_at >= ? THEN output_tokens ELSE 0 END) o_month,
                   SUM(CASE WHEN used_at >= ? THEN 1 ELSE 0 END) n_today,
                   MAX(used_at) last_used
            FROM ai_usage GROUP BY $column";
    $st = db()->prepare($sql);
    $today = gmdate('Y-m-d 00:00:00');
    $st->execute([month_start(), month_start(), month_start(), $today]);
    $out = [];
    foreach ($st->fetchAll() as $r) {
        $out[$r['k']] = [
            'analyses' => (int) $r['n'],
            'analyses_month' => (int) $r['n_month'],
            'analyses_today' => (int) $r['n_today'],
            'cost_usd' => ai_cost($r['i'], $r['o']),
            'cost_month_usd' => ai_cost($r['i_month'], $r['o_month']),
            'last_used' => $r['last_used'],
        ];
    }
    return $out;
}

function no_cost(): array
{
    return ['analyses' => 0, 'analyses_month' => 0, 'analyses_today' => 0, 'cost_usd' => 0, 'cost_month_usd' => 0, 'last_used' => null];
}

function admin_overview(): array
{
    require_admin();
    $count = fn(string $sql) => (int) db()->query($sql)->fetchColumn();
    $totals = no_cost();
    foreach (ai_costs_by('yard_id') as $c) {
        foreach (['analyses', 'analyses_month', 'analyses_today', 'cost_usd', 'cost_month_usd'] as $k) {
            $totals[$k] += $c[$k];
        }
    }
    $totals['cost_usd'] = round($totals['cost_usd'], 4);
    $totals['cost_month_usd'] = round($totals['cost_month_usd'], 4);
    unset($totals['last_used']);

    // medie del mese: tempo di risposta, errori, costo per richiesta e per immagine
    $st = db()->prepare("SELECT COUNT(*) n,
                                SUM(CASE WHEN status = 'ok' THEN 1 ELSE 0 END) ok,
                                SUM(CASE WHEN status <> 'ok' THEN 1 ELSE 0 END) failed,
                                AVG(CASE WHEN status = 'ok' THEN duration_ms END) avg_ms,
                                MAX(duration_ms) max_ms,
                                SUM(images) images,
                                SUM(input_tokens) i, SUM(output_tokens) o,
                                SUM(CASE WHEN kind = 'photos' THEN 1 ELSE 0 END) n_photos,
                                SUM(CASE WHEN kind = 'photos' THEN images ELSE 0 END) img_photos,
                                SUM(CASE WHEN kind = 'photos' THEN input_tokens ELSE 0 END) i_photos,
                                SUM(CASE WHEN kind = 'photos' THEN output_tokens ELSE 0 END) o_photos,
                                SUM(CASE WHEN kind = 'parts' THEN 1 ELSE 0 END) n_parts,
                                SUM(CASE WHEN kind = 'parts' THEN input_tokens ELSE 0 END) i_parts,
                                SUM(CASE WHEN kind = 'parts' THEN output_tokens ELSE 0 END) o_parts
                         FROM ai_usage WHERE used_at >= ?");
    $st->execute([month_start()]);
    $m = $st->fetch();
    $n = (int) $m['n'];
    $photosCost = ai_cost($m['i_photos'] ?? 0, $m['o_photos'] ?? 0);
    $stats = [
        'requests' => $n,
        'failed' => (int) $m['failed'],
        'error_rate' => $n ? round($m['failed'] / $n, 3) : 0,
        'avg_seconds' => $m['avg_ms'] === null ? null : round($m['avg_ms'] / 1000, 1),
        'max_seconds' => round(((int) $m['max_ms']) / 1000, 1),
        'avg_cost_request' => $n ? round(ai_cost($m['i'] ?? 0, $m['o'] ?? 0) / $n, 5) : 0,
        'avg_cost_photo_request' => $m['n_photos'] ? round($photosCost / $m['n_photos'], 5) : 0,
        'avg_cost_image' => $m['img_photos'] ? round($photosCost / $m['img_photos'], 5) : 0,
        'avg_images' => $m['n_photos'] ? round($m['img_photos'] / $m['n_photos'], 1) : 0,
        'avg_cost_parts' => $m['n_parts'] ? round(ai_cost($m['i_parts'] ?? 0, $m['o_parts'] ?? 0) / $m['n_parts'], 5) : 0,
    ];

    // ultimi 30 giorni, per il grafico
    $st = db()->prepare('SELECT SUBSTR(used_at, 1, 10) d, COUNT(*) n, SUM(input_tokens) i, SUM(output_tokens) o
                         FROM ai_usage WHERE used_at >= ? GROUP BY SUBSTR(used_at, 1, 10) ORDER BY d');
    $st->execute([gmdate('Y-m-d 00:00:00', time() - 29 * 86400)]);
    $days = array_map(fn($r) => ['day' => $r['d'], 'analyses' => (int) $r['n'], 'cost_usd' => ai_cost($r['i'], $r['o'])], $st->fetchAll());

    return [
        'yards' => $count('SELECT COUNT(*) FROM yards'),
        'users' => $count('SELECT COUNT(*) FROM users'),
        'vehicles' => $count('SELECT COUNT(*) FROM vehicles'),
        'photos' => $count('SELECT COUNT(*) FROM vehicle_photos'),
        'ai' => $totals + ['enabled' => ai_key() !== '', 'default_daily_limit' => (int) (config()['ai_daily_limit'] ?? AI_DAILY_LIMIT)],
        'days' => $days,
        'month' => $stats,
    ];
}

/** Elenco delle singole richieste all'AI, le più recenti prima. Filtri: yard_id, kind, status=failed. */
function admin_requests(): array
{
    require_admin();
    $where = ['1 = 1'];
    $args = [];
    if (($y = (string) ($_GET['yard_id'] ?? '')) !== '') {
        $where[] = 'a.yard_id = ?';
        $args[] = $y;
    }
    if (in_array($k = (string) ($_GET['kind'] ?? ''), ['photos', 'parts'], true)) {
        $where[] = 'a.kind = ?';
        $args[] = $k;
    }
    if (($_GET['status'] ?? '') === 'failed') {
        $where[] = "a.status <> 'ok'";
    }
    $limit = max(1, min(500, (int) ($_GET['limit'] ?? 200)));
    $st = db()->prepare('SELECT a.*, y.name yard_name, u.email, v.make, v.model
                         FROM ai_usage a LEFT JOIN yards y ON y.id = a.yard_id LEFT JOIN users u ON u.id = a.user_id
                         LEFT JOIN vehicles v ON v.id = a.vehicle_id
                         WHERE ' . implode(' AND ', $where) . " ORDER BY a.used_at DESC LIMIT $limit");
    $st->execute($args);
    return array_map(function ($r) {
        $cost = ai_cost($r['input_tokens'], $r['output_tokens']);
        $images = (int) $r['images'];
        return [
            'at' => $r['used_at'],
            'kind' => $r['kind'],
            'yard_name' => $r['yard_name'],
            'email' => $r['email'],
            'vehicle' => trim(($r['make'] ?? '') . ' ' . ($r['model'] ?? '')),
            'images' => $images,
            'input_tokens' => (int) $r['input_tokens'],
            'output_tokens' => (int) $r['output_tokens'],
            'cost_usd' => $cost,
            'cost_per_image_usd' => $images ? round($cost / $images, 5) : null,
            'seconds' => round(((int) $r['duration_ms']) / 1000, 1),
            'status' => $r['status'],
            'error' => $r['error'],
        ];
    }, $st->fetchAll());
}

function admin_yards(): array
{
    require_admin();
    $costs = ai_costs_by('yard_id');
    $rows = db()->query('SELECT y.*, u.email owner_email,
                                (SELECT COUNT(*) FROM vehicles v WHERE v.yard_id = y.id) vehicles
                         FROM yards y LEFT JOIN users u ON u.id = y.owner_id ORDER BY y.created_at DESC')->fetchAll();
    return array_map(fn($y) => [
        'id' => $y['id'],
        'name' => $y['name'],
        'city' => $y['city'],
        'province' => $y['province'],
        'phone' => $y['phone'],
        'owner_email' => $y['owner_email'],
        'published' => (bool) $y['published'],
        'vehicles' => (int) $y['vehicles'],
        'ai_daily_limit' => $y['ai_daily_limit'] === null ? null : (int) $y['ai_daily_limit'],
        'created_at' => $y['created_at'],
        'ai' => $costs[$y['id']] ?? no_cost(),
    ], $rows);
}

function admin_update_yard(string $id): array
{
    require_admin();
    $b = body();
    $st = db()->prepare('SELECT id FROM yards WHERE id = ?');
    $st->execute([$id]);
    $st->fetchColumn() ?: throw new HttpError(404, 'Piazzale non trovato.');
    if (array_key_exists('ai_daily_limit', $b)) {
        $limit = $b['ai_daily_limit'] === null ? null : max(0, min(1000, (int) $b['ai_daily_limit']));
        db()->prepare('UPDATE yards SET ai_daily_limit = ? WHERE id = ?')->execute([$limit, $id]);
    }
    if (array_key_exists('published', $b)) {
        db()->prepare('UPDATE yards SET published = ? WHERE id = ?')->execute([$b['published'] ? 1 : 0, $id]);
    }
    return ['ok' => true];
}

function admin_users(): array
{
    $me = require_admin();
    $costs = ai_costs_by('user_id');
    $admins = admin_emails();
    $rows = db()->query('SELECT u.id, u.email, u.is_admin, u.disabled, u.created_at,
                                (SELECT y.name FROM yard_members m JOIN yards y ON y.id = m.yard_id WHERE m.user_id = u.id ORDER BY y.created_at LIMIT 1) yard_name,
                                (SELECT m.yard_id FROM yard_members m WHERE m.user_id = u.id LIMIT 1) yard_id,
                                (SELECT MAX(t.created_at) FROM auth_tokens t WHERE t.user_id = u.id) last_login
                         FROM users u ORDER BY u.created_at DESC')->fetchAll();
    return array_map(fn($u) => [
        'id' => $u['id'],
        'email' => $u['email'],
        'is_admin' => $u['is_admin'] || in_array($u['email'], $admins, true),
        'admin_from_file' => in_array($u['email'], $admins, true),
        'disabled' => (bool) $u['disabled'],
        'is_me' => $u['id'] === $me['id'],
        'created_at' => $u['created_at'],
        'last_login' => $u['last_login'],
        'yard_id' => $u['yard_id'],
        'yard_name' => $u['yard_name'],
        'ai' => $costs[$u['id']] ?? no_cost(),
    ], $rows);
}

function random_password(): string
{
    // facile da dettare al telefono: niente 0/O, 1/l
    $chars = 'abcdefghjkmnpqrstuvwxyz23456789';
    $p = '';
    for ($i = 0; $i < 10; $i++) {
        $p .= $chars[random_int(0, strlen($chars) - 1)];
    }
    return $p;
}

/** Crea un account (e se richiesto il suo piazzale) per qualcuno. Ritorna la password da consegnare. */
function admin_create_user(): array
{
    require_admin();
    $b = body();
    $email = normalize_email($b);
    $st = db()->prepare('SELECT 1 FROM users WHERE email = ?');
    $st->execute([$email]);
    if ($st->fetchColumn()) {
        throw new HttpError(409, 'Esiste già un account con questa email.');
    }
    $password = trim((string) ($b['password'] ?? '')) ?: random_password();
    if (strlen($password) < 8) {
        throw new HttpError(422, 'La password deve avere almeno 8 caratteri.');
    }
    $yardName = str_field($b, 'yard_name', 80);

    $pdo = db();
    $pdo->beginTransaction();
    $id = uuid();
    $pdo->prepare('INSERT INTO users (id, email, password_hash, is_admin, created_at) VALUES (?, ?, ?, ?, ?)')
        ->execute([$id, $email, password_hash($password, PASSWORD_DEFAULT), empty($b['is_admin']) ? 0 : 1, now()]);
    $yardId = null;
    if ($yardName !== '') {
        $yardId = uuid();
        $pdo->prepare('INSERT INTO yards (id, owner_id, name, city, province, phone, published, ai_daily_limit, created_at)
                       VALUES (?, ?, ?, ?, ?, ?, 1, ?, ?)')
            ->execute([$yardId, $id, $yardName, str_field($b, 'city', 80), strtoupper(str_field($b, 'province', 2)),
                str_field($b, 'phone', 40), isset($b['ai_daily_limit']) ? max(0, (int) $b['ai_daily_limit']) : null, now()]);
        $pdo->prepare("INSERT INTO yard_members (yard_id, user_id, role) VALUES (?, ?, 'owner')")->execute([$yardId, $id]);
    }
    $pdo->commit();
    return ['id' => $id, 'email' => $email, 'password' => $password, 'yard_id' => $yardId];
}

function admin_update_user(string $id): array
{
    $me = require_admin();
    $b = body();
    $st = db()->prepare('SELECT id FROM users WHERE id = ?');
    $st->execute([$id]);
    $st->fetchColumn() ?: throw new HttpError(404, 'Account non trovato.');
    $out = ['ok' => true];

    if (array_key_exists('disabled', $b)) {
        if ($id === $me['id'] && $b['disabled']) {
            throw new HttpError(422, 'Non puoi sospendere il tuo account.');
        }
        db()->prepare('UPDATE users SET disabled = ? WHERE id = ?')->execute([$b['disabled'] ? 1 : 0, $id]);
        if ($b['disabled']) {
            db()->prepare('DELETE FROM auth_tokens WHERE user_id = ?')->execute([$id]); // esce subito da tutte le app
        }
    }
    if (array_key_exists('is_admin', $b)) {
        if ($id === $me['id'] && !$b['is_admin']) {
            throw new HttpError(422, 'Non puoi togliere a te stesso il ruolo di admin.');
        }
        db()->prepare('UPDATE users SET is_admin = ? WHERE id = ?')->execute([$b['is_admin'] ? 1 : 0, $id]);
    }
    if (!empty($b['reset_password'])) {
        $password = random_password();
        db()->prepare('UPDATE users SET password_hash = ? WHERE id = ?')->execute([password_hash($password, PASSWORD_DEFAULT), $id]);
        db()->prepare('DELETE FROM auth_tokens WHERE user_id = ?')->execute([$id]);
        $out['password'] = $password;
    }
    return $out;
}
