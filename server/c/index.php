<?php
// Catalogo condivisibile di un piazzale: sito/c/<nome-piazzale>  (una sola auto: ?auto=<id>)
// Pagina leggera fatta dal server, così su WhatsApp e Facebook il link mostra foto e titolo.
declare(strict_types=1);

require __DIR__ . '/../api/lib/bootstrap.php';
require __DIR__ . '/../api/lib/schema.php';
require __DIR__ . '/../api/lib/handlers.php';

header('Content-Type: text/html; charset=utf-8');
header('Cache-Control: public, max-age=120');

const ZONES = ['front' => 'frontale', 'front_left' => 'anteriore sx', 'front_right' => 'anteriore dx', 'left' => 'fiancata sx',
    'right' => 'fiancata dx', 'rear_left' => 'posteriore sx', 'rear_right' => 'posteriore dx', 'rear' => 'posteriore',
    'roof' => 'tetto', 'glass' => 'vetri', 'engine' => 'motore', 'interior' => 'interni'];

function h(?string $s): string
{
    return htmlspecialchars((string) $s, ENT_QUOTES, 'UTF-8');
}

function wa_number(string $phone): string
{
    $n = preg_replace('/[^0-9+]/', '', $phone);
    if (str_starts_with($n, '+')) {
        return substr($n, 1);
    }
    if (str_starts_with($n, '00')) {
        return substr($n, 2);
    }
    return $n === '' ? '' : (str_starts_with($n, '39') && strlen($n) > 10 ? $n : "39$n");
}

function not_found(): never
{
    http_response_code(404);
    echo '<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">'
        . '<title>Catalogo non trovato</title><body style="font:16px system-ui;background:#0F1A1C;color:#EAF2EF;padding:40px 16px;text-align:center">'
        . '<h1>Catalogo non trovato</h1><p>Il link potrebbe essere sbagliato o il piazzale non è più online.</p>'
        . '<p><a style="color:#F26B1D" href="../">Vai a SfascioHub</a></p>';
    exit;
}

try {
    $slug = (string) ($_GET['s'] ?? '');
    if (!preg_match('/^[a-z0-9-]{1,60}$/', $slug)) {
        not_found();
    }
    $st = db()->prepare('SELECT * FROM yards WHERE slug = ? AND published = 1 AND approved = 1');
    $st->execute([$slug]);
    $yard = $st->fetch() ?: not_found();
    $st = db()->prepare(PUBLIC_VEHICLES . ' AND v.yard_id = ? ORDER BY v.created_at DESC');
    $st->execute([$yard['id']]);
    $cars = vehicles_out($st->fetchAll());
} catch (HttpError) {
    not_found();
}

$base = base_url();
$self = "$base/c/$slug";
$focus = null;
foreach ($cars as $c) {
    if ($c['id'] === ($_GET['auto'] ?? '')) {
        $focus = $c;
    }
}
if ($focus) {
    // l'auto condivisa va in cima
    $cars = array_merge([$focus], array_values(array_filter($cars, fn($c) => $c['id'] !== $focus['id'])));
}
$wa = wa_number($yard['whatsapp'] ?: $yard['phone']);
$title = fn(array $c) => trim("{$c['make']} {$c['model']}" . ($c['version'] ? " {$c['version']}" : ''));
$place = trim($yard['city'] . ($yard['province'] ? " ({$yard['province']})" : ''));

