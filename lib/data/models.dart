/// Zone di un veicolo che possono essere danneggiate. Il resto del veicolo è
/// presumibilmente integro: è da lì che si recuperano i ricambi.
enum DamageZone {
  front('front', 'Frontale', 'Paraurti ant., cofano, fari, radiatore'),
  frontLeft('front_left', 'Anteriore sinistro', 'Parafango e ruota ant. sx'),
  frontRight('front_right', 'Anteriore destro', 'Parafango e ruota ant. dx'),
  left('left', 'Fiancata sinistra', 'Porte e specchietto sx'),
  right('right', 'Fiancata destra', 'Porte e specchietto dx'),
  rearLeft('rear_left', 'Posteriore sinistro', 'Parafango e ruota post. sx'),
  rearRight('rear_right', 'Posteriore destro', 'Parafango e ruota post. dx'),
  rear('rear', 'Posteriore', 'Paraurti post., portellone, fanali'),
  roof('roof', 'Tetto', 'Tetto e montanti'),
  glass('glass', 'Vetri', 'Parabrezza, lunotto, cristalli'),
  engine('engine', 'Motore / meccanica', 'Motore, cambio, sospensioni'),
  interior('interior', 'Interni', 'Sedili, cruscotto, airbag');

  const DamageZone(this.key, this.label, this.parts);
  final String key;
  final String label;
  final String parts;

  static DamageZone? fromKey(String k) {
    for (final z in values) {
      if (z.key == k) return z;
    }
    return null;
  }
}

/// Stato di un ricambio nella lista del veicolo.
enum PartStatus {
  ok('ok', 'Sano'),
  check('check', 'Da verificare'),
  damaged('damaged', 'Danneggiato');

  const PartStatus(this.key, this.label);
  final String key;
  final String label;

  static PartStatus fromKey(String? k) => values.firstWhere((s) => s.key == k, orElse: () => check);

  /// Tocco sul pezzo: sano → danneggiato → da verificare → sano.
  PartStatus get next => switch (this) { ok => damaged, damaged => check, check => ok };
}

/// Un ricambio del veicolo: proposto dall'AI, confermato o corretto dal piazzale.
class VehiclePart {
  VehiclePart({required this.id, required this.name, required this.zone, required this.status, this.confirmed = false});
  final String id;
  final String name;
  final DamageZone? zone;
  PartStatus status;
  bool confirmed;

  factory VehiclePart.fromJson(Map<String, dynamic> j) => VehiclePart(
        id: j['id'] as String,
        name: j['name'] as String,
        zone: DamageZone.fromKey(j['zone'] as String? ?? ''),
        status: PartStatus.fromKey(j['status'] as String?),
        confirmed: j['confirmed'] == true,
      );
}

enum VehicleStatus {
  available('available', 'Disponibile'),
  reserved('reserved', 'Riservato'),
  gone('gone', 'Demolito / venduto');

  const VehicleStatus(this.key, this.label);
  final String key;
  final String label;

  static VehicleStatus fromKey(String? k) =>
      values.firstWhere((s) => s.key == k, orElse: () => available);
}

const fuels = <String, String>{
  '': '—',
  'benzina': 'Benzina',
  'diesel': 'Diesel',
  'gpl': 'GPL',
  'metano': 'Metano',
  'ibrida': 'Ibrida',
  'elettrica': 'Elettrica',
};

/// Marche più comuni nei piazzali italiani, per l'autocompletamento.
const commonMakes = [
  'Alfa Romeo', 'Audi', 'BMW', 'Citroën', 'Dacia', 'DS', 'Fiat', 'Ford', 'Honda',
  'Hyundai', 'Jeep', 'Kia', 'Lancia', 'Land Rover', 'Mazda', 'Mercedes-Benz',
  'Mini', 'Mitsubishi', 'Nissan', 'Opel', 'Peugeot', 'Renault', 'Seat', 'Skoda',
  'Smart', 'Suzuki', 'Tesla', 'Toyota', 'Volkswagen', 'Volvo',
];

