<?php
// Business intelligence della piattaforma per l'app Admin: costi per tipo di richiesta, crescita,
// attività dei piazzali e dei clienti.
declare(strict_types=1);

function bi_one(string $sql, array $args = []): array
{
    $st = db()->prepare($sql);
    $st->execute($args);
    return $st->fetch() ?: [];
}

function bi_all(string $sql, array $args = []): array
{
    $st = db()->prepare($sql);
    $st->execute($args);
    return $st->fetchAll();
}

/** ?days= è il periodo dei grafici giornalieri (default 60). */
function admin_bi(): array
{
    require_admin();
    $days = max(7, min(365, (int) ($_GET['days'] ?? 60)));
    $from = gmdate('Y-m-d 00:00:00', time() - ($days - 1) * 86400);

    // ---- la piattaforma oggi ----
    $p = bi_one("SELECT (SELECT COUNT(*) FROM yards) yards,
                        (SELECT COUNT(*) FROM users) users,
                        (SELECT COUNT(*) FROM vehicles) vehicles,
                        (SELECT COUNT(*) FROM vehicles WHERE published = 1 AND status <> 'gone') online,
                        (SELECT COUNT(*) FROM vehicle_photos) photos,
                        (SELECT COUNT(DISTINCT vehicle_id) FROM vehicle_parts) with_parts,
                        (SELECT COUNT(*) FROM vehicle_parts) parts,
                        (SELECT COUNT(*) FROM vehicle_parts WHERE confirmed = 1) confirmed");
    $active = bi_one('SELECT COUNT(DISTINCT yard_id) n FROM vehicles WHERE created_at >= ?', [gmdate('Y-m-d H:i:s', time() - 30 * 86400)]);
    $platform = [
        'yards' => (int) $p['yards'],
        'active_yards' => (int) ($active['n'] ?? 0), // hanno caricato un'auto negli ultimi 30 giorni
        'users' => (int) $p['users'],
        'vehicles' => (int) $p['vehicles'],
        'online' => (int) $p['online'],
        'vehicles_per_yard' => $p['yards'] ? round($p['vehicles'] / $p['yards'], 1) : 0,
        'photos_per_vehicle' => $p['vehicles'] ? round($p['photos'] / $p['vehicles'], 1) : 0,
        'parts_coverage' => $p['vehicles'] ? round($p['with_parts'] / $p['vehicles'], 3) : 0,
        'parts_per_vehicle' => $p['with_parts'] ? (int) round($p['parts'] / $p['with_parts']) : 0,
        'parts_confirmed' => $p['parts'] ? round($p['confirmed'] / $p['parts'], 3) : 0,
    ];

    // ---- quanto costa ogni cosa ----
    $kinds = [];
    foreach (bi_all("SELECT kind, COUNT(*) n, SUM(CASE WHEN status <> 'ok' THEN 1 ELSE 0 END) failed,
                            SUM(images) images, SUM(input_tokens) i, SUM(output_tokens) o,
                            AVG(CASE WHEN status = 'ok' AND duration_ms > 0 THEN duration_ms END) ms
                     FROM ai_usage GROUP BY kind") as $r) {
        $cost = ai_cost($r['i'] ?? 0, $r['o'] ?? 0);
        $n = (int) $r['n'];
        $kinds[$r['kind']] = [
            'requests' => $n,
            'total_usd' => $cost,
            'avg_usd' => $n ? round($cost / $n, 5) : 0,
            'avg_images' => $n ? round($r['images'] / $n, 1) : 0,
            'per_image_usd' => $r['images'] ? round($cost / $r['images'], 5) : null,
            'avg_seconds' => $r['ms'] === null ? null : round($r['ms'] / 1000, 1),
            'error_rate' => $n ? round($r['failed'] / $n, 3) : 0,
            'avg_input_tokens' => $n ? (int) round($r['i'] / $n) : 0,
            'avg_output_tokens' => $n ? (int) round($r['o'] / $n) : 0,
        ];
    }
    $perVehicle = bi_one('SELECT AVG(c) avg_usd FROM (SELECT SUM(input_tokens) * ? / 1000000 + SUM(output_tokens) * ? / 1000000 c
                          FROM ai_usage WHERE vehicle_id IS NOT NULL GROUP BY vehicle_id) t', [AI_PRICE_IN, AI_PRICE_OUT]);
    $month = bi_one('SELECT SUM(input_tokens) i, SUM(output_tokens) o FROM ai_usage WHERE used_at >= ?', [month_start()]);
    $monthCost = ai_cost($month['i'] ?? 0, $month['o'] ?? 0);
    $costs = [
        'by_kind' => (object) $kinds,
        'per_vehicle_usd' => round((float) ($perVehicle['avg_usd'] ?? 0), 5),
        'month_usd' => $monthCost,
        'month_forecast_usd' => round($monthCost / max(1, (int) gmdate('j')) * (int) gmdate('t'), 4),
    ];

    // ---- giorno per giorno ----
    $series = [];
    for ($i = $days - 1; $i >= 0; $i--) {
        $series[gmdate('Y-m-d', time() - $i * 86400)] = ['photos' => 0, 'parts' => 0, 'cost_photos' => 0.0, 'cost_parts' => 0.0,
            'vehicles' => 0, 'views' => 0, 'contacts' => 0, 'requests' => 0];
    }
    foreach (bi_all('SELECT SUBSTR(used_at, 1, 10) d, kind, COUNT(*) n, SUM(input_tokens) i, SUM(output_tokens) o
                     FROM ai_usage WHERE used_at >= ? GROUP BY SUBSTR(used_at, 1, 10), kind', [$from]) as $r) {
        if (!isset($series[$r['d']])) {
            continue;
        }
        $k = $r['kind'] === 'parts' ? 'parts' : 'photos';
        $series[$r['d']][$k] += (int) $r['n'];
        $series[$r['d']]['cost_' . $k] += ai_cost($r['i'], $r['o']);
    }
    foreach (bi_all('SELECT SUBSTR(created_at, 1, 10) d, COUNT(*) n FROM vehicles WHERE created_at >= ? GROUP BY SUBSTR(created_at, 1, 10)', [$from]) as $r) {
        if (isset($series[$r['d']])) {
            $series[$r['d']]['vehicles'] = (int) $r['n'];
        }
    }
    foreach (bi_all("SELECT SUBSTR(created_at, 1, 10) d,
                            SUM(CASE WHEN kind = 'view' THEN 1 ELSE 0 END) v,
                            SUM(CASE WHEN kind IN ('call', 'whatsapp', 'maps') THEN 1 ELSE 0 END) c,
                            SUM(CASE WHEN kind = 'part' THEN 1 ELSE 0 END) r
                     FROM events WHERE created_at >= ? GROUP BY SUBSTR(created_at, 1, 10)", [$from]) as $r) {
        if (!isset($series[$r['d']])) {
            continue;
        }
        $series[$r['d']]['views'] = (int) $r['v'];
        $series[$r['d']]['contacts'] = (int) $r['c'];
        $series[$r['d']]['requests'] = (int) $r['r'];
    }
    $daily = [];
    foreach ($series as $d => $v) {
        $v['cost_photos'] = round($v['cost_photos'], 5);
        $v['cost_parts'] = round($v['cost_parts'], 5);
        $daily[] = ['day' => $d] + $v;
    }

    // ---- crescita mese per mese (ultimi 12) ----
    $growth = [];
    for ($m = 11; $m >= 0; $m--) {
        $start = gmdate('Y-m-01', strtotime(gmdate('Y-m-01') . " -$m months"));
        $end = gmdate('Y-m-01', strtotime("$start +1 month"));
        $g = bi_one('SELECT (SELECT COUNT(*) FROM yards WHERE created_at < ?) yards,
                            (SELECT COUNT(*) FROM vehicles WHERE created_at < ?) vehicles,
                            (SELECT COUNT(*) FROM vehicles WHERE created_at >= ? AND created_at < ?) new_vehicles', [$end, $end, $start, $end]);
        $growth[] = ['month' => substr($start, 0, 7), 'yards' => (int) $g['yards'], 'vehicles' => (int) $g['vehicles'], 'new_vehicles' => (int) $g['new_vehicles']];
    }

    // ---- clienti (lato C) nel periodo ----
    $e = bi_one("SELECT SUM(CASE WHEN kind = 'view' THEN 1 ELSE 0 END) views,
                        COUNT(DISTINCT visitor) visitors,
                        SUM(CASE WHEN kind IN ('call', 'whatsapp', 'maps') THEN 1 ELSE 0 END) contacts,
                        SUM(CASE WHEN kind = 'part' THEN 1 ELSE 0 END) requests
                 FROM events WHERE created_at >= ?", [$from]);
    $customers = ['views' => (int) ($e['views'] ?? 0), 'visitors' => (int) ($e['visitors'] ?? 0),
        'contacts' => (int) ($e['contacts'] ?? 0), 'requests' => (int) ($e['requests'] ?? 0)];
    $customers['contact_rate'] = $customers['views'] ? round(($customers['contacts'] + $customers['requests']) / $customers['views'], 3) : 0;

    // ---- classifiche ----
    $topYards = array_map(fn($r) => [
        'name' => $r['name'], 'vehicles' => (int) $r['vehicles'], 'views' => (int) $r['views'],
        'cost_usd' => ai_cost($r['i'] ?? 0, $r['o'] ?? 0),
    ], bi_all("SELECT y.name,
                      (SELECT COUNT(*) FROM vehicles v WHERE v.yard_id = y.id) vehicles,
                      (SELECT COUNT(*) FROM events e WHERE e.yard_id = y.id AND e.kind = 'view' AND e.created_at >= ?) views,
                      (SELECT SUM(input_tokens) FROM ai_usage a WHERE a.yard_id = y.id) i,
                      (SELECT SUM(output_tokens) FROM ai_usage a WHERE a.yard_id = y.id) o
               FROM yards y ORDER BY vehicles DESC LIMIT 8", [$from]));
    $makes = array_map(fn($r) => ['make' => $r['make'], 'vehicles' => (int) $r['n']],
        bi_all('SELECT make, COUNT(*) n FROM vehicles GROUP BY make ORDER BY n DESC LIMIT 8'));
    $status = [];
    foreach (bi_all('SELECT status, COUNT(*) n FROM vehicles GROUP BY status') as $r) {
        $status[$r['status']] = (int) $r['n'];
    }

    return [
        'days' => $days,
        'platform' => $platform,
        'costs' => $costs,
        'daily' => $daily,
        'growth' => $growth,
        'customers' => $customers,
        'top_yards' => $topYards,
        'makes' => $makes,
        'status' => (object) $status,
    ];
}
