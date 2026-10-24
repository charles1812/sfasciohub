<?php
// Riconoscimento del veicolo dalle foto con Claude (Anthropic API, modello Haiku).
// La chiave sta solo sul server, in api/ai_key.php: l'app non la vede mai.
declare(strict_types=1);

const AI_MODEL = 'claude-haiku-5-5';
const AI_MAX_IMAGES = 5;
const AI_MAX_IMAGE_BYTES = 5 * 1024 * 1024;   // limite dell'API per immagine
const AI_DAILY_LIMIT = 40;                    // analisi al giorno per sfasciacarrozze

function ai_key(): string
{
    $file = __DIR__ . '/../ai_key.php';
    $key = is_file($file) ? require $file : '';
    if (!is_string($key) || $key === '') {
        $key = (string) (config()['anthropic_api_key'] ?? getenv('ANTHROPIC_API_KEY') ?: '');
    }
    return trim($key);
}

function ai_url(): string
{
    // per i test in locale si può puntare a un finto server
    return (string) (config()['anthropic_url'] ?? 'https://api.anthropic.com/v1/messages');
}

function ai_daily_limit(): int
{
    return (int) (config()['ai_daily_limit'] ?? AI_DAILY_LIMIT);
}

function ai_used_today(string $yardId): int
{
    db()->exec(ai_usage_table_sql(is_sqlite()));
    $st = db()->prepare('SELECT COUNT(*) FROM ai_usage WHERE yard_id = ? AND used_at >= ?');
    $st->execute([$yardId, gmdate('Y-m-d 00:00:00')]);
    return (int) $st->fetchColumn();
}

function ai_status(): array
{
    $yard = require_my_yard(require_user());
    $enabled = ai_key() !== '';
    return [
        'enabled' => $enabled,
        'remaining' => $enabled ? max(0, ai_daily_limit() - ai_used_today($yard['id'])) : 0,
    ];
}

