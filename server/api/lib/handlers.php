<?php
// Sfasciacarrozze, veicoli e foto.
declare(strict_types=1);

const MAX_PHOTO_BYTES = 8 * 1024 * 1024;
const MAX_PHOTOS = 20;

// ---------------------------------------------------------------------------
// Formato delle risposte (stesse chiavi che usa l'app Flutter)
// ---------------------------------------------------------------------------

function yard_out(array $y): array
{
    return [
        'id' => $y['id'],
        'owner_id' => $y['owner_id'],
        'name' => $y['name'],
        'city' => $y['city'],
        'province' => $y['province'],
        'address' => $y['address'],
        'phone' => $y['phone'],
        'whatsapp' => $y['whatsapp'],
        'email' => $y['email'],
        'hours' => $y['hours'],
        'description' => $y['description'] ?? '',
        'lat' => $y['lat'] === null ? null : (float) $y['lat'],
        'lng' => $y['lng'] === null ? null : (float) $y['lng'],
        'published' => (bool) $y['published'],
    ];
}

/** Veicoli con foto e sfasciacarrozze, in due query invece di N+1. */
function vehicles_out(array $rows): array
{
    if (!$rows) {
        return [];
    }
    $ids = array_column($rows, 'id');
    $in = implode(',', array_fill(0, count($ids), '?'));
    $st = db()->prepare("SELECT id, vehicle_id, file, position FROM vehicle_photos WHERE vehicle_id IN ($in) ORDER BY position, created_at");
    $st->execute($ids);
    $photos = [];
    $base = base_url() . '/uploads/';
    foreach ($st as $p) {
        $photos[$p['vehicle_id']][] = ['id' => $p['id'], 'url' => $base . $p['file'], 'position' => (int) $p['position']];
    }

    $yardIds = array_values(array_unique(array_column($rows, 'yard_id')));
    $in = implode(',', array_fill(0, count($yardIds), '?'));
    $st = db()->prepare("SELECT * FROM yards WHERE id IN ($in)");
    $st->execute($yardIds);
    $yards = [];
    foreach ($st as $y) {
        $yards[$y['id']] = yard_out($y);
    }

    return array_map(fn(array $v) => [
        'id' => $v['id'],
        'yard_id' => $v['yard_id'],
        'make' => $v['make'],
        'model' => $v['model'],
        'version' => $v['version'],
        'year' => $v['year'] === null ? null : (int) $v['year'],
        'fuel' => $v['fuel'],
        'color' => $v['color'],
        'km' => $v['km'] === null ? null : (int) $v['km'],
        'engine_code' => $v['engine_code'],
        'damage_zones' => $v['damage_zones'] === '' ? [] : explode(',', $v['damage_zones']),
        'notes' => $v['notes'] ?? '',
        'status' => $v['status'],
        'published' => (bool) $v['published'],
        'arrived_on' => substr((string) $v['arrived_on'], 0, 10),
        'created_at' => $v['created_at'],
        'vehicle_photos' => $photos[$v['id']] ?? [],
        'yards' => $yards[$v['yard_id']] ?? null,
    ], $rows);
}

// ---------------------------------------------------------------------------
// Pubblico
// ---------------------------------------------------------------------------

const PUBLIC_VEHICLES = "SELECT v.* FROM vehicles v JOIN yards y ON y.id = v.yard_id
                         WHERE v.published = 1 AND v.status <> 'gone' AND y.published = 1";

function public_vehicles(): array
{
    $sql = PUBLIC_VEHICLES;
    $args = [];
    if (!empty($_GET['yard_id'])) {
        $sql .= ' AND v.yard_id = ?';
        $args[] = (string) $_GET['yard_id'];
    }
    if (!empty($_GET['make'])) {
        $sql .= ' AND v.make = ?';
        $args[] = (string) $_GET['make'];
    }
    if (!empty($_GET['province'])) {
        $sql .= ' AND y.province = ?';
        $args[] = strtoupper((string) $_GET['province']);
    }
    if (isset($_GET['year_from']) && is_numeric($_GET['year_from'])) {
        $sql .= ' AND v.year >= ?';
        $args[] = (int) $_GET['year_from'];
    }
    if (isset($_GET['year_to']) && is_numeric($_GET['year_to'])) {
        $sql .= ' AND v.year <= ?';
        $args[] = (int) $_GET['year_to'];
    }
    $sql .= ' ORDER BY v.arrived_on DESC, v.created_at DESC LIMIT 1000';
    $st = db()->prepare($sql);
    $st->execute($args);
    return vehicles_out($st->fetchAll());
}

