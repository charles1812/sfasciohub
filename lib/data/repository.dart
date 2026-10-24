import 'package:flutter/foundation.dart';

import '../config.dart';
import 'demo_repository.dart';
import 'models.dart';
import 'supabase_repository.dart';

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

/// Tutto ciò che l'app sa fare con i dati. Due implementazioni: Supabase
/// (piattaforma vera, condivisa) e demo (dati di esempio sul dispositivo).
abstract class Repository extends ChangeNotifier {
  static late final Repository instance;

  static Future<void> init() async {
    instance = AppConfig.hasSupabase ? await SupabaseRepository.create() : await DemoRepository.create();
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
}
