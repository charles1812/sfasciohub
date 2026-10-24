<?php
// Lista dei ricambi di ogni veicolo: elenco base dei pezzi vendibili, generazione con l'AI, conferme del piazzale.
declare(strict_types=1);

const PART_STATUSES = ['ok', 'damaged', 'check'];

/**
 * I ricambi che uno sfasciacarrozze vende davvero (niente viteria), divisi per zona della mappa dei danni.
 * Chiave = id stabile; l'AI aggiunge il nome preciso per il modello (es. "Faro full LED").
 */
const PART_CATALOG = [
    'front' => [
        'paraurti_ant' => 'Paraurti anteriore', 'calandra' => 'Calandra / griglia', 'cofano' => 'Cofano motore',
        'traversa_ant' => 'Traversa / ossatura anteriore', 'rinforzo_paraurti_ant' => 'Rinforzo paraurti anteriore',
        'radiatore' => 'Radiatore acqua', 'condensatore' => 'Condensatore clima', 'elettroventola' => 'Elettroventola',
        'intercooler' => 'Intercooler', 'serratura_cofano' => 'Serratura cofano', 'sensori_park_ant' => 'Sensori di parcheggio anteriori',
        'radar_ant' => 'Radar / telecamera assistenza guida', 'stemma_ant' => 'Stemma anteriore',
    ],
    'front_left' => [
        'faro_ant_sx' => 'Faro anteriore sinistro', 'fendinebbia_sx' => 'Fendinebbia sinistro', 'parafango_ant_sx' => 'Parafango anteriore sinistro',
        'passaruota_ant_sx' => 'Passaruota anteriore sinistro', 'cerchio_ant_sx' => 'Cerchio anteriore sinistro', 'gomma_ant_sx' => 'Pneumatico anteriore sinistro',
        'ammortizzatore_ant_sx' => 'Ammortizzatore anteriore sinistro', 'fusello_ant_sx' => 'Fusello / mozzo anteriore sinistro',
        'braccio_ant_sx' => 'Braccio oscillante anteriore sinistro', 'semiasse_ant_sx' => 'Semiasse anteriore sinistro',
        'pinza_ant_sx' => 'Pinza freno anteriore sinistra', 'disco_ant_sx' => 'Disco freno anteriore sinistro',
    ],
    'front_right' => [
        'faro_ant_dx' => 'Faro anteriore destro', 'fendinebbia_dx' => 'Fendinebbia destro', 'parafango_ant_dx' => 'Parafango anteriore destro',
        'passaruota_ant_dx' => 'Passaruota anteriore destro', 'cerchio_ant_dx' => 'Cerchio anteriore destro', 'gomma_ant_dx' => 'Pneumatico anteriore destro',
        'ammortizzatore_ant_dx' => 'Ammortizzatore anteriore destro', 'fusello_ant_dx' => 'Fusello / mozzo anteriore destro',
        'braccio_ant_dx' => 'Braccio oscillante anteriore destro', 'semiasse_ant_dx' => 'Semiasse anteriore destro',
        'pinza_ant_dx' => 'Pinza freno anteriore destra', 'disco_ant_dx' => 'Disco freno anteriore destro',
    ],
    'left' => [
        'porta_ant_sx' => 'Porta anteriore sinistra', 'porta_post_sx' => 'Porta posteriore sinistra', 'specchietto_sx' => 'Specchietto sinistro',
        'alzavetro_ant_sx' => 'Alzacristallo anteriore sinistro', 'alzavetro_post_sx' => 'Alzacristallo posteriore sinistro',
        'maniglia_ant_sx' => 'Maniglia esterna anteriore sinistra', 'maniglia_post_sx' => 'Maniglia esterna posteriore sinistra',
        'serratura_ant_sx' => 'Serratura porta anteriore sinistra', 'serratura_post_sx' => 'Serratura porta posteriore sinistra',
        'minigonna_sx' => 'Minigonna / brancardo sinistro',
    ],
    'right' => [
        'porta_ant_dx' => 'Porta anteriore destra', 'porta_post_dx' => 'Porta posteriore destra', 'specchietto_dx' => 'Specchietto destro',
        'alzavetro_ant_dx' => 'Alzacristallo anteriore destro', 'alzavetro_post_dx' => 'Alzacristallo posteriore destro',
        'maniglia_ant_dx' => 'Maniglia esterna anteriore destra', 'maniglia_post_dx' => 'Maniglia esterna posteriore destra',
        'serratura_ant_dx' => 'Serratura porta anteriore destra', 'serratura_post_dx' => 'Serratura porta posteriore destra',
        'minigonna_dx' => 'Minigonna / brancardo destro',
    ],
    'rear_left' => [
        'fanale_post_sx' => 'Fanale posteriore sinistro', 'fiancata_post_sx' => 'Fiancata / parafango posteriore sinistro',
        'cerchio_post_sx' => 'Cerchio posteriore sinistro', 'gomma_post_sx' => 'Pneumatico posteriore sinistro',
        'ammortizzatore_post_sx' => 'Ammortizzatore posteriore sinistro', 'freno_post_sx' => 'Freno posteriore sinistro (pinza/tamburo)',
        'sportello_carburante' => 'Sportello carburante',
    ],
    'rear_right' => [
        'fanale_post_dx' => 'Fanale posteriore destro', 'fiancata_post_dx' => 'Fiancata / parafango posteriore destro',
        'cerchio_post_dx' => 'Cerchio posteriore destro', 'gomma_post_dx' => 'Pneumatico posteriore destro',
        'ammortizzatore_post_dx' => 'Ammortizzatore posteriore destro', 'freno_post_dx' => 'Freno posteriore destro (pinza/tamburo)',
    ],
    'rear' => [
        'paraurti_post' => 'Paraurti posteriore', 'portellone' => 'Portellone / cofano bagagliaio', 'serratura_portellone' => 'Serratura portellone',
        'pistoncini_portellone' => 'Pistoncini portellone', 'terzo_stop' => 'Terzo stop', 'sensori_park_post' => 'Sensori di parcheggio posteriori',
        'telecamera_post' => 'Telecamera retromarcia', 'assale_post' => 'Assale / ponte posteriore', 'scarico' => 'Silenziatore / scarico',
        'gancio_traino' => 'Gancio traino', 'ruota_scorta' => 'Ruotino di scorta',
    ],
    'roof' => [
        'tetto' => 'Padiglione / tetto', 'tetto_apribile' => 'Tetto apribile', 'barre_tetto' => 'Barre portatutto', 'antenna' => 'Antenna',
    ],
    'glass' => [
        'parabrezza' => 'Parabrezza', 'lunotto' => 'Lunotto', 'vetro_ant_sx' => 'Vetro porta anteriore sinistra', 'vetro_ant_dx' => 'Vetro porta anteriore destra',
        'vetro_post_sx' => 'Vetro porta posteriore sinistra', 'vetro_post_dx' => 'Vetro porta posteriore destra',
        'vetro_fisso_sx' => 'Vetro fisso laterale sinistro', 'vetro_fisso_dx' => 'Vetro fisso laterale destro',
    ],
    'engine' => [
        'motore' => 'Motore completo', 'testata' => 'Testata', 'cambio' => 'Cambio', 'frizione' => 'Frizione / volano',
        'alternatore' => 'Alternatore', 'motorino_avviamento' => 'Motorino di avviamento', 'compressore_clima' => 'Compressore clima',
        'turbina' => 'Turbina', 'iniettori' => 'Iniettori', 'pompa_iniezione' => 'Pompa iniezione / alta pressione',
        'centralina_motore' => 'Centralina motore', 'corpo_farfallato' => 'Corpo farfallato', 'debimetro' => 'Debimetro',
        'valvola_egr' => 'Valvola EGR', 'fap' => 'Filtro antiparticolato (FAP/DPF)', 'catalizzatore' => 'Catalizzatore',
        'pompa_acqua' => 'Pompa acqua', 'scatola_sterzo' => 'Scatola sterzo / servosterzo', 'pompa_abs' => 'Gruppo ABS / ESP',
        'servofreno' => 'Servofreno e pompa freni', 'batteria' => 'Batteria', 'scatola_fusibili' => 'Scatola fusibili motore',
        'scatola_filtro' => 'Scatola filtro aria', 'vaschetta_espansione' => 'Vaschetta espansione', 'cablaggio_motore' => 'Cablaggio motore',
        'supporti_motore' => 'Supporti motore', 'culla_motore' => 'Culla / telaietto anteriore',
    ],
    'interior' => [
        'cruscotto' => 'Cruscotto / plancia', 'quadro_strumenti' => 'Quadro strumenti', 'volante' => 'Volante', 'airbag_volante' => 'Airbag volante',
        'airbag_passeggero' => 'Airbag passeggero', 'airbag_laterali' => 'Airbag laterali e a tendina', 'centralina_airbag' => 'Centralina airbag',
        'sedile_guida' => 'Sedile guida', 'sedile_passeggero' => 'Sedile passeggero', 'divano_post' => 'Divano posteriore',
        'cinture' => 'Cinture di sicurezza', 'autoradio' => 'Autoradio / navigatore', 'display' => 'Display centrale',
        'comandi_clima' => 'Comandi climatizzatore', 'devioluci' => 'Devioluci / piantone sterzo', 'body_computer' => 'Body computer (BSI)',
        'pannelli_porte' => 'Pannelli porte', 'cielo' => 'Cielo / tappezzeria tetto', 'specchietto_int' => 'Specchietto retrovisore interno',
        'pedaliera' => 'Pedaliera', 'leva_cambio' => 'Leva cambio / selettore', 'freno_mano' => 'Freno a mano', 'cappelliera' => 'Cappelliera',
        'ventola_abitacolo' => 'Ventola abitacolo / riscaldamento', 'blocchetto' => 'Blocchetto accensione / chiave', 'tappetini' => 'Tappetini',
    ],
];