function public_vehicle(string $id): array
{
    $u = current_user();
    $st = db()->prepare('SELECT v.* FROM vehicles v JOIN yards y ON y.id = v.yard_id WHERE v.id = ?');
    $st->execute([$id]);
    $v = $st->fetch();
    if ($v && ($u === null || !is_member($v['yard_id'], $u['id']))) {
        $chk = db()->prepare(PUBLIC_VEHICLES . ' AND v.id = ?');
        $chk->execute([$id]);
        $v = $chk->fetch();
    }
    if (!$v) {
        throw new HttpError(404, 'Questo veicolo non è più disponibile.');
    }
    // la scheda singola porta anche la lista dei ricambi (se generata)
    return vehicles_out([$v])[0] + ['parts' => function_exists('parts_of') ? parts_of($id) : []];
}

function public_yards(): array
{
    return array_map('yard_out', db()->query('SELECT * FROM yards WHERE published = 1 ORDER BY name')->fetchAll());
}

function public_yard(string $id): array
{
    $st = db()->prepare('SELECT * FROM yards WHERE id = ? AND published = 1');
    $st->execute([$id]);
    return yard_out($st->fetch() ?: throw new HttpError(404, 'Sfasciacarrozze non trovato.'));
}

function public_counts(): array
{
    $rows = db()->query('SELECT v.yard_id, COUNT(*) AS n FROM (' . PUBLIC_VEHICLES . ') v GROUP BY v.yard_id')->fetchAll();
    $out = [];
    foreach ($rows as $r) {
        $out[$r['yard_id']] = (int) $r['n'];
    }
    return $out ?: (object) [];
}

// ---------------------------------------------------------------------------
// Il mio sfasciacarrozze
// ---------------------------------------------------------------------------

function is_member(string $yardId, string $userId): bool
{
    $st = db()->prepare('SELECT 1 FROM yard_members WHERE yard_id = ? AND user_id = ?');
    $st->execute([$yardId, $userId]);
    return (bool) $st->fetchColumn();
}

function my_yard_row(array $u): ?array
{
    $st = db()->prepare('SELECT y.* FROM yards y JOIN yard_members m ON m.yard_id = y.id WHERE m.user_id = ? ORDER BY y.created_at LIMIT 1');
    $st->execute([$u['id']]);
    return $st->fetch() ?: null;
}

function require_my_yard(array $u): array
{
    return my_yard_row($u) ?? throw new HttpError(404, 'Crea prima il tuo sfasciacarrozze.');
}

function yard_fields(array $b): array
{
    $name = str_field($b, 'name', 80, true, 'Il nome');
    if (mb_strlen($name) < 2) {
        throw new HttpError(422, 'Il nome è troppo corto.');
    }
    $lat = $b['lat'] ?? null;
    $lng = $b['lng'] ?? null;
    return [
        'name' => $name,
        'city' => str_field($b, 'city', 80),
        'province' => strtoupper(str_field($b, 'province', 2)),
        'address' => str_field($b, 'address', 160),
        'phone' => str_field($b, 'phone', 40),
        'whatsapp' => str_field($b, 'whatsapp', 40),
        'email' => str_field($b, 'email', 190),
        'hours' => str_field($b, 'hours', 160),
        'description' => str_field($b, 'description', 2000),
        'lat' => is_numeric($lat) ? (float) $lat : null,
        'lng' => is_numeric($lng) ? (float) $lng : null,
        'published' => array_key_exists('published', $b) ? (int) (bool) $b['published'] : 1,
    ];
}

function my_yard(): ?array
{
    $y = my_yard_row(require_user());
    return $y ? yard_out($y) : null;
}

function create_my_yard(): array
{
    $u = require_user();
    if (my_yard_row($u)) {
        throw new HttpError(409, 'Hai già uno sfasciacarrozze.');
    }
    $f = yard_fields(body());
    $id = uuid();
    $pdo = db();
    $pdo->beginTransaction();
    $pdo->prepare('INSERT INTO yards (id, owner_id, name, city, province, address, phone, whatsapp, email, hours, description, lat, lng, published, created_at)
                   VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)')
        ->execute([$id, $u['id'], ...array_values($f), now()]);
    $pdo->prepare("INSERT INTO yard_members (yard_id, user_id, role) VALUES (?, ?, 'owner')")->execute([$id, $u['id']]);
    $pdo->commit();
    return yard_out(require_my_yard($u));
}

