<?php
// Statistiche per lo sfasciacarrozze: visite alle auto, contatti e ricambi richiesti dai clienti.
declare(strict_types=1);

const EVENT_KINDS = ['view', 'yard_view', 'call', 'whatsapp', 'maps', 'part'];
const EVENTS_PER_VISITOR_DAY = 300;

/** Visitatore anonimo: impronta di IP + browser che cambia ogni giorno (nessun dato personale salvato). */
function visitor_id(): string
{
    // il sale è segreto (dalla configurazione): dall'impronta non si risale all'IP
    $salt = hash('sha256', json_encode(config()['db']));
    return substr(hash('sha256', ($_SERVER['REMOTE_ADDR'] ?? '') . '|' . ($_SERVER['HTTP_USER_AGENT'] ?? '') . '|' . gmdate('Y-m-d') . '|' . $salt), 0, 16);
}

/** Pubblico: l'app clienti segnala una visita, un contatto o un ricambio richiesto. */
function track_event(): array
{
    $b = body();
    $kind = (string) ($b['kind'] ?? '');
    if (!in_array($kind, EVENT_KINDS, true)) {
        throw new HttpError(422, 'Evento non valido.');
    }
    $vehicleId = (string) ($b['vehicle_id'] ?? '');
    $yardId = (string) ($b['yard_id'] ?? '');
    if ($vehicleId !== '') {
        $st = db()->prepare(PUBLIC_VEHICLES . ' AND v.id = ?');
        $st->execute([$vehicleId]);
        $v = $st->fetch() ?: throw new HttpError(404, 'Veicolo non trovato.');
        $yardId = $v['yard_id'];
    } elseif ($yardId !== '') {
        $st = db()->prepare('SELECT id FROM yards WHERE id = ? AND published = 1');
        $st->execute([$yardId]);
        $st->fetchColumn() ?: throw new HttpError(404, 'Sfasciacarrozze non trovato.');
    } else {
        throw new HttpError(422, 'Manca il veicolo o lo sfasciacarrozze.');
    }
    // le visite del piazzale stesso (anteprima, controlli) non contano
    $u = current_user();
    if ($u && is_member($yardId, $u['id'])) {
        return ['ok' => true, 'counted' => false];
    }

    $visitor = visitor_id();
    $today = gmdate('Y-m-d 00:00:00');
    $st = db()->prepare('SELECT COUNT(*) FROM events WHERE visitor = ? AND created_at >= ?');
    $st->execute([$visitor, $today]);
    if ((int) $st->fetchColumn() >= EVENTS_PER_VISITOR_DAY) {
        return ['ok' => true, 'counted' => false];
    }
    $partId = $kind === 'part' ? (substr((string) ($b['part_id'] ?? ''), 0, 40) ?: null) : null;
    // pezzo scritto dal cliente (o la zona scelta) quando non c'è nella lista
    $text = $kind === 'part' ? mb_substr(trim(strip_tags((string) ($b['text'] ?? ''))), 0, 120) : '';
    // una visita per persona, per auto, al giorno
    if ($kind === 'view' || $kind === 'yard_view') {
        $st = db()->prepare('SELECT 1 FROM events WHERE visitor = ? AND kind = ? AND yard_id = ? AND COALESCE(vehicle_id, \'\') = ? AND created_at >= ?');
        $st->execute([$visitor, $kind, $yardId, $vehicleId, $today]);
        if ($st->fetchColumn()) {
            return ['ok' => true, 'counted' => false];
        }
    }
    db()->prepare('INSERT INTO events (yard_id, vehicle_id, kind, part_id, text, visitor, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)')
        ->execute([$yardId, $vehicleId ?: null, $kind, $partId, $text, $visitor, now()]);
    return ['ok' => true, 'counted' => true];
}