/** @return array<string, array{zone:string,name:string}> */
function part_index(): array
{
    static $idx = null;
    if ($idx === null) {
        $idx = [];
        foreach (PART_CATALOG as $zone => $parts) {
            foreach ($parts as $id => $name) {
                $idx[$id] = ['zone' => $zone, 'name' => $name];
            }
        }
    }
    return $idx;
}

function parts_of(string $vehicleId): array
{
    $st = db()->prepare('SELECT part_id, name, zone, status, confirmed, note FROM vehicle_parts WHERE vehicle_id = ?');
    $st->execute([$vehicleId]);
    $order = array_flip(array_keys(part_index()));
    $rows = $st->fetchAll();
    usort($rows, fn($a, $b) => ($order[$a['part_id']] ?? 9999) <=> ($order[$b['part_id']] ?? 9999));
    return array_map(fn($r) => [
        'id' => $r['part_id'],
        'name' => $r['name'],
        'zone' => $r['zone'],
        'status' => $r['status'],
        'confirmed' => (bool) $r['confirmed'],
        'note' => $r['note'],
    ], $rows);
}

function my_parts(string $vehicleId): array
{
    own_vehicle($vehicleId, require_user());
    return ['parts' => parts_of($vehicleId), 'catalog_size' => count(part_index())];
}

