import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../config.dart';
import 'models.dart';
import 'repository.dart';

const _bucket = 'vehicle-photos';
const _vehicleSelect = '*, vehicle_photos(id, path, position), yards(*)';

class SupabaseRepository extends Repository {
  SupabaseRepository._(this._db) {
    _db.auth.onAuthStateChange.listen((_) => notifyListeners());
  }

  final SupabaseClient _db;

  static Future<SupabaseRepository> create() async {
    await Supabase.initialize(url: AppConfig.supabaseUrl, publishableKey: AppConfig.supabaseAnonKey);
    return SupabaseRepository._(Supabase.instance.client);
  }

  @override
  bool get isDemo => false;

  String _photoUrl(String path) => _db.storage.from(_bucket).getPublicUrl(path);
  Vehicle _vehicle(Map<String, dynamic> j) => Vehicle.fromJson(j, photoUrl: _photoUrl);

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on AuthException catch (e) {
      throw RepoException(_authMessage(e));
    } on PostgrestException catch (e) {
      throw RepoException('Errore del database: ${e.message}');
    } on StorageException catch (e) {
      throw RepoException('Errore nel caricamento della foto: ${e.message}');
    }
  }

  // ---- pubblico ----
  @override
  Future<List<Vehicle>> searchVehicles(VehicleFilter f) => _guard(() async {
        var q = _db.from('vehicles').select(_vehicleSelect).eq('published', true).neq('status', 'gone');
        if (f.make != null) q = q.eq('make', f.make!);
        if (f.yearFrom != null) q = q.gte('year', f.yearFrom!);
        if (f.yearTo != null) q = q.lte('year', f.yearTo!);
        if (f.yardId != null) q = q.eq('yard_id', f.yardId!);
        final rows = await q.order('created_at', ascending: false).limit(500);
        // testo libero, provincia e zone si filtrano qui: dataset piccolo per piazzale
        return rows.map(_vehicle).where(f.matches).toList();
      });

  @override
  Future<Vehicle?> vehicle(String id) => _guard(() async {
        final row = await _db.from('vehicles').select(_vehicleSelect).eq('id', id).maybeSingle();
        return row == null ? null : _vehicle(row);
      });

  @override
  Future<List<Yard>> yards() => _guard(() async {
        final rows = await _db.from('yards').select().eq('published', true).order('name');
        return rows.map(Yard.fromJson).toList();
      });

  @override
  Future<Yard?> yard(String id) => _guard(() async {
        final row = await _db.from('yards').select().eq('id', id).maybeSingle();
        return row == null ? null : Yard.fromJson(row);
      });

  @override
  Future<Map<String, int>> vehicleCounts() => _guard(() async {
        final rows = await _db.from('vehicles').select('yard_id').eq('published', true).neq('status', 'gone');
        final counts = <String, int>{};
        for (final r in rows) {
          final id = r['yard_id'] as String;
          counts[id] = (counts[id] ?? 0) + 1;
        }
        return counts;
      });

  // ---- account ----
  @override
  AppUser? get currentUser {
    final u = _db.auth.currentUser;
    return u == null ? null : AppUser(id: u.id, email: u.email ?? '');
  }

  @override
  Future<void> signIn(String email, String password) =>
      _guard(() => _db.auth.signInWithPassword(email: email.trim(), password: password));

  @override
  Future<bool> signUp(String email, String password) => _guard(() async {
        final res = await _db.auth.signUp(email: email.trim(), password: password);
        return res.session == null;
      });

  @override
  Future<void> signOut() => _guard(() => _db.auth.signOut());

  // ---- gestione ----
  @override
  Future<Yard?> myYard() => _guard(() async {
        final uid = _db.auth.currentUser?.id;
        if (uid == null) return null;
        final m = await _db.from('yard_members').select('yards(*)').eq('user_id', uid).limit(1).maybeSingle();
        final y = m?['yards'];
        return y is Map<String, dynamic> ? Yard.fromJson(y) : null;
      });

  @override
  Future<Yard> createYard(Yard draft) => _guard(() async {
        final row = draft.toJson()
          ..remove('id')
          ..['owner_id'] = _db.auth.currentUser!.id;
        final saved = await _db.from('yards').insert(row).select().single();
        return Yard.fromJson(saved);
      });

  @override
  Future<void> updateYard(Yard yard) => _guard(() async {
        final row = yard.toJson()..remove('owner_id');
        await _db.from('yards').update(row).eq('id', yard.id);
      });

  @override
  Future<List<Vehicle>> myVehicles() => _guard(() async {
        final y = await myYard();
        if (y == null) return [];
        final rows = await _db.from('vehicles').select(_vehicleSelect).eq('yard_id', y.id).order('created_at', ascending: false);
        return rows.map(_vehicle).toList();
      });

  @override
  Future<Vehicle> saveVehicle(Vehicle v) => _guard(() async {
        final saved = await _db.from('vehicles').upsert(v.toRow()).select(_vehicleSelect).single();
        return _vehicle(saved);
      });

  @override
  Future<void> deleteVehicle(Vehicle v) => _guard(() async {
        final paths = await _db.from('vehicle_photos').select('path').eq('vehicle_id', v.id);
        if (paths.isNotEmpty) {
          await _db.storage.from(_bucket).remove(paths.map((p) => p['path'] as String).toList());
        }
        await _db.from('vehicles').delete().eq('id', v.id);
      });

  @override
  Future<VehiclePhoto> addPhoto(Vehicle v, Uint8List jpeg, int position) => _guard(() async {
        final path = '${v.yardId}/${v.id}/${DateTime.now().millisecondsSinceEpoch}.jpg';
        await _db.storage.from(_bucket).uploadBinary(path, jpeg,
            fileOptions: const FileOptions(contentType: 'image/jpeg', cacheControl: '31536000'));
        final row = await _db
            .from('vehicle_photos')
            .insert({'vehicle_id': v.id, 'path': path, 'position': position})
            .select()
            .single();
        return VehiclePhoto(id: row['id'] as String, url: _photoUrl(path), position: position);
      });

  @override
  Future<void> removePhoto(Vehicle v, VehiclePhoto photo) => _guard(() async {
        final row = await _db.from('vehicle_photos').delete().eq('id', photo.id).select('path').maybeSingle();
        final path = row?['path'] as String?;
        if (path != null) await _db.storage.from(_bucket).remove([path]);
      });
}

String _authMessage(AuthException e) {
  final m = e.message.toLowerCase();
  if (m.contains('invalid login')) return 'Email o password non corretti.';
  if (m.contains('already registered')) return 'Esiste già un account con questa email.';
  if (m.contains('email not confirmed')) return 'Conferma prima l\'email: ti abbiamo mandato un link.';
  if (m.contains('password')) return 'La password deve avere almeno 6 caratteri.';
  return e.message;
}
