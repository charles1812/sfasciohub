import 'package:flutter/foundation.dart';

import '../config.dart';
import 'demo_repository.dart';
import 'models.dart';
import 'php_repository.dart';

class AppUser {
  const AppUser({required this.id, required this.email});
  final String id;
  final String email;
}

class RepoException implements Exception {
  RepoException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Cosa ha riconosciuto l'AI nelle foto. Campi vuoti = non riconosciuto.
class AiResult {
  AiResult.fromJson(Map<String, dynamic> j)
      : make = j['make'] as String? ?? '',
        model = j['model'] as String? ?? '',
        version = j['version'] as String? ?? '',
        year = (j['year'] as num?)?.toInt(),
        yearRange = j['year_range'] as String? ?? '',
        fuel = j['fuel'] as String? ?? '',
        color = j['color'] as String? ?? '',
        damage = ((j['damage'] as List?) ?? []).map((k) => DamageZone.fromKey(k as String)).whereType<DamageZone>().toSet(),
        notes = j['notes'] as String? ?? '',
        confidence = j['confidence'] as String? ?? 'bassa',
        remaining = (j['remaining'] as num?)?.toInt();
  final String make, model, version, yearRange, fuel, color, notes, confidence;
  final int? year;
  final Set<DamageZone> damage;

  /// Analisi ancora disponibili oggi per questo sfasciacarrozze.
  final int? remaining;
}

/// Tutto ciò che l'app sa fare con i dati. Due implementazioni: l'API PHP sul
/// server (piattaforma vera, condivisa) e demo (dati di esempio sul dispositivo).
abstract class Repository extends ChangeNotifier {
  static late final Repository instance;

  static Future<void> init() async {
    instance = AppConfig.hasServer ? await PhpRepository.create() : await DemoRepository.create();
  }

  bool get isDemo;

  // ---- pubblico ----
  Future<List<Vehicle>> searchVehicles(VehicleFilter filter);
  Future<Vehicle?> vehicle(String id);
  Future<List<Yard>> yards();
  Future<Yard?> yard(String id);

  /// Numero di veicoli visibili per ogni sfasciacarrozze.
  Future<Map<String, int>> vehicleCounts();

  // ---- account ----
  AppUser? get currentUser;
  Future<void> signIn(String email, String password);

  /// Ritorna true se serve confermare l'email prima di entrare.
  Future<bool> signUp(String email, String password);
  Future<void> signOut();

  // ---- gestione (utente loggato) ----
  Future<Yard?> myYard();
  Future<Yard> createYard(Yard draft);
  Future<void> updateYard(Yard yard);
  Future<List<Vehicle>> myVehicles();
  Future<Vehicle> saveVehicle(Vehicle v);
  Future<void> deleteVehicle(Vehicle v);
  Future<VehiclePhoto> addPhoto(Vehicle v, Uint8List jpeg, int position);
  Future<void> removePhoto(Vehicle v, VehiclePhoto photo);

  /// Nuovo ordine delle foto già salvate (la prima è la copertina).
  Future<void> reorderPhotos(Vehicle v, List<String> photoIds);

  // ---- riconoscimento dalle foto ----
  /// Analisi rimaste oggi, o null se il server non ha il riconoscimento attivo.
  Future<int?> aiRemaining();

  /// Manda le foto (nuove e/o già salvate) all'AI e ritorna i dati riconosciuti.
  Future<AiResult> analyzePhotos({List<Uint8List> images = const [], List<String> photoIds = const []});

  // ---- lista ricambi ----
  Future<List<VehiclePart>> parts(Vehicle v);

  /// L'AI propone la lista (i pezzi già confermati restano come sono).
  Future<List<VehiclePart>> generateParts(Vehicle v);

  /// Il piazzale conferma o corregge alcuni pezzi.
  Future<List<VehiclePart>> updateParts(Vehicle v, List<VehiclePart> changed);
}