if ($focus) {
    $ogTitle = $title($focus) . ($focus['year'] ? " {$focus['year']}" : '') . ' · ricambi da ' . $yard['name'];
    $ogDesc = 'Ricambi usati disponibili' . ($place ? " a $place" : '') . '. Chiedi il pezzo che ti serve su WhatsApp.';
    $ogImage = $focus['vehicle_photos'][0]['url'] ?? '';
} else {
    $n = count($cars);
    $ogTitle = $yard['name'] . " · $n auto per ricambi";
    $ogDesc = ($place ? "$place. " : '') . 'Il catalogo delle auto da cui recuperare ricambi usati: chiedi il pezzo su WhatsApp.';
    $ogImage = '';
    foreach ($cars as $c) {
        if (!empty($c['vehicle_photos'])) {
            $ogImage = $c['vehicle_photos'][0]['url'];
            break;
        }
    }
}
$ogImage = $ogImage ?: "$base/icons/Icon-512.png";
?>
<!doctype html>
<html lang="it">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title><?= h($ogTitle) ?></title>
<meta name="description" content="<?= h($ogDesc) ?>">
<meta property="og:type" content="website">
<meta property="og:title" content="<?= h($ogTitle) ?>">
<meta property="og:description" content="<?= h($ogDesc) ?>">
<meta property="og:image" content="<?= h($ogImage) ?>">
<meta property="og:url" content="<?= h($focus ? "$self?auto={$focus['id']}" : $self) ?>">
<meta name="twitter:card" content="summary_large_image">
<link rel="icon" href="<?= h("$base/favicon.png") ?>">
<style>
  :root { --ink:#0F1A1C; --surface:#16262A; --surface2:#1E3338; --line:#2A4045; --text:#EAF2EF; --muted:#8FA6A2;
          --orange:#F26B1D; --gold:#E0B15E; --ok:#6FCF97; --damage:#E08A6B; --wa:#25D366; }
  * { box-sizing: border-box; }
  body { margin: 0; background: var(--ink); color: var(--text); font: 16px/1.45 system-ui, -apple-system, "Segoe UI", Roboto, sans-serif; }
  a { color: inherit; }
  header { background: linear-gradient(135deg, #F26B1D, #C2410C 60%, #7C2D12); padding: 26px 16px 22px; }
  .wrap { max-width: 1100px; margin: 0 auto; }
  header h1 { margin: 0; font-size: 28px; line-height: 1.15; }
  header p { margin: 6px 0 0; opacity: .92; }
  .actions { display: flex; flex-wrap: wrap; gap: 8px; margin-top: 16px; }
  .btn { display: inline-flex; align-items: center; gap: 8px; text-decoration: none; font-weight: 700; padding: 11px 16px; border-radius: 12px; border: 0; cursor: pointer; font-size: 15px; }
  .btn.wa { background: var(--wa); color: #06331b; }
  .btn.light { background: rgba(255,255,255,.18); color: #fff; }
  .btn.ghost { background: var(--surface2); color: var(--text); }
  main { padding: 16px; }
  .search { width: 100%; padding: 13px 14px; border-radius: 12px; border: 1px solid var(--line); background: var(--surface); color: var(--text); font-size: 16px; margin-bottom: 14px; }
  .count { color: var(--muted); margin: 0 0 12px; font-size: 14px; }
  .grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(280px, 1fr)); gap: 14px; }
  .car { background: var(--surface); border: 1px solid var(--line); border-radius: 18px; overflow: hidden; display: flex; flex-direction: column; }
  .car.focus { border-color: var(--orange); box-shadow: 0 0 0 2px rgba(242,107,29,.35); }
  .photo { aspect-ratio: 16/10; background: var(--surface2) center/cover no-repeat; position: relative; }
  .photo .none { position: absolute; inset: 0; display: grid; place-items: center; color: var(--muted); font-size: 14px; }
  .tag { position: absolute; top: 10px; left: 10px; background: rgba(15,26,28,.8); color: var(--ok); font-size: 12px; font-weight: 700; padding: 4px 9px; border-radius: 20px; }
  .tag.res { color: var(--gold); }
  .body { padding: 14px; display: flex; flex-direction: column; gap: 6px; flex: 1; }
  .body h2 { margin: 0; font-size: 18px; }
  .meta { color: var(--muted); font-size: 14px; }
  .dmg { font-size: 13.5px; color: var(--damage); }
  .ok { font-size: 13.5px; color: var(--ok); }
  .row { display: flex; gap: 8px; margin-top: auto; padding-top: 8px; flex-wrap: wrap; }
  .row .btn { flex: 1; justify-content: center; padding: 10px 12px; font-size: 14px; }
  footer { text-align: center; color: var(--muted); font-size: 13.5px; padding: 26px 16px 40px; }
  footer a { color: var(--orange); }
  .empty { background: var(--surface); border: 1px solid var(--line); border-radius: 18px; padding: 22px; text-align: center; color: var(--muted); }
</style>
</head>
<body>
<header>
  <div class="wrap">
    <h1><?= h($yard['name']) ?></h1>
    <p><?= h(implode(' · ', array_filter([$place, $yard['address'], $yard['hours']]))) ?></p>
    <div class="actions">
      <?php if ($wa): ?>
        <a class="btn wa" href="https://wa.me/<?= h($wa) ?>?text=<?= rawurlencode("Buongiorno, ho visto il vostro catalogo su SfascioHub. Cerco: ") ?>">WhatsApp</a>
      <?php endif ?>
      <?php if ($yard['phone']): ?>
        <a class="btn light" href="tel:<?= h(preg_replace('/\s+/', '', $yard['phone'])) ?>">Chiama</a>
      <?php endif ?>
      <?php if ($yard['address'] || $yard['city']): ?>
        <a class="btn light" target="_blank" rel="noopener" href="https://www.google.com/maps/search/?api=1&query=<?= rawurlencode(trim("{$yard['name']} {$yard['address']} {$yard['city']}")) ?>">Indicazioni</a>
      <?php endif ?>
      <button class="btn light" type="button" data-share="<?= h($self) ?>" data-title="<?= h($yard['name']) ?>">Condividi</button>
    </div>
  </div>
</header>
<main class="wrap">
  <?php if ($cars): ?>
    <input class="search" type="search" placeholder="Cerca marca, modello, anno…" aria-label="Cerca nel catalogo">
    <p class="count"><span id="n"><?= count($cars) ?></span> auto da cui recuperare ricambi</p>
    <div class="grid">
      <?php foreach ($cars as $c):
          $t = $title($c);
          $damage = array_map(fn($z) => ZONES[$z] ?? $z, $c['damage_zones']);
          $msg = "Buongiorno, ho visto su SfascioHub la $t" . ($c['year'] ? " {$c['year']}" : '') . '. Avete ancora questo pezzo: ';
          $search = strtolower("$t {$c['year']} {$c['fuel']} {$c['engine_code']}");
          ?>
        <article class="car<?= $focus && $focus['id'] === $c['id'] ? ' focus' : '' ?>" data-q="<?= h($search) ?>" id="auto-<?= h($c['id']) ?>">
          <div class="photo"<?= $c['vehicle_photos'] ? ' style="background-image:url(\'' . h($c['vehicle_photos'][0]['url']) . '\')"' : '' ?>>
            <?php if (!$c['vehicle_photos']): ?><div class="none">Foto in arrivo</div><?php endif ?>
            <span class="tag<?= $c['status'] === 'reserved' ? ' res' : '' ?>"><?= $c['status'] === 'reserved' ? 'Riservata' : 'Disponibile' ?></span>
          </div>
          <div class="body">
            <h2><?= h($t) ?></h2>
            <div class="meta"><?= h(implode(' · ', array_filter([(string) $c['year'], $c['fuel'], $c['km'] ? number_format($c['km'], 0, ',', '.') . ' km' : '', $c['engine_code'] ? "motore {$c['engine_code']}" : '']))) ?></div>
            <?php if ($damage): ?><div class="dmg">Danni: <?= h(implode(', ', $damage)) ?></div><?php endif ?>
            <?php if (!$damage): ?><div class="ok">Nessun danno segnato</div><?php endif ?>
            <div class="row">
              <?php if ($wa): ?>
                <a class="btn wa" href="https://wa.me/<?= h($wa) ?>?text=<?= rawurlencode($msg) ?>">Chiedi un pezzo</a>
              <?php endif ?>
              <a class="btn ghost" href="<?= h("$base/#/veicolo/{$c['id']}") ?>">Dettagli</a>
              <button class="btn ghost" type="button" data-share="<?= h("$self?auto={$c['id']}") ?>" data-title="<?= h($t) ?>" aria-label="Condividi <?= h($t) ?>">↗</button>
            </div>
          </div>
        </article>
      <?php endforeach ?>
    </div>
  <?php else: ?>
    <div class="empty">Nessuna auto in catalogo in questo momento. Contatta il piazzale: i ricambi potrebbero esserci lo stesso.</div>
  <?php endif ?>
</main>
<footer>Catalogo su <a href="<?= h("$base/") ?>">SfascioHub</a>: i ricambi usati dagli sfasciacarrozze.</footer>
<script>
  // condividi: menu del telefono se c'è, altrimenti copia il link
  document.querySelectorAll('[data-share]').forEach(function (b) {
    b.addEventListener('click', function () {
      var url = b.getAttribute('data-share'), title = b.getAttribute('data-title');
      if (navigator.share) { navigator.share({ title: title, url: url }).catch(function () {}); return; }
      navigator.clipboard && navigator.clipboard.writeText(url).then(function () { b.textContent = 'Link copiato'; });
    });
  });
  // ricerca nel catalogo
  var q = document.querySelector('.search');
  if (q) q.addEventListener('input', function () {
    var words = q.value.toLowerCase().split(/\s+/).filter(Boolean), n = 0;
    document.querySelectorAll('.car').forEach(function (c) {
      var hay = c.getAttribute('data-q'), show = words.every(function (w) { return hay.indexOf(w) >= 0; });
      c.style.display = show ? '' : 'none';
      if (show) n++;
    });
    document.getElementById('n').textContent = n;
  });
  // statistiche del piazzale: una visita al catalogo; i tocchi su WhatsApp contano come contatti
  function track(kind, extra) {
    var body = Object.assign({ kind: kind, yard_id: <?= json_encode($yard['id']) ?> }, extra || {});
    try { navigator.sendBeacon('<?= h("$base/api/index.php?r=/events") ?>', new Blob([JSON.stringify(body)], { type: 'application/json' })); } catch (e) {}
  }
  track('yard_view');
  document.querySelectorAll('a.wa').forEach(function (a) {
    a.addEventListener('click', function () {
      var car = a.closest('.car');
      track('whatsapp', car ? { vehicle_id: car.id.replace('auto-', '') } : {});
    });
  });
<?php if ($focus): ?>
  document.getElementById('auto-<?= h($focus['id']) ?>').scrollIntoView({ block: 'start' });
<?php endif ?>
</script>
</body>
</html>