/** Il piazzale conferma o corregge: [{id, status}] → confermati. */
function update_my_parts(string $vehicleId): array
{
    own_vehicle($vehicleId, require_user());
    $st = db()->prepare('UPDATE vehicle_parts SET status = ?, confirmed = 1, updated_at = ? WHERE vehicle_id = ? AND part_id = ?');
    foreach ((array) (body()['parts'] ?? []) as $p) {
        $status = (string) ($p['status'] ?? '');
        if (in_array($status, PART_STATUSES, true)) {
            $st->execute([$status, now(), $vehicleId, (string) ($p['id'] ?? '')]);
        }
    }
    db()->prepare('UPDATE vehicles SET updated_at = ? WHERE id = ?')->execute([now(), $vehicleId]);
    return ['parts' => parts_of($vehicleId)];
}

function parts_schema(): array
{
    return [
        'type' => 'object',
        'properties' => [
            'parts' => [
                'type' => 'array',
                'items' => [
                    'type' => 'object',
                    'properties' => [
                        'id' => ['type' => 'string', 'enum' => array_keys(part_index())],
                        'status' => ['type' => 'string', 'enum' => PART_STATUSES],
                        'name' => ['type' => 'string'],
                    ],
                    'required' => ['id', 'status', 'name'],
                    'additionalProperties' => false,
                ],
            ],
        ],
        'required' => ['parts'],
        'additionalProperties' => false,
    ];
}

