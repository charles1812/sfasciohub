import 'dart:convert';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'models.dart';
import 'repository.dart';

const demoEmail = 'demo@sfasciohub.it';
const demoPassword = 'demo1234';

/// Dati di esempio salvati sul dispositivo (nel browser: localStorage, che il
/// sito pubblico e la console di gestione condividono). Serve a provare tutto
/// senza un account Supabase.
class DemoRepository extends Repository {
  DemoRepository._(this._prefs);

  static const _key = 'sfasciohub_demo_v2';
  final SharedPreferences _prefs;
  final _uuid = const Uuid();

  late List<Yard> _yards;
  late List<Vehicle> _vehicles;
  late Map<String, String> _users; // email -> password
  late Map<String, String> _yardOf; // email -> yard id
  String? _session;

  static Future<DemoRepository> create() async {
    final r = DemoRepository._(await SharedPreferences.getInstance());
    r._load();
    return r;
  }

  void _load() {
    final raw = _prefs.getString(_key);
    if (raw == null) {
      _seed();
      return;
    }
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      _yards = (j['yards'] as List).map((y) => Yard.fromJson(y as Map<String, dynamic>)).toList();
      _vehicles = (j['vehicles'] as List).map((v) => Vehicle.fromJson(v as Map<String, dynamic>)).toList();
      _users = (j['users'] as Map).cast<String, String>();
      _yardOf = (j['yardOf'] as Map).cast<String, String>();
      _session = j['session'] as String?;
    } catch (_) {
      _seed();
    }
  }

  /// Rilegge lo stato salvato: nel browser un'altra scheda può averlo cambiato.
  void _refresh() {
    _prefs.reload();
    _load();
  }

  Future<void> _save() async {
    final j = {
      'yards': _yards.map((y) => y.toJson()).toList(),
      'vehicles': _vehicles
          .map((v) => {
                ...v.toRow(),
                'vehicle_photos': v.photos.map((p) => {'id': p.id, 'url': p.url, 'position': p.position}).toList(),
              })
          .toList(),
      'users': _users,
      'yardOf': _yardOf,
      'session': _session,
    };
    try {
      await _prefs.setString(_key, jsonEncode(j));
    } catch (_) {
      throw RepoException('Spazio esaurito nella demo: elimina qualche foto o veicolo.');
    }
  }

  Vehicle _withYard(Vehicle v) => v..yard = _yards.where((y) => y.id == v.yardId).firstOrNull;

  bool _isPublic(Vehicle v) {
    final y = _yards.where((y) => y.id == v.yardId).firstOrNull;
    return v.published && v.status != VehicleStatus.gone && (y?.published ?? false);
  }

  @override
  bool get isDemo => true;

  // ---- pubblico ----
  @override
  Future<List<Vehicle>> searchVehicles(VehicleFilter filter) async {
    _refresh();
    final list = _vehicles.where(_isPublic).map(_withYard).where(filter.matches).toList()
      ..sort((a, b) => b.arrivedOn.compareTo(a.arrivedOn));
    return list;
  }

  @override
  Future<Vehicle?> vehicle(String id) async {
    _refresh();
    final v = _vehicles.where((v) => v.id == id).firstOrNull;
    return v == null ? null : _withYard(v.copy());
  }

  @override
  Future<List<Yard>> yards() async {
    _refresh();
    return _yards.where((y) => y.published).toList()..sort((a, b) => a.name.compareTo(b.name));
  }

  @override
  Future<Yard?> yard(String id) async => _yards.where((y) => y.id == id).firstOrNull;

  @override
  Future<Map<String, int>> vehicleCounts() async {
    _refresh();
    final c = <String, int>{};
    for (final v in _vehicles.where(_isPublic)) {
      c[v.yardId] = (c[v.yardId] ?? 0) + 1;
    }
    return c;
  }

  // ---- account ----
  @override
  AppUser? get currentUser => _session == null ? null : AppUser(id: _session!, email: _session!);

  @override
  Future<void> signIn(String email, String password) async {
    final e = email.trim().toLowerCase();
    if (_users[e] != password) throw RepoException('Email o password non corretti. Nella demo usa $demoEmail / $demoPassword.');
    _session = e;
    await _save();
    notifyListeners();
  }

  @override
  Future<bool> signUp(String email, String password) async {
    final e = email.trim().toLowerCase();
    if (!e.contains('@')) throw RepoException('Inserisci un indirizzo email valido.');
    if (password.length < 8) throw RepoException('La password deve avere almeno 8 caratteri.');
    if (_users.containsKey(e)) throw RepoException('Esiste già un account con questa email.');
    _users[e] = password;
    _session = e;
    await _save();
    notifyListeners();
    return false;
  }

  @override
  Future<void> signOut() async {
    _session = null;
    await _save();
    notifyListeners();
  }

  // ---- gestione ----
  @override
  Future<Yard?> myYard() async {
    _refresh();
    final id = _yardOf[_session];
    return _yards.where((y) => y.id == id).firstOrNull;
  }

  @override
  Future<Yard> createYard(Yard draft) async {
    final y = Yard.fromJson({...draft.toJson(), 'id': _uuid.v4(), 'owner_id': _session});
    _yards.add(y);
    _yardOf[_session!] = y.id;
    await _save();
    notifyListeners();
    return y;
  }

  @override
  Future<void> updateYard(Yard yard) async {
    final i = _yards.indexWhere((y) => y.id == yard.id);
    if (i >= 0) _yards[i] = yard;
    await _save();
    notifyListeners();
  }

  @override
  Future<List<Vehicle>> myVehicles() async {
    final y = await myYard();
    if (y == null) return [];
    return _vehicles.where((v) => v.yardId == y.id).map((v) => _withYard(v.copy())).toList()
      ..sort((a, b) => b.arrivedOn.compareTo(a.arrivedOn));
  }

  @override
  Future<Vehicle> saveVehicle(Vehicle v) async {
    final i = _vehicles.indexWhere((x) => x.id == v.id);
    final stored = v.copy()..yard = null;
    if (i >= 0) {
      stored.photos = _vehicles[i].photos;
      _vehicles[i] = stored;
    } else {
      _vehicles.add(stored);
    }
    await _save();
    notifyListeners();
    return _withYard(stored.copy());
  }

  @override
  Future<void> deleteVehicle(Vehicle v) async {
    _vehicles.removeWhere((x) => x.id == v.id);
    await _save();
    notifyListeners();
  }

  @override
  Future<VehiclePhoto> addPhoto(Vehicle v, Uint8List jpeg, int position) async {
    final stored = _vehicles.firstWhere((x) => x.id == v.id);
    final p = VehiclePhoto(id: _uuid.v4(), url: 'data:image/jpeg;base64,${base64Encode(jpeg)}', position: position);
    stored.photos.add(p);
    try {
      await _save();
    } catch (e) {
      stored.photos.remove(p);
      rethrow;
    }
    return p;
  }

  @override
  Future<void> removePhoto(Vehicle v, VehiclePhoto photo) async {
    _vehicles.firstWhere((x) => x.id == v.id).photos.removeWhere((p) => p.id == photo.id);
    await _save();
  }

  @override
  Future<void> reorderPhotos(Vehicle v, List<String> photoIds) async {
    final stored = _vehicles.firstWhere((x) => x.id == v.id);
    final byId = {for (final p in stored.photos) p.id: p};
    stored.photos = [
      for (final (i, id) in photoIds.indexed)
        if (byId[id] case final p?) VehiclePhoto(id: p.id, url: p.url, position: i),
    ];
    await _save();
  }

  // ---- dati di esempio ----
  void _seed() {
    Yard yard(String id, String name, String city, String prov, String address, String phone, String desc, double lat, double lng) =>
        Yard(
          id: id,
          ownerId: 'seed',
          name: name,
          city: city,
          province: prov,
          address: address,
          phone: phone,
          whatsapp: phone,
          hours: 'Lun–Ven 8:30–12:30 / 14:00–18:30 · Sab 8:30–12:30',
          description: desc,
          lat: lat,
          lng: lng,
        );
    _yards = [
      yard('y-martesana', 'Autodemolizioni Martesana (demo)', 'Cassina de\' Pecchi', 'MI', 'Via dell\'Industria 12',
          '+39 02 0000 0001', 'Piazzale di 4.000 m² con oltre 200 veicoli. Smontaggio su richiesta e spedizione ricambi in tutta Italia.', 45.522, 9.362),
      yard('y-brianza', 'Ricambi Usati Brianza (demo)', 'Monza', 'MB', 'Viale delle Industrie 45',
          '+39 039 000 0002', 'Specializzati in utilitarie e SUV recenti. Ricambi testati e garantiti 3 mesi.', 45.585, 9.274),
      yard('y-bergamo', 'Sfasciacarrozze Orobico (demo)', 'Treviglio', 'BG', 'Strada Provinciale 11 km 4',
          '+39 0363 000 003', 'Dal 1987. Auto, furgoni e moto. Possibilità di smontaggio fai-da-te il sabato mattina.', 45.521, 9.592),
    ];
    final now = DateTime.now();
    Vehicle v(String yardId, String make, String model, String version, int year, String fuel, String color, int km,
            List<DamageZone> dmg, String notes, int daysAgo,
            {VehicleStatus status = VehicleStatus.available, String engine = ''}) =>
        Vehicle(
          id: _uuid.v4(),
          yardId: yardId,
          make: make,
          model: model,
          version: version,
          year: year,
          fuel: fuel,
          color: color,
          km: km,
          engineCode: engine,
          damage: dmg.toSet(),
          notes: notes,
          status: status,
          arrivedOn: now.subtract(Duration(days: daysAgo)),
        );
    const f = DamageZone.front, fl = DamageZone.frontLeft, fr = DamageZone.frontRight, l = DamageZone.left,
        r = DamageZone.right, b = DamageZone.rear, rl = DamageZone.rearLeft, rr = DamageZone.rearRight,
        g = DamageZone.glass, e = DamageZone.engine, i = DamageZone.interior, t = DamageZone.roof;
    _vehicles = [
      v('y-martesana', 'Fiat', 'Panda', '1.2 Easy', 2016, 'benzina', 'Bianco', 98000, [f, fl], 'Urto frontale. Motore 169A4000 integro e funzionante, porte e portellone perfetti.', 2, engine: '169A4000'),
      v('y-martesana', 'Volkswagen', 'Golf', 'VII 1.6 TDI', 2014, 'diesel', 'Grigio', 187000, [b, rl, rr], 'Tamponamento posteriore. Frontale, fari LED e motore CLHA in ottimo stato.', 5, engine: 'CLHA'),
      v('y-martesana', 'Toyota', 'Yaris', 'Hybrid Active', 2019, 'ibrida', 'Rosso', 64000, [l], 'Fiancata sinistra danneggiata. Gruppo ibrido, interni e frontale integri.', 9),
      v('y-martesana', 'Renault', 'Clio', 'IV 0.9 TCe', 2017, 'benzina', 'Blu', 112000, [e], 'Motore rotto (catena). Carrozzeria completa senza danni.', 14),
      v('y-martesana', 'Ford', 'Fiesta', '1.0 EcoBoost', 2018, 'benzina', 'Nero', 76000, [f, g, i], 'Frontale importante con airbag esplosi. Posteriore e porte recuperabili.', 21, status: VehicleStatus.reserved),
      v('y-brianza', 'Jeep', 'Renegade', '1.6 Mjt Limited', 2018, 'diesel', 'Verde', 134000, [fr, r], 'Urto laterale destro. Lato sinistro, frontale e motore in ordine.', 1),
      v('y-brianza', 'Peugeot', '208', '1.2 PureTech', 2020, 'benzina', 'Arancione', 41000, [b], 'Posteriore danneggiato. Tutto il resto praticamente nuovo.', 3),
      v('y-brianza', 'Audi', 'A3', 'Sportback 2.0 TDI', 2015, 'diesel', 'Bianco', 201000, [f, fl, fr, g], 'Frontale distrutto. Interni in pelle, cambio S-tronic e posteriore integri.', 8),
      v('y-brianza', 'Dacia', 'Sandero', 'Stepway 0.9', 2019, 'gpl', 'Grigio', 88000, [t, g], 'Ribaltata: tetto e vetri da buttare. Meccanica e frontale buoni.', 12),
      v('y-brianza', 'Mercedes-Benz', 'Classe A', 'A 180 d', 2016, 'diesel', 'Argento', 156000, [rl, l], 'Danni lato sinistro posteriore. Fari, cofano e motore OM607 integri.', 30, engine: 'OM607'),
      v('y-bergamo', 'Fiat', 'Punto', 'Evo 1.3 Mjt', 2011, 'diesel', 'Nero', 214000, [f], 'Frontale. Porte, sedili e cambio recuperabili.', 4),
      v('y-bergamo', 'Opel', 'Corsa', 'E 1.2', 2016, 'benzina', 'Bianco', 93000, [r, rr], 'Lato destro. Motore e frontale ok.', 6),
      v('y-bergamo', 'Lancia', 'Ypsilon', '1.2 Gold', 2017, 'gpl', 'Beige', 104000, [e, i], 'Allagata: elettronica e interni da sostituire. Carrozzeria perfetta.', 10),
      v('y-bergamo', 'BMW', 'Serie 1', '116d', 2013, 'diesel', 'Blu', 178000, [f, fr], 'Frontale destro. Posteriore, cerchi e interni ottimi.', 18),
      v('y-bergamo', 'Citroën', 'C3', '1.2 PureTech', 2018, 'benzina', 'Rosso', 69000, [b, g], 'Tamponata. Frontale e motore come nuovi.', 25),
      v('y-bergamo', 'Smart', 'ForTwo', '1.0 Passion', 2015, 'benzina', 'Giallo', 58000, [fl, l], 'Urto lato sinistro. Motore e lato destro integri.', 40),
    ];
    _users = {demoEmail: demoPassword};
    _yardOf = {demoEmail: 'y-martesana'};
    _session = null;
    _save();
  }

  // Nella demo offline non c'è un server che possa chiamare l'AI.
  @override
  Future<int?> aiRemaining() async => null;

  @override
  Future<AiResult> analyzePhotos({List<Uint8List> images = const [], List<String> photoIds = const []}) =>
      throw RepoException('Il riconoscimento dalle foto funziona solo con il server.');

  @override
  Future<List<VehiclePart>> parts(Vehicle v) async => [];

  @override
  Future<List<VehiclePart>> generateParts(Vehicle v) =>
      throw RepoException("La lista ricambi con l'AI funziona solo con il server.");

  @override
  Future<List<VehiclePart>> updateParts(Vehicle v, List<VehiclePart> changed) async => changed;
}
