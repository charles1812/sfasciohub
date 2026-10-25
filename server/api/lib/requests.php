<?php
// Profilo dei clienti, richieste di disponibilità dei ricambi (cliente → piazzale → risposta) e auto preferite.
declare(strict_types=1);

const REQUESTS_PER_DAY = 30;   // per cliente
const REQUEST_STATUSES = ['open', 'available', 'unavailable'];

function profile_out(array $u): array
{
    $st = db()->prepare('SELECT name, phone, (SELECT COUNT(*) FROM yard_members m WHERE m.user_id = users.id) yards FROM users WHERE id = ?');
    $st->execute([$u['id']]);
    $p = $st->fetch() ?: ['name' => '', 'phone' => '', 'yards' => 0];
    return ['name' => (string) $p['name'], 'phone' => (string) $p['phone'], 'has_yard' => (int) $p['yards'] > 0];
}

/** PUT /me/profile  {"name": "...", "phone": "..."} */
function update_profile(): array
{
    $u = require_user();
    $b = body();
    db()->prepare('UPDATE users SET name = ?, phone = ? WHERE id = ?')
        ->execute([str_field($b, 'name', 80), str_field($b, 'phone', 40), $u['id']]);
    return profile_out($u);
}

function request_out(array $r): array
{
    return [
        'id' => $r['id'],
        'vehicle_id' => $r['vehicle_id'],
        'vehicle' => trim(($r['make'] ?? '') . ' ' . ($r['model'] ?? '') . ($r['year'] ? ' ' . $r['year'] : '')),
        'yard_id' => $r['yard_id'],
        'yard_name' => $r['yard_name'] ?? '',
        'part' => $r['part_text'],
        'part_id' => $r['part_id'],
        'note' => $r['note'] ?? '',
        'status' => $r['status'],
        'reply' => $r['reply'] ?? '',
        'price' => $r['price'],
        'created_at' => $r['created_at'],
        'replied_at' => $r['replied_at'],
        'customer' => isset($r['c_email']) ? ['name' => $r['c_name'], 'phone' => $r['c_phone'], 'email' => $r['c_email']] : null,
    ];
}

const REQUEST_SELECT = 'SELECT r.*, v.make, v.model, v.year, y.name yard_name, u.name c_name, u.phone c_phone, u.email c_email
                        FROM part_requests r
                        JOIN yards y ON y.id = r.yard_id
                        JOIN users u ON u.id = r.customer_id
                        LEFT JOIN vehicles v ON v.id = r.vehicle_id';

