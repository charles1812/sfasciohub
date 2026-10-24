import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import 'models.dart';
import 'repository.dart';

const _tokenKey = 'sfasciohub_token';

/// Piattaforma vera: l'API PHP + MySQL sul server (cartella `server/`).
class PhpRepository extends Repository {
  PhpRepository._(this._base, this._prefs);

  final Uri _base;
  final SharedPreferences _prefs;
  final _client = http.Client();
  String? _token;
  AppUser? _user;

  static Future<PhpRepository> create() async {
    // sul web l'indirizzo può essere relativo al sito (es. "api/")
    final base = Uri.base.resolve(AppConfig.apiUrl);
    final r = PhpRepository._(base, await SharedPreferences.getInstance());
    r._token = r._prefs.getString(_tokenKey);
    if (r._token != null) {
      try {
        final me = await r._call('GET', '/auth/me') as Map<String, dynamic>;
        r._user = _userFrom(me['user']);
      } on RepoException {
        await r._setToken(null);
      }
    }
    return r;
  }

  static AppUser _userFrom(dynamic u) => AppUser(id: u['id'] as String, email: u['email'] as String);

  Future<void> _setToken(String? t) async {
    _token = t;
    t == null ? await _prefs.remove(_tokenKey) : await _prefs.setString(_tokenKey, t);
  }

  Uri _uri(String route, [Map<String, String>? query]) {
    final q = {..._base.queryParameters, 'r': route, ...?query};
    final path = _base.path.endsWith('/') ? '${_base.path}index.php' : _base.path;
    return _base.replace(path: path, queryParameters: q);
  }

  Future<dynamic> _call(String method, String route,
      {Object? json, Uint8List? bytes, String? contentType, Map<String, String>? query,
      Duration timeout = const Duration(seconds: 40)}) async {
    final req = http.Request(method, _uri(route, query));
    if (_token != null) {
      req.headers['Authorization'] = 'Bearer $_token';
      req.headers['X-Auth-Token'] = _token!;
    }
    if (json != null) {
      req.headers['Content-Type'] = 'application/json';
      req.body = jsonEncode(json);
    } else if (bytes != null) {
      req.headers['Content-Type'] = contentType ?? 'application/octet-stream';
      req.bodyBytes = bytes;
    }
    final http.Response res;
    try {
      res = await http.Response.fromStream(await _client.send(req).timeout(timeout));
    } catch (_) {
      throw RepoException('Server non raggiungibile. Controlla la connessione e riprova.');
    }
    dynamic data;
    try {
      data = res.body.isEmpty ? null : jsonDecode(utf8.decode(res.bodyBytes));
    } catch (_) {
      throw RepoException('Risposta non valida dal server (${res.statusCode}).');
    }
    if (res.statusCode >= 400) {
      if (res.statusCode == 401 && _token != null && route != '/auth/login') {
        await _setToken(null);
        _user = null;
        notifyListeners();
      }
      final msg = data is Map && data['error'] is String ? data['error'] as String : 'Errore ${res.statusCode}';
      throw RepoException(msg);
    }
    return data;
  }

  List<Vehicle> _vehicles(dynamic list) =>
      (list as List).map((j) => Vehicle.fromJson(j as Map<String, dynamic>)).toList();

  @override
  bool get isDemo => false;

  // ---- pubblico ----
  @override
  Future<List<Vehicle>> searchVehicles(VehicleFilter f) async {
    final list = _vehicles(await _call('GET', '/vehicles', query: {
      if (f.yardId != null) 'yard_id': f.yardId!,
      if (f.make != null) 'make': f.make!,
      if (f.province != null) 'province': f.province!,
      if (f.yearFrom != null) 'year_from': '${f.yearFrom}',
      if (f.yearTo != null) 'year_to': '${f.yearTo}',
    }));
    return list.where(f.matches).toList();
  }

  @override
  Future<Vehicle?> vehicle(String id) async {
    try {
      return Vehicle.fromJson(await _call('GET', '/vehicles/$id') as Map<String, dynamic>);
    } on RepoException {
      return null;
    }
  }

  @override
  Future<List<Yard>> yards() async =>
      ((await _call('GET', '/yards')) as List).map((j) => Yard.fromJson(j as Map<String, dynamic>)).toList();

  @override
  Future<Yard?> yard(String id) async {
    try {
      return Yard.fromJson(await _call('GET', '/yards/$id') as Map<String, dynamic>);
    } on RepoException {
      return null;
    }
  }

  @override
  Future<Map<String, int>> vehicleCounts() async =>
      ((await _call('GET', '/counts')) as Map).map((k, v) => MapEntry(k as String, (v as num).toInt()));

  // ---- account ----
  @override
  AppUser? get currentUser => _user;

  Future<void> _session(dynamic res) async {
    await _setToken(res['token'] as String);
    _user = _userFrom(res['user']);
    notifyListeners();
  }