/** I numeri del mio piazzale negli ultimi N giorni, con il confronto sul periodo precedente. */
function my_stats(): array
{
    $yard = require_my_yard(require_user());
    $days = max(1, min(365, (int) ($_GET['days'] ?? 30)));
    $from = gmdate('Y-m-d 00:00:00', time() - ($days - 1) * 86400);
    $prevFrom = gmdate('Y-m-d 00:00:00', time() - (2 * $days - 1) * 86400);
    $y = $yard['id'];

    $totals = function (string $a, string $b) use ($y): array {
        $st = db()->prepare("SELECT kind, COUNT(*) n, COUNT(DISTINCT visitor) people FROM events
                             WHERE yard_id = ? AND created_at >= ? AND created_at < ? GROUP BY kind");
        $st->execute([$y, $a, $b]);
        $out = array_fill_keys(EVENT_KINDS, 0);
        foreach ($st->fetchAll() as $r) {
            $out[$r['kind']] = (int) $r['n'];
        }
        $st = db()->prepare("SELECT COUNT(DISTINCT visitor) FROM events WHERE yard_id = ? AND created_at >= ? AND created_at < ?");
        $st->execute([$y, $a, $b]);
        $out['visitors'] = (int) $st->fetchColumn();
        $out['contacts'] = $out['call'] + $out['whatsapp'] + $out['maps'];
        return $out;
    };
    $end = gmdate('Y-m-d H:i:s', time() + 60);

    $st = db()->prepare("SELECT SUBSTR(created_at, 1, 10) d,
                                SUM(CASE WHEN kind = 'view' THEN 1 ELSE 0 END) views,
                                SUM(CASE WHEN kind IN ('call', 'whatsapp', 'maps') THEN 1 ELSE 0 END) contacts,
                                SUM(CASE WHEN kind = 'part' THEN 1 ELSE 0 END) parts
                         FROM events WHERE yard_id = ? AND created_at >= ? GROUP BY SUBSTR(created_at, 1, 10)");
    $st->execute([$y, $from]);
    $byDay = [];
    foreach ($st->fetchAll() as $r) {
        $byDay[$r['d']] = ['views' => (int) $r['views'], 'contacts' => (int) $r['contacts'], 'parts' => (int) $r['parts']];
    }
    $series = [];
    for ($i = $days - 1; $i >= 0; $i--) {
        $d = gmdate('Y-m-d', time() - $i * 86400);
        $series[] = ['day' => $d] + ($byDay[$d] ?? ['views' => 0, 'contacts' => 0, 'parts' => 0]);
    }

    $st = db()->prepare("SELECT v.id, v.make, v.model, v.version, v.year, v.status,
                                SUM(CASE WHEN e.kind = 'view' THEN 1 ELSE 0 END) views,
                                SUM(CASE WHEN e.kind IN ('call', 'whatsapp', 'maps') THEN 1 ELSE 0 END) contacts,
                                SUM(CASE WHEN e.kind = 'part' THEN 1 ELSE 0 END) parts
                         FROM events e JOIN vehicles v ON v.id = e.vehicle_id
                         WHERE e.yard_id = ? AND e.created_at >= ?
                         GROUP BY v.id, v.make, v.model, v.version, v.year, v.status
                         ORDER BY views DESC, contacts DESC LIMIT 20");
    $st->execute([$y, $from]);
    $vehicles = array_map(fn($r) => [
        'id' => $r['id'],
        'title' => trim("{$r['make']} {$r['model']} {$r['version']}"),
        'year' => $r['year'] === null ? null : (int) $r['year'],
        'status' => $r['status'],
        'views' => (int) $r['views'],
        'contacts' => (int) $r['contacts'],
        'parts' => (int) $r['parts'],
    ], $st->fetchAll());

    // raggruppati per pezzo della lista, oppure per testo scritto dal cliente
    $st = db()->prepare("SELECT COALESCE(e.part_id, LOWER(e.text)) k, MAX(e.part_id) part_id, MAX(e.text) text,
                                COUNT(*) n, COUNT(DISTINCT e.vehicle_id) cars, MAX(p.name) name,
                                MAX(CONCAT_WS(' ', v.make, v.model)) car
                         FROM events e LEFT JOIN vehicle_parts p ON p.vehicle_id = e.vehicle_id AND p.part_id = e.part_id
                         LEFT JOIN vehicles v ON v.id = e.vehicle_id
                         WHERE e.yard_id = ? AND e.kind = 'part' AND e.created_at >= ?
                         GROUP BY COALESCE(e.part_id, LOWER(e.text)) ORDER BY n DESC LIMIT 20");
    if (is_sqlite()) {
        // SQLite non ha CONCAT_WS
        $st = db()->prepare(str_replace("CONCAT_WS(' ', v.make, v.model)", "v.make || ' ' || v.model", $st->queryString));
    }
    $st->execute([$y, $from]);
    $idx = part_index();
    $parts = array_map(fn($r) => [
        'part_id' => $r['part_id'],
        'name' => $r['name'] ?: ($idx[$r['part_id'] ?? '']['name'] ?? ($r['text'] ?: ($r['part_id'] ?? 'Pezzo'))),
        'requests' => (int) $r['n'],
        'vehicles' => (int) $r['cars'],
        'example_vehicle' => $r['car'],
    ], $st->fetchAll());

    return [
        'days' => $days,
        'totals' => $totals($from, $end),
        'previous' => $totals($prevFrom, $from),
        'series' => $series,
        'vehicles' => $vehicles,
        'parts' => $parts,
    ];
}