/** Le foto da analizzare: immagini nuove (base64) e/o foto già salvate del veicolo. */
function ai_images(array $b, array $yard): array
{
    $images = [];
    foreach ((array) ($b['images'] ?? []) as $b64) {
        $data = base64_decode((string) $b64, true);
        if ($data === false || $data === '') {
            throw new HttpError(400, 'Immagine non valida.');
        }
        $images[] = $data;
    }
    $ids = array_values(array_filter(array_map('strval', (array) ($b['photo_ids'] ?? []))));
    if ($ids) {
        $in = implode(',', array_fill(0, count($ids), '?'));
        $st = db()->prepare("SELECT p.id, p.file FROM vehicle_photos p JOIN vehicles v ON v.id = p.vehicle_id
                             WHERE v.yard_id = ? AND p.id IN ($in)");
        $st->execute([$yard['id'], ...$ids]);
        $files = array_column($st->fetchAll(), 'file', 'id');
        foreach ($ids as $id) {
            $path = isset($files[$id]) ? uploads_dir() . '/' . $files[$id] : '';
            if ($path !== '' && is_file($path)) {
                $images[] = (string) file_get_contents($path);
            }
        }
    }
    if (!$images) {
        throw new HttpError(400, 'Aggiungi almeno una foto del veicolo.');
    }

    $out = [];
    foreach (array_slice($images, 0, AI_MAX_IMAGES) as $data) {
        if (strlen($data) > AI_MAX_IMAGE_BYTES) {
            throw new HttpError(413, 'Una foto è troppo grande per l\'analisi (max 5 MB).');
        }
        $mime = @getimagesizefromstring($data)['mime'] ?? '';
        if (!in_array($mime, ['image/jpeg', 'image/png', 'image/webp'], true)) {
            throw new HttpError(415, 'Formato non supportato: usa JPEG, PNG o WebP.');
        }
        $out[] = ['type' => 'image', 'source' => ['type' => 'base64', 'media_type' => $mime, 'data' => base64_encode($data)]];
    }
    return $out;
}

function ai_schema(): array
{
    return [
        'type' => 'object',
        'properties' => [
            'is_vehicle' => ['type' => 'boolean'],
            'make' => ['type' => 'string'],
            'model' => ['type' => 'string'],
            'version' => ['type' => 'string'],
            'year' => ['type' => 'integer'],
            'year_range' => ['type' => 'string'],
            'fuel' => ['type' => 'string', 'enum' => FUELS],
            'color' => ['type' => 'string'],
            'damage' => ['type' => 'array', 'items' => ['type' => 'string', 'enum' => DAMAGE_ZONES]],
            'notes' => ['type' => 'string'],
            'confidence' => ['type' => 'string', 'enum' => ['alta', 'media', 'bassa']],
        ],
        'required' => ['is_vehicle', 'make', 'model', 'version', 'year', 'year_range', 'fuel', 'color', 'damage', 'notes', 'confidence'],
        'additionalProperties' => false,
    ];
}

const AI_PROMPT = <<<TXT
Sei il perito di uno sfasciacarrozze italiano. Le foto mostrano un veicolo appena arrivato nel piazzale.
Compila la scheda in italiano:
- make, model: marca e modello come li scriverebbe un ricambista (es. "Fiat", "Punto Evo"). Vuoti se non riconoscibili.
- version: allestimento o motorizzazione solo se si vede (scritte, badge), altrimenti vuoto.
- year: anno più probabile; year_range: la serie/generazione con gli anni di produzione (es. "2009–2012, 1ª serie"). year = 0 se non stimabile.
- fuel: solo se lo indicano badge o scritte (TDI, JTD, GPL, hybrid…), altrimenti "".
- color: colore della carrozzeria in parole semplici.
- damage: le zone danneggiate visibili, tra: front (frontale), front_left / front_right (angolo anteriore sx/dx),
  left / right (fiancata sx/dx), rear_left / rear_right (angolo posteriore sx/dx), rear (posteriore), roof (tetto),
  glass (vetri), engine (vano motore), interior (interni). Sinistra e destra sono dal punto di vista di chi guida.
  Segna solo i danni che si vedono davvero; una zona che non si vede non è danneggiata.
- notes: 1–3 frasi sui danni e su cosa sembra integro e recuperabile.
- confidence: quanto sei sicuro del modello.
Se le foto non mostrano un veicolo, is_vehicle = false e lascia il resto vuoto.
TXT;

function ai_analyze(): array
{
    $u = require_user();
    $yard = require_my_yard($u);
    $key = ai_key();
    if ($key === '') {
        throw new HttpError(503, 'Il riconoscimento automatico non è attivo su questo server.');
    }
    if (ai_used_today($yard['id']) >= ai_daily_limit()) {
        throw new HttpError(429, 'Hai usato tutte le analisi di oggi (' . ai_daily_limit() . '). Riprova domani.');
    }
    $images = ai_images(body(), $yard);

    $request = [
        'model' => AI_MODEL,
        'max_tokens' => 4000,
        'output_config' => [
            'effort' => 'low',
            'format' => ['type' => 'json_schema', 'schema' => ai_schema()],
        ],
        'messages' => [[
            'role' => 'user',
            'content' => [...$images, ['type' => 'text', 'text' => AI_PROMPT]],
        ]],
    ];
    $res = ai_post($key, $request);

    db()->prepare('INSERT INTO ai_usage (yard_id, user_id, used_at, input_tokens, output_tokens) VALUES (?, ?, ?, ?, ?)')
        ->execute([$yard['id'], $u['id'], now(), (int) ($res['usage']['input_tokens'] ?? 0), (int) ($res['usage']['output_tokens'] ?? 0)]);

    $stop = $res['stop_reason'] ?? '';
    if ($stop === 'refusal') {
        throw new HttpError(422, 'Il riconoscimento non ha potuto analizzare queste foto. Compila a mano.');
    }
    if ($stop === 'max_tokens') {
        throw new HttpError(502, 'Analisi incompleta, riprova.');
    }
    $text = '';
    foreach ((array) ($res['content'] ?? []) as $block) {
        if (($block['type'] ?? '') === 'text') {
            $text .= $block['text'];
        }
    }
    $r = json_decode($text, true);
    if (!is_array($r)) {
        throw new HttpError(502, 'Risposta del riconoscimento non valida, riprova.');
    }
    if (empty($r['is_vehicle'])) {
        throw new HttpError(422, 'Nelle foto non riconosco un veicolo.');
    }

    $year = (int) ($r['year'] ?? 0);
    return [
        'make' => mb_substr(trim((string) ($r['make'] ?? '')), 0, 60),
        'model' => mb_substr(trim((string) ($r['model'] ?? '')), 0, 80),
        'version' => mb_substr(trim((string) ($r['version'] ?? '')), 0, 120),
        'year' => $year >= 1950 && $year <= (int) gmdate('Y') + 1 ? $year : null,
        'year_range' => mb_substr(trim((string) ($r['year_range'] ?? '')), 0, 120),
        'fuel' => in_array($r['fuel'] ?? '', FUELS, true) ? $r['fuel'] : '',
        'color' => mb_substr(trim((string) ($r['color'] ?? '')), 0, 40),
        'damage' => array_values(array_unique(array_intersect((array) ($r['damage'] ?? []), DAMAGE_ZONES))),
        'notes' => mb_substr(trim((string) ($r['notes'] ?? '')), 0, 1000),
        'confidence' => in_array($r['confidence'] ?? '', ['alta', 'media', 'bassa'], true) ? $r['confidence'] : 'bassa',
        'remaining' => max(0, ai_daily_limit() - ai_used_today($yard['id'])),
    ];
}

function ai_post(string $key, array $request): array
{
    if (!function_exists('curl_init')) {
        throw new HttpError(500, 'Sul server manca l\'estensione PHP curl.');
    }
    $ch = curl_init(ai_url());
    curl_setopt_array($ch, [
        CURLOPT_POST => true,
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_CONNECTTIMEOUT => 10,
        CURLOPT_TIMEOUT => 90,
        CURLOPT_HTTPHEADER => [
            'Content-Type: application/json',
            'x-api-key: ' . $key,
            'anthropic-version: 2026-10-21',
        ],
        CURLOPT_POSTFIELDS => json_encode($request, JSON_UNESCAPED_SLASHES),
    ]);
    $raw = curl_exec($ch);
    $status = (int) curl_getinfo($ch, CURLINFO_RESPONSE_CODE);
    $err = curl_error($ch);
    curl_close($ch);

    if ($raw === false) {
        error_log('[sfasciohub] Anthropic API non raggiungibile: ' . $err);
        throw new HttpError(502, 'Il servizio di riconoscimento non risponde, riprova tra poco.');
    }
    $data = json_decode((string) $raw, true);
    if ($status >= 400 || !is_array($data)) {
        $msg = is_array($data) ? (string) ($data['error']['message'] ?? '') : '';
        error_log("[sfasciohub] Anthropic API $status: " . ($msg ?: substr((string) $raw, 0, 300)));
        throw new HttpError(502, match (true) {
            $status === 401 => 'La chiave del riconoscimento non è valida: controlla api/ai_key.php.',
            $status === 429 => 'Il riconoscimento è molto richiesto in questo momento, riprova tra un minuto.',
            $status === 400 && str_contains($msg, 'credit') => 'Crediti API esauriti: ricarica il conto Anthropic.',
            default => 'Il riconoscimento non è riuscito, riprova.',
        });
    }
    return $data;
}