  @override
  Future<void> signIn(String email, String password) async =>
      _session(await _call('POST', '/auth/login', json: {'email': email.trim(), 'password': password}));

  @override
  Future<bool> signUp(String email, String password) async {
    await _session(await _call('POST', '/auth/signup', json: {'email': email.trim(), 'password': password}));
    return false;
  }

  @override
  Future<void> signOut() async {
    try {
      await _call('POST', '/auth/logout');
    } catch (_) {}
    await _setToken(null);
    _user = null;
    notifyListeners();
  }

  // ---- gestione ----
  @override
  Future<Yard?> myYard() async {
    final y = ((await _call('GET', '/me/yard')) as Map)['yard'];
    return y == null ? null : Yard.fromJson(y as Map<String, dynamic>);
  }

  @override
  Future<Yard> createYard(Yard draft) async =>
      Yard.fromJson(await _call('POST', '/me/yard', json: draft.toJson()) as Map<String, dynamic>);

  @override
  Future<void> updateYard(Yard yard) async => _call('PUT', '/me/yard', json: yard.toJson());

  @override
  Future<List<Vehicle>> myVehicles() async => _vehicles(await _call('GET', '/me/vehicles'));

  @override
  Future<Vehicle> saveVehicle(Vehicle v) async =>
      Vehicle.fromJson(await _call('PUT', '/me/vehicles/${v.id}', json: v.toRow()) as Map<String, dynamic>);

  @override
  Future<void> deleteVehicle(Vehicle v) async => _call('DELETE', '/me/vehicles/${v.id}');

  @override
  Future<VehiclePhoto> addPhoto(Vehicle v, Uint8List jpeg, int position) async {
    final p = await _call('POST', '/me/vehicles/${v.id}/photos',
        bytes: jpeg, contentType: 'image/jpeg', query: {'position': '$position'}) as Map<String, dynamic>;
    return VehiclePhoto(id: p['id'] as String, url: p['url'] as String, position: (p['position'] as num).toInt());
  }

  @override
  Future<void> removePhoto(Vehicle v, VehiclePhoto photo) async => _call('DELETE', '/me/photos/${photo.id}');

  @override
  Future<void> reorderPhotos(Vehicle v, List<String> photoIds) async =>
      _call('PUT', '/me/vehicles/${v.id}/photos/order', json: {'order': photoIds});

  // ---- app Admin ----
  /// Chiamata diretta all'API (le rotte /admin/* servono solo all'app Admin). Accetta "/rotta?filtro=valore".
  Future<dynamic> request(String method, String route, {Object? json}) {
    final u = Uri.parse(route);
    return _call(method, u.path, json: json, query: u.queryParameters.isEmpty ? null : u.queryParameters);
  }

  Future<bool> isAdmin() async {
    final me = await _call('GET', '/auth/me') as Map<String, dynamic>;
    return (me['user'] as Map)['is_admin'] == true;
  }

  @override
  Future<int?> aiRemaining() async {
    try {
      final r = await _call('GET', '/me/ai') as Map<String, dynamic>;
      return r['enabled'] == true ? (r['remaining'] as num).toInt() : null;
    } on RepoException {
      return null; // server vecchio senza riconoscimento
    }
  }

  @override
  Future<AiResult> analyzePhotos({List<Uint8List> images = const [], List<String> photoIds = const [], String? vehicleId}) async =>
      AiResult.fromJson(await _call('POST', '/me/ai/analyze',
          json: {'images': images.map(base64Encode).toList(), 'photo_ids': photoIds, 'vehicle_id': ?vehicleId},
          timeout: const Duration(seconds: 100)) as Map<String, dynamic>);

  List<VehiclePart> _parts(dynamic r) =>
      ((r as Map)['parts'] as List).map((p) => VehiclePart.fromJson(p as Map<String, dynamic>)).toList();

  @override
  Future<List<VehiclePart>> parts(Vehicle v) async => _parts(await _call('GET', '/me/vehicles/${v.id}/parts'));

  @override
  Future<List<VehiclePart>> generateParts(Vehicle v) async =>
      _parts(await _call('POST', '/me/vehicles/${v.id}/parts/generate', timeout: const Duration(seconds: 120)));

  @override
  Future<List<VehiclePart>> updateParts(Vehicle v, List<VehiclePart> changed) async => _parts(await _call(
      'PUT', '/me/vehicles/${v.id}/parts', json: {'parts': [for (final p in changed) {'id': p.id, 'status': p.status.key}]}));

  @override
  void track(String kind, {String? vehicleId, String? yardId, String? partId}) {
    _call('POST', '/events', json: {'kind': kind, 'vehicle_id': ?vehicleId, 'yard_id': ?yardId, 'part_id': ?partId}).ignore();
  }

  @override
  Future<Map<String, dynamic>> myStats({int days = 30}) async =>
      await _call('GET', '/me/stats', query: {'days': '$days'}) as Map<String, dynamic>;

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }
}