function update_my_yard(): array
{
    $u = require_user();
    $y = require_my_yard($u);
    $f = yard_fields(body());
    $set = implode(', ', array_map(fn($k) => "$k = ?", array_keys($f)));
    db()->prepare("UPDATE yards SET $set WHERE id = ?")->execute([...array_values($f), $y['id']]);
    return yard_out(require_my_yard($u));
}

function my_vehicles(): array
{
    $y = require_my_yard(require_user());
    $st = db()->prepare('SELECT * FROM vehicles WHERE yard_id = ? ORDER BY arrived_on DESC, created_at DESC');
    $st->execute([$y['id']]);
    return vehicles_out($st->fetchAll());
}

/** Crea o aggiorna un veicolo del proprio piazzale (l'id lo genera l'app). */
function save_my_vehicle(string $id): array
{
    if (!preg_match('/^[0-9a-f-]{36}$/i', $id)) {
        throw new HttpError(400, 'Identificativo non valido.');
    }
    $u = require_user();
    $y = require_my_yard($u);
    $b = body();

    $st = db()->prepare('SELECT yard_id FROM vehicles WHERE id = ?');
    $st->execute([$id]);
    $existing = $st->fetchColumn();
    if ($existing !== false && $existing !== $y['id']) {
        throw new HttpError(403, 'Questo veicolo appartiene a un altro sfasciacarrozze.');
    }

    $zones = array_values(array_unique(array_filter((array) ($b['damage_zones'] ?? []), fn($z) => in_array($z, DAMAGE_ZONES, true))));
    $fuel = (string) ($b['fuel'] ?? '');
    $status = (string) ($b['status'] ?? 'available');
    $arrived = (string) ($b['arrived_on'] ?? '');
    if (!preg_match('/^\d{4}-\d{2}-\d{2}$/', $arrived)) {
        $arrived = gmdate('Y-m-d');
    }
    $f = [
        'make' => str_field($b, 'make', 40, true, 'La marca'),
        'model' => str_field($b, 'model', 60, true, 'Il modello'),
        'version' => str_field($b, 'version', 80),
        'year' => int_field($b, 'year', 1950, (int) gmdate('Y') + 1),
        'fuel' => in_array($fuel, FUELS, true) ? $fuel : '',
        'color' => str_field($b, 'color', 40),
        'km' => int_field($b, 'km', 0, 3_000_000),
        'engine_code' => strtoupper(str_field($b, 'engine_code', 30)),
        'damage_zones' => implode(',', $zones),
        'notes' => str_field($b, 'notes', 4000),
        'status' => in_array($status, STATUSES, true) ? $status : 'available',
        'published' => (int) (bool) ($b['published'] ?? true),
        'arrived_on' => $arrived,
    ];

    if ($existing === false) {
        $cols = implode(', ', array_keys($f));
        $marks = implode(', ', array_fill(0, count($f), '?'));
        db()->prepare("INSERT INTO vehicles (id, yard_id, $cols, created_at, updated_at) VALUES (?, ?, $marks, ?, ?)")
            ->execute([$id, $y['id'], ...array_values($f), now(), now()]);
    } else {
        $set = implode(', ', array_map(fn($k) => "$k = ?", array_keys($f)));
        db()->prepare("UPDATE vehicles SET $set, updated_at = ? WHERE id = ?")->execute([...array_values($f), now(), $id]);
    }
    return public_vehicle($id);
}

function own_vehicle(string $id, array $u): array
{
    $st = db()->prepare('SELECT v.* FROM vehicles v JOIN yard_members m ON m.yard_id = v.yard_id WHERE v.id = ? AND m.user_id = ?');
    $st->execute([$id, $u['id']]);
    return $st->fetch() ?: throw new HttpError(404, 'Veicolo non trovato nel tuo piazzale.');
}