function parts_prompt(array $v): string
{
    $zones = ['front' => 'frontale', 'front_left' => 'angolo anteriore sinistro', 'front_right' => 'angolo anteriore destro',
        'left' => 'fiancata sinistra', 'right' => 'fiancata destra', 'rear_left' => 'angolo posteriore sinistro',
        'rear_right' => 'angolo posteriore destro', 'rear' => 'posteriore', 'roof' => 'tetto', 'glass' => 'vetri',
        'engine' => 'vano motore', 'interior' => 'interni'];
    $damage = array_filter(explode(',', (string) $v['damage_zones']));
    $catalog = '';
    foreach (PART_CATALOG as $zone => $parts) {
        $catalog .= "\n[{$zones[$zone]}]\n";
        foreach ($parts as $id => $name) {
            $catalog .= "$id: $name\n";
        }
    }
    $car = trim("{$v['make']} {$v['model']} {$v['version']}") . ($v['year'] ? " ({$v['year']})" : '')
        . ($v['fuel'] ? ", {$v['fuel']}" : '') . ($v['engine_code'] ? ", motore {$v['engine_code']}" : '');
    $damageText = $damage ? implode(', ', array_map(fn($z) => $zones[$z] ?? $z, $damage)) : 'nessuna segnalata';
    $notes = trim((string) $v['notes']) ?: '—';

    return <<<TXT
Sei il magazziniere esperto di uno sfasciacarrozze italiano. Per questo veicolo prepara la lista dei ricambi vendibili.

Veicolo: $car
Zone danneggiate segnate dal piazzale: $damageText
Note del piazzale: $notes
Le foto (se ci sono) mostrano il veicolo così com'è arrivato.

Elenco base dei ricambi (id: nome), diviso per zona:
$catalog
Regole:
- Includi solo i pezzi che questo modello ha davvero (es. niente tetto apribile o turbina se il modello/allestimento non li prevede di serie; se è possibile che ci siano, includili come "check"). Niente pezzi fuori elenco.
- status: "ok" = probabilmente sano e recuperabile; "damaged" = sicuramente o molto probabilmente rovinato; "check" = da verificare (vicino all'urto, airbag esplosi, meccanica dopo un frontale forte, ecc.).
- Ragiona come un perito: un frontale forte rovina spesso radiatore, condensatore, traversa ed elettroventola; se sono esplosi gli airbag, airbag e centralina airbag vanno "damaged" e cruscotto e cinture "check".
- name: il nome preciso per questo modello quando aggiunge informazione utile a chi compra (es. "Faro anteriore sinistro full LED", "Cambio manuale 5 marce"), altrimenti stringa vuota.
TXT;
}

/** Chiede all'AI la lista dei pezzi per un veicolo già salvato e la scrive nel database. */
function generate_my_parts(string $vehicleId): array
{
    $u = require_user();
    $v = own_vehicle($vehicleId, $u);
    $yard = require_my_yard($u);
    $key = ai_key();
    if ($key === '') {
        throw new HttpError(503, 'Il riconoscimento automatico non è attivo su questo server.');
    }
    if (ai_used_today($yard['id']) >= ai_daily_limit($yard)) {
        throw new HttpError(429, 'Hai usato tutte le analisi di oggi (' . ai_daily_limit($yard) . '). Riprova domani.');
    }

    // fino a 4 foto già salvate: aiutano a capire allestimento e danni
    $st = db()->prepare('SELECT id FROM vehicle_photos WHERE vehicle_id = ? ORDER BY position LIMIT 4');
    $st->execute([$vehicleId]);
    $ids = array_column($st->fetchAll(), 'id');
    $images = $ids ? ai_images(['photo_ids' => $ids], $yard) : [];

    $res = ai_post($key, [
        'model' => AI_MODEL,
        'max_tokens' => 12000,
        'output_config' => [
            'effort' => 'low',
            'format' => ['type' => 'json_schema', 'schema' => parts_schema()],
        ],
        'messages' => [[
            'role' => 'user',
            'content' => [...$images, ['type' => 'text', 'text' => parts_prompt($v)]],
        ]],
    ]);
    db()->prepare("INSERT INTO ai_usage (yard_id, user_id, used_at, input_tokens, output_tokens, kind) VALUES (?, ?, ?, ?, ?, 'parts')")
        ->execute([$yard['id'], $u['id'], now(), (int) ($res['usage']['input_tokens'] ?? 0), (int) ($res['usage']['output_tokens'] ?? 0)]);

    $stop = $res['stop_reason'] ?? '';
    if ($stop === 'refusal' || $stop === 'max_tokens') {
        throw new HttpError(502, 'La lista dei pezzi non è riuscita, riprova.');
    }
    $text = '';
    foreach ((array) ($res['content'] ?? []) as $block) {
        if (($block['type'] ?? '') === 'text') {
            $text .= $block['text'];
        }
    }
    $r = json_decode($text, true);
    if (!is_array($r) || !is_array($r['parts'] ?? null)) {
        throw new HttpError(502, 'Risposta non valida, riprova.');
    }

    // i pezzi già confermati dal piazzale non si toccano
    $st = db()->prepare('SELECT part_id FROM vehicle_parts WHERE vehicle_id = ? AND confirmed = 1');
    $st->execute([$vehicleId]);
    $confirmed = array_flip(array_column($st->fetchAll(), 'part_id'));
    $idx = part_index();

    $pdo = db();
    $pdo->beginTransaction();
    $pdo->prepare('DELETE FROM vehicle_parts WHERE vehicle_id = ? AND confirmed = 0')->execute([$vehicleId]);
    $ins = $pdo->prepare('INSERT INTO vehicle_parts (vehicle_id, part_id, name, zone, status, confirmed, note, updated_at) VALUES (?, ?, ?, ?, ?, 0, ?, ?)');
    $seen = [];
    foreach ($r['parts'] as $p) {
        $id = (string) ($p['id'] ?? '');
        if (!isset($idx[$id]) || isset($seen[$id]) || isset($confirmed[$id]) || !in_array($p['status'] ?? '', PART_STATUSES, true)) {
            continue;
        }
        $seen[$id] = true;
        $name = mb_substr(trim((string) ($p['name'] ?? '')), 0, 120) ?: $idx[$id]['name'];
        $ins->execute([$vehicleId, $id, $name, $idx[$id]['zone'], $p['status'], '', now()]);
    }
    $pdo->prepare('UPDATE vehicles SET updated_at = ? WHERE id = ?')->execute([now(), $vehicleId]);
    $pdo->commit();

    return ['parts' => parts_of($vehicleId), 'remaining' => max(0, ai_daily_limit($yard) - ai_used_today($yard['id']))];
}