class Yard {
  Yard({
    required this.id,
    required this.ownerId,
    required this.name,
    this.city = '',
    this.province = '',
    this.address = '',
    this.phone = '',
    this.whatsapp = '',
    this.email = '',
    this.hours = '',
    this.description = '',
    this.lat,
    this.lng,
    this.published = true,
  });

  final String id;
  final String ownerId;
  String name;
  String city;
  String province;
  String address;
  String phone;
  String whatsapp;
  String email;
  String hours;
  String description;
  double? lat;
  double? lng;
  bool published;

  String get place => [city, if (province.isNotEmpty) '($province)'].where((s) => s.isNotEmpty).join(' ');

  factory Yard.fromJson(Map<String, dynamic> j) => Yard(
        id: j['id'] as String,
        ownerId: (j['owner_id'] ?? '') as String,
        name: (j['name'] ?? '') as String,
        city: (j['city'] ?? '') as String,
        province: (j['province'] ?? '') as String,
        address: (j['address'] ?? '') as String,
        phone: (j['phone'] ?? '') as String,
        whatsapp: (j['whatsapp'] ?? '') as String,
        email: (j['email'] ?? '') as String,
        hours: (j['hours'] ?? '') as String,
        description: (j['description'] ?? '') as String,
        lat: (j['lat'] as num?)?.toDouble(),
        lng: (j['lng'] as num?)?.toDouble(),
        published: (j['published'] ?? true) as bool,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'owner_id': ownerId,
        'name': name,
        'city': city,
        'province': province,
        'address': address,
        'phone': phone,
        'whatsapp': whatsapp,
        'email': email,
        'hours': hours,
        'description': description,
        'lat': lat,
        'lng': lng,
        'published': published,
      };
}

class VehiclePhoto {
  VehiclePhoto({required this.id, required this.url, this.position = 0});
  final String id;

  /// URL pubblico (Supabase) oppure `data:` URI (modalità demo).
  final String url;
  final int position;
}

class Vehicle {
  Vehicle({
    required this.id,
    required this.yardId,
    required this.make,
    required this.model,
    this.version = '',
    this.year,
    this.fuel = '',
    this.color = '',
    this.km,
    this.engineCode = '',
    Set<DamageZone>? damage,
    this.notes = '',
    this.status = VehicleStatus.available,
    this.published = true,
    DateTime? arrivedOn,
    List<VehiclePhoto>? photos,
    this.yard,
    List<VehiclePart>? parts,
  })  : damage = damage ?? {},
        parts = parts ?? [],
        arrivedOn = arrivedOn ?? DateTime.now(),
        photos = photos ?? [];

  final String id;
  final String yardId;
  String make;
  String model;
  String version;
  int? year;
  String fuel;
  String color;
  int? km;
  String engineCode;
  Set<DamageZone> damage;
  String notes;
  VehicleStatus status;
  bool published;
  DateTime arrivedOn;
  List<VehiclePhoto> photos;

  /// Lista dei ricambi (solo nella scheda singola, se è stata generata).
  List<VehiclePart> parts;

  /// Lo sfasciacarrozze, quando caricato insieme al veicolo.
  Yard? yard;

  String get title => '$make $model${version.isNotEmpty ? ' $version' : ''}';
  String get subtitle => [
        if (year != null) '$year',
        if (fuel.isNotEmpty) fuels[fuel]!,
        if (km != null) '${_thousands(km!)} km',
      ].join(' · ');

  /// Zone integre, cioè dove probabilmente ci sono ricambi buoni.
  List<DamageZone> get intactZones => DamageZone.values.where((z) => !damage.contains(z)).toList();