function delete_my_vehicle(string $id): array
{
    $u = require_user();
    own_vehicle($id, $u);
    $st = db()->prepare('SELECT file FROM vehicle_photos WHERE vehicle_id = ?');
    $st->execute([$id]);
    foreach ($st->fetchAll(PDO::FETCH_COLUMN) as $file) {
        remove_upload($file);
    }
    db()->prepare('DELETE FROM vehicle_photos WHERE vehicle_id = ?')->execute([$id]);
    db()->prepare('DELETE FROM vehicles WHERE id = ?')->execute([$id]);
    return ['ok' => true];
}

/** Carica una foto: corpo della richiesta = immagine JPEG/PNG/WebP. */
function add_photo(string $vehicleId): array
{
    $u = require_user();
    $v = own_vehicle($vehicleId, $u);

    $st = db()->prepare('SELECT COUNT(*) FROM vehicle_photos WHERE vehicle_id = ?');
    $st->execute([$vehicleId]);
    if ((int) $st->fetchColumn() >= MAX_PHOTOS) {
        throw new HttpError(422, 'Massimo ' . MAX_PHOTOS . ' foto per veicolo.');
    }

    $data = file_get_contents('php://input', false, null, 0, MAX_PHOTO_BYTES + 1) ?: '';
    if ($data === '' && !empty($_FILES['photo']['tmp_name'])) {
        $data = file_get_contents($_FILES['photo']['tmp_name']) ?: '';
    }
    if ($data === '') {
        throw new HttpError(400, 'Nessuna immagine ricevuta.');
    }
    if (strlen($data) > MAX_PHOTO_BYTES) {
        throw new HttpError(413, 'La foto è troppo grande (max 8 MB).');
    }
    $info = @getimagesizefromstring($data);
    $ext = match ($info['mime'] ?? '') {
        'image/jpeg' => 'jpg',
        'image/png' => 'png',
        'image/webp' => 'webp',
        default => throw new HttpError(415, 'Formato non supportato: usa JPEG, PNG o WebP.'),
    };

    $dir = uploads_dir() . '/' . $v['yard_id'];
    if (!is_dir($dir) && !mkdir($dir, 0755, true)) {
        throw new HttpError(500, 'Impossibile salvare la foto sul server.');
    }
    $name = $v['yard_id'] . '/' . bin2hex(random_bytes(12)) . '.' . $ext;
    if (file_put_contents(uploads_dir() . '/' . $name, $data) === false) {
        throw new HttpError(500, 'Impossibile salvare la foto sul server.');
    }

    $position = isset($_GET['position']) && is_numeric($_GET['position']) ? (int) $_GET['position'] : 0;
    $id = uuid();
    db()->prepare('INSERT INTO vehicle_photos (id, vehicle_id, file, position, created_at) VALUES (?, ?, ?, ?, ?)')
        ->execute([$id, $vehicleId, $name, $position, now()]);
    db()->prepare('UPDATE vehicles SET updated_at = ? WHERE id = ?')->execute([now(), $vehicleId]);
    return ['id' => $id, 'url' => base_url() . '/uploads/' . $name, 'position' => $position];
}

function delete_photo(string $photoId): array
{
    $u = require_user();
    $st = db()->prepare('SELECT p.id, p.file FROM vehicle_photos p JOIN vehicles v ON v.id = p.vehicle_id
                         JOIN yard_members m ON m.yard_id = v.yard_id WHERE p.id = ? AND m.user_id = ?');
    $st->execute([$photoId, $u['id']]);
    $p = $st->fetch() ?: throw new HttpError(404, 'Foto non trovata.');
    remove_upload($p['file']);
    db()->prepare('DELETE FROM vehicle_photos WHERE id = ?')->execute([$photoId]);
    return ['ok' => true];
}

/** Cancella un file caricato, solo se sta davvero dentro uploads/. */
function remove_upload(string $file): void
{
    $root = realpath(uploads_dir());
    $path = realpath(uploads_dir() . '/' . $file);
    if ($root !== false && $path !== false && str_starts_with($path, $root . DIRECTORY_SEPARATOR)) {
        @unlink($path);
    }
}

function reorder_photos(string $vehicleId): array
{
    $u = require_user();
    own_vehicle($vehicleId, $u);
    $order = (array) (body()['order'] ?? []);
    $st = db()->prepare('UPDATE vehicle_photos SET position = ? WHERE id = ? AND vehicle_id = ?');
    foreach (array_values($order) as $i => $photoId) {
        $st->execute([$i, (string) $photoId, $vehicleId]);
    }
    return ['ok' => true];
}
