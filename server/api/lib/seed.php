<?php
// Dati di esempio (facoltativi): 3 sfasciacarrozze, 16 veicoli e un account demo.
declare(strict_types=1);

const DEMO_EMAIL = 'demo@sfasciohub.it';
const DEMO_PASSWORD = 'demo1234';

function seed_demo(PDO $pdo): void
{
    $st = $pdo->prepare('SELECT 1 FROM users WHERE email = ?');
    $st->execute([DEMO_EMAIL]);
    if ($st->fetchColumn()) {
        return;
    }
    $now = now();
    $demoUser = uuid();
    $seedUser = uuid();
    $ins = $pdo->prepare('INSERT INTO users (id, email, password_hash, created_at) VALUES (?, ?, ?, ?)');
    $ins->execute([$demoUser, DEMO_EMAIL, password_hash(DEMO_PASSWORD, PASSWORD_DEFAULT), $now]);
    // i due piazzali di esempio senza account vero
    $ins->execute([$seedUser, 'esempi@sfasciohub.invalid', password_hash(bin2hex(random_bytes(16)), PASSWORD_DEFAULT), $now]);

    $hours = 'Lun–Ven 8:30–12:30 / 14:00–18:30 · Sab 8:30–12:30';
    $yards = [
        'martesana' => [$demoUser, "Autodemolizioni Martesana (demo)", "Cassina de' Pecchi", 'MI', "Via dell'Industria 12", '+39 02 0000 0001',
            'Piazzale di 4.000 m² con oltre 200 veicoli. Smontaggio su richiesta e spedizione ricambi in tutta Italia.', 45.522, 9.362],
        'brianza' => [$seedUser, 'Ricambi Usati Brianza (demo)', 'Monza', 'MB', 'Viale delle Industrie 45', '+39 039 000 0002',
            'Specializzati in utilitarie e SUV recenti. Ricambi testati e garantiti 3 mesi.', 45.585, 9.274],
        'bergamo' => [$seedUser, 'Sfasciacarrozze Orobico (demo)', 'Treviglio', 'BG', 'Strada Provinciale 11 km 4', '+39 0363 000 003',
            'Dal 1987. Auto, furgoni e moto. Possibilità di smontaggio fai-da-te il sabato mattina.', 45.521, 9.592],
    ];
    $yardIds = [];
    $y = $pdo->prepare('INSERT INTO yards (id, owner_id, name, city, province, address, phone, whatsapp, email, hours, description, lat, lng, published, created_at)
                        VALUES (?, ?, ?, ?, ?, ?, ?, ?, \'\', ?, ?, ?, ?, 1, ?)');
    $m = $pdo->prepare("INSERT INTO yard_members (yard_id, user_id, role) VALUES (?, ?, 'owner')");
    foreach ($yards as $key => [$owner, $name, $city, $prov, $addr, $phone, $desc, $lat, $lng]) {
        $id = uuid();
        $yardIds[$key] = $id;
        $y->execute([$id, $owner, $name, $city, $prov, $addr, $phone, $phone, $hours, $desc, $lat, $lng, $now]);
        $m->execute([$id, $owner]);
    }

    $vehicles = [
        ['martesana', 'Fiat', 'Panda', '1.2 Easy', 2016, 'benzina', 'Bianco', 98000, 'front,front_left', 'Urto frontale. Motore 169A4000 integro e funzionante, porte e portellone perfetti.', 2, 'available', '169A4000'],
        ['martesana', 'Volkswagen', 'Golf', 'VII 1.6 TDI', 2014, 'diesel', 'Grigio', 187000, 'rear,rear_left,rear_right', 'Tamponamento posteriore. Frontale, fari LED e motore CLHA in ottimo stato.', 5, 'available', 'CLHA'],
        ['martesana', 'Toyota', 'Yaris', 'Hybrid Active', 2019, 'ibrida', 'Rosso', 64000, 'left', 'Fiancata sinistra danneggiata. Gruppo ibrido, interni e frontale integri.', 9, 'available', ''],
        ['martesana', 'Renault', 'Clio', 'IV 0.9 TCe', 2017, 'benzina', 'Blu', 112000, 'engine', 'Motore rotto (catena). Carrozzeria completa senza danni.', 14, 'available', ''],
        ['martesana', 'Ford', 'Fiesta', '1.0 EcoBoost', 2018, 'benzina', 'Nero', 76000, 'front,glass,interior', 'Frontale importante con airbag esplosi. Posteriore e porte recuperabili.', 21, 'reserved', ''],
        ['brianza', 'Jeep', 'Renegade', '1.6 Mjt Limited', 2018, 'diesel', 'Verde', 134000, 'front_right,right', 'Urto laterale destro. Lato sinistro, frontale e motore in ordine.', 1, 'available', ''],
        ['brianza', 'Peugeot', '208', '1.2 PureTech', 2020, 'benzina', 'Arancione', 41000, 'rear', 'Posteriore danneggiato. Tutto il resto praticamente nuovo.', 3, 'available', ''],
        ['brianza', 'Audi', 'A3', 'Sportback 2.0 TDI', 2015, 'diesel', 'Bianco', 201000, 'front,front_left,front_right,glass', 'Frontale distrutto. Interni in pelle, cambio S-tronic e posteriore integri.', 8, 'available', ''],
        ['brianza', 'Dacia', 'Sandero', 'Stepway 0.9', 2019, 'gpl', 'Grigio', 88000, 'roof,glass', 'Ribaltata: tetto e vetri da buttare. Meccanica e frontale buoni.', 12, 'available', ''],
        ['brianza', 'Mercedes-Benz', 'Classe A', 'A 180 d', 2016, 'diesel', 'Argento', 156000, 'rear_left,left', 'Danni lato sinistro posteriore. Fari, cofano e motore OM607 integri.', 30, 'available', 'OM607'],
        ['bergamo', 'Fiat', 'Punto', 'Evo 1.3 Mjt', 2011, 'diesel', 'Nero', 214000, 'front', 'Frontale. Porte, sedili e cambio recuperabili.', 4, 'available', ''],
        ['bergamo', 'Opel', 'Corsa', 'E 1.2', 2016, 'benzina', 'Bianco', 93000, 'right,rear_right', 'Lato destro. Motore e frontale ok.', 6, 'available', ''],
        ['bergamo', 'Lancia', 'Ypsilon', '1.2 Gold', 2017, 'gpl', 'Beige', 104000, 'engine,interior', 'Allagata: elettronica e interni da sostituire. Carrozzeria perfetta.', 10, 'available', ''],
        ['bergamo', 'BMW', 'Serie 1', '116d', 2013, 'diesel', 'Blu', 178000, 'front,front_right', 'Frontale destro. Posteriore, cerchi e interni ottimi.', 18, 'available', ''],
        ['bergamo', 'Citroën', 'C3', '1.2 PureTech', 2018, 'benzina', 'Rosso', 69000, 'rear,glass', 'Tamponata. Frontale e motore come nuovi.', 25, 'available', ''],
        ['bergamo', 'Smart', 'ForTwo', '1.0 Passion', 2015, 'benzina', 'Giallo', 58000, 'front_left,left', 'Urto lato sinistro. Motore e lato destro integri.', 40, 'available', ''],
    ];
    $v = $pdo->prepare('INSERT INTO vehicles (id, yard_id, make, model, version, year, fuel, color, km, engine_code, damage_zones, notes, status, published, arrived_on, created_at, updated_at)
                        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1, ?, ?, ?)');
    foreach ($vehicles as [$yard, $make, $model, $ver, $year, $fuel, $color, $km, $dmg, $notes, $days, $status, $engine]) {
        $v->execute([uuid(), $yardIds[$yard], $make, $model, $ver, $year, $fuel, $color, $km, $engine, $dmg, $notes, $status,
            gmdate('Y-m-d', time() - $days * 86400), $now, $now]);
    }
}