/** POST /requests  {"vehicle_id", "part", "part_id"?, "note"?, "name", "phone"} */
function create_request(): array
{
    $u = require_user();
    $b = body();
    $part = str_field($b, 'part', 160, true, 'Il pezzo');
    $name = str_field($b, 'name', 80, true, 'Il nome');
    $phone = str_field($b, 'phone', 40, true, 'Il telefono');
    if (strlen(preg_replace('/\D/', '', $phone)) < 6) {
        throw new HttpError(422, 'Scrivi un numero di telefono valido: serve al piazzale per risponderti.');
    }
    $st = db()->prepare("SELECT v.id, v.yard_id, v.make, v.model, v.year, y.name yard_name, y.email yard_email, o.email owner_email
                         FROM vehicles v JOIN yards y ON y.id = v.yard_id LEFT JOIN users o ON o.id = y.owner_id
                         WHERE v.id = ? AND v.published = 1 AND y.published = 1 AND y.approved = 1");
    $st->execute([(string) ($b['vehicle_id'] ?? '')]);
    $v = $st->fetch() ?: throw new HttpError(404, 'Auto non trovata.');
    if (is_member($v['yard_id'], $u['id'])) {
        throw new HttpError(422, 'Questa è un\'auto del tuo piazzale.');
    }
    $st = db()->prepare('SELECT COUNT(*) FROM part_requests WHERE customer_id = ? AND created_at >= ?');
    $st->execute([$u['id'], gmdate('Y-m-d H:i:s', time() - 86400)]);
    if ((int) $st->fetchColumn() >= REQUESTS_PER_DAY) {
        throw new HttpError(429, 'Hai mandato molte richieste oggi. Riprova domani.');
    }
    // nome e telefono restano nel profilo per le prossime richieste
    db()->prepare('UPDATE users SET name = ?, phone = ? WHERE id = ?')->execute([$name, $phone, $u['id']]);
    $id = uuid();
    $partId = preg_match('/^[a-z0-9_]{1,40}$/', (string) ($b['part_id'] ?? '')) ? $b['part_id'] : null;
    db()->prepare("INSERT INTO part_requests (id, yard_id, vehicle_id, customer_id, part_text, part_id, note, status, created_at)
                   VALUES (?, ?, ?, ?, ?, ?, ?, 'open', ?)")
        ->execute([$id, $v['yard_id'], $v['id'], $u['id'], $part, $partId, str_field($b, 'note', 500), now()]);

    $car = trim("{$v['make']} {$v['model']}" . ($v['year'] ? " {$v['year']}" : ''));
    $to = $v['yard_email'] ?: $v['owner_email'];
    if ($to) {
        send_mail($to, "Richiesta: $part ($car)", "Un cliente chiede se avete questo ricambio.\n\n"
            . "Pezzo: $part\nAuto: $car\nCliente: $name · $phone\n"
            . (trim((string) ($b['note'] ?? '')) !== '' ? 'Nota: ' . trim((string) $b['note']) . "\n" : '')
            . "\nRispondi dall'app SfascioHub Gestione, scheda Richieste: il cliente riceve la risposta nell'app e per email.");
    }
    $st = db()->prepare(REQUEST_SELECT . ' WHERE r.id = ?');
    $st->execute([$id]);
    return request_out($st->fetch());
}

/** GET /me/requests: le richieste che ho mandato io (cliente). */
function my_requests(): array
{
    $u = require_user();
    $st = db()->prepare(REQUEST_SELECT . ' WHERE r.customer_id = ? ORDER BY r.created_at DESC LIMIT 200');
    $st->execute([$u['id']]);
    return array_map(function ($r) {
        $out = request_out($r);
        unset($out['customer']);
        return $out;
    }, $st->fetchAll());
}

/** GET /me/yard/requests: le richieste arrivate al mio piazzale. */
function yard_requests(): array
{
    $y = require_my_yard(require_user());
    $st = db()->prepare(REQUEST_SELECT . " WHERE r.yard_id = ? ORDER BY CASE WHEN r.status = 'open' THEN 0 ELSE 1 END, r.created_at DESC LIMIT 300");
    $st->execute([$y['id']]);
    $rows = array_map('request_out', $st->fetchAll());
    return ['requests' => $rows, 'open' => count(array_filter($rows, fn($r) => $r['status'] === 'open'))];
}

/** PUT /me/yard/requests/{id}  {"status": "available"|"unavailable", "reply", "price"} */
function reply_request(string $id): array
{
    $y = require_my_yard(require_user());
    $b = body();
    $status = (string) ($b['status'] ?? '');
    if (!in_array($status, ['available', 'unavailable'], true)) {
        throw new HttpError(422, 'Scegli se il pezzo c\'è o non c\'è.');
    }
    $st = db()->prepare(REQUEST_SELECT . ' WHERE r.id = ? AND r.yard_id = ?');
    $st->execute([$id, $y['id']]);
    $r = $st->fetch() ?: throw new HttpError(404, 'Richiesta non trovata.');
    $reply = str_field($b, 'reply', 1000);
    $price = $status === 'available' ? str_field($b, 'price', 40) : '';
    db()->prepare('UPDATE part_requests SET status = ?, reply = ?, price = ?, replied_at = ? WHERE id = ?')
        ->execute([$status, $reply, $price === '' ? null : $price, now(), $id]);

    $car = trim(($r['make'] ?? '') . ' ' . ($r['model'] ?? ''));
    $text = $status === 'available'
        ? "Buone notizie: {$y['name']} ha il pezzo che hai chiesto.\n\nPezzo: {$r['part_text']}" . ($car ? " ($car)" : '')
            . ($price !== '' ? "\nPrezzo: $price" : '')
        : "{$y['name']} ha risposto: purtroppo il pezzo non è disponibile.\n\nPezzo: {$r['part_text']}" . ($car ? " ($car)" : '');
    if ($reply !== '') {
        $text .= "\n\nMessaggio del piazzale: $reply";
    }
    $contact = array_filter([$y['phone'] ? "Telefono: {$y['phone']}" : '', $y['whatsapp'] ? "WhatsApp: {$y['whatsapp']}" : '']);
    send_mail($r['c_email'], $status === 'available' ? "Il pezzo c'è: {$r['part_text']}" : "Risposta su: {$r['part_text']}",
        $text . ($contact ? "\n\n" . implode("\n", $contact) : '') . "\n\nTrovi tutte le risposte nell'app SfascioHub, scheda Profilo.\n\nSfascioHub");

    $st = db()->prepare(REQUEST_SELECT . ' WHERE r.id = ?');
    $st->execute([$id]);
    return request_out($st->fetch());
}

// ---------------------------------------------------------------------------
// Auto preferite
// ---------------------------------------------------------------------------

/** GET /me/favorites: le auto salvate (solo quelle ancora visibili). */
function my_favorites(): array
{
    $u = require_user();
    $st = db()->prepare('SELECT v.* FROM favorites f JOIN (' . PUBLIC_VEHICLES . ') v ON v.id = f.vehicle_id
                         WHERE f.user_id = ? ORDER BY f.created_at DESC');
    $st->execute([$u['id']]);
    return vehicles_out($st->fetchAll());
}

/** PUT /me/favorites/{id} salva, DELETE toglie. */
function set_favorite(string $vehicleId, bool $on): array
{
    $u = require_user();
    db()->prepare('DELETE FROM favorites WHERE user_id = ? AND vehicle_id = ?')->execute([$u['id'], $vehicleId]);
    if ($on) {
        $st = db()->prepare('SELECT 1 FROM vehicles WHERE id = ?');
        $st->execute([$vehicleId]);
        $st->fetchColumn() ?: throw new HttpError(404, 'Auto non trovata.');
        db()->prepare('INSERT INTO favorites (user_id, vehicle_id, created_at) VALUES (?, ?, ?)')->execute([$u['id'], $vehicleId, now()]);
    }
    return ['ok' => true, 'favorite' => $on];
}