  Vehicle copy() => Vehicle(
        id: id,
        yardId: yardId,
        make: make,
        model: model,
        version: version,
        year: year,
        fuel: fuel,
        color: color,
        km: km,
        engineCode: engineCode,
        damage: {...damage},
        notes: notes,
        status: status,
        published: published,
        arrivedOn: arrivedOn,
        photos: [...photos],
        yard: yard,
        parts: [...parts],
      );

  factory Vehicle.fromJson(Map<String, dynamic> j, {String Function(String path)? photoUrl}) {
    final photos = ((j['vehicle_photos'] as List?) ?? [])
        .cast<Map<String, dynamic>>()
        .map((p) => VehiclePhoto(
              id: p['id'] as String,
              url: photoUrl != null ? photoUrl(p['path'] as String) : (p['url'] ?? p['path']) as String,
              position: (p['position'] ?? 0) as int,
            ))
        .toList()
      ..sort((a, b) => a.position.compareTo(b.position));
    return Vehicle(
      id: j['id'] as String,
      yardId: j['yard_id'] as String,
      make: (j['make'] ?? '') as String,
      model: (j['model'] ?? '') as String,
      version: (j['version'] ?? '') as String,
      year: j['year'] as int?,
      fuel: (j['fuel'] ?? '') as String,
      color: (j['color'] ?? '') as String,
      km: j['km'] as int?,
      engineCode: (j['engine_code'] ?? '') as String,
      damage: ((j['damage_zones'] as List?) ?? []).map((k) => DamageZone.fromKey(k as String)).whereType<DamageZone>().toSet(),
      notes: (j['notes'] ?? '') as String,
      status: VehicleStatus.fromKey(j['status'] as String?),
      published: (j['published'] ?? true) as bool,
      arrivedOn: DateTime.tryParse((j['arrived_on'] ?? '') as String),
      photos: photos,
      yard: j['yards'] is Map<String, dynamic> ? Yard.fromJson(j['yards'] as Map<String, dynamic>) : null,
      parts: ((j['parts'] as List?) ?? []).map((p) => VehiclePart.fromJson(p as Map<String, dynamic>)).toList(),
    );
  }

  /// Colonne della tabella `vehicles` (foto e sfasciacarrozze esclusi).
  Map<String, dynamic> toRow() => {
        'id': id,
        'yard_id': yardId,
        'make': make,
        'model': model,
        'version': version,
        'year': year,
        'fuel': fuel,
        'color': color,
        'km': km,
        'engine_code': engineCode,
        'damage_zones': damage.map((z) => z.key).toList(),
        'notes': notes,
        'status': status.key,
        'published': published,
        'arrived_on': arrivedOn.toIso8601String().substring(0, 10),
      };
}

class VehicleFilter {
  const VehicleFilter({this.query = '', this.make, this.province, this.yearFrom, this.yearTo, this.needIntact, this.yardId});
  final String query;
  final String? make;
  final String? province;
  final int? yearFrom;
  final int? yearTo;

  /// Mostra solo veicoli con questa zona integra (es. "mi serve il frontale").
  final DamageZone? needIntact;
  final String? yardId;

  bool matches(Vehicle v) {
    final q = query.trim().toLowerCase();
    if (q.isNotEmpty) {
      final hay = '${v.make} ${v.model} ${v.version} ${v.engineCode} ${v.yard?.city ?? ''}'.toLowerCase();
      if (!q.split(RegExp(r'\s+')).every(hay.contains)) return false;
    }
    if (make != null && v.make != make) return false;
    if (province != null && v.yard?.province != province) return false;
    if (yearFrom != null && (v.year == null || v.year! < yearFrom!)) return false;
    if (yearTo != null && (v.year == null || v.year! > yearTo!)) return false;
    if (needIntact != null && v.damage.contains(needIntact)) return false;
    if (yardId != null && v.yardId != yardId) return false;
    return true;
  }
}

String _thousands(int n) {
  final s = n.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return b.toString();
}
