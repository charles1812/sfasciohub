import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:ota_update/ota_update.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../theme.dart';

/// Descrizione dell'ultima versione, pubblicata come asset di ogni release GitHub.
const _manifestUrl = 'https://github.com/charles1812/sfasciohub/releases/latest/download/version.json';

/// Aggiornamento delle app Android senza passare dal Play Store: legge
/// version.json dall'ultima release, scarica l'APK e apre l'installazione.
class Updater extends ChangeNotifier {
  Updater._();
  static final instance = Updater._();

  /// Solo le app Android installate da APK si aggiornano così (il web si aggiorna da solo).
  static bool get supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  String? newVersion;
  String notes = '';
  String? _apkUrl;

  /// null = non sta scaricando; 0–100 = percentuale.
  int? progress;
  String? error;
  bool _dismissed = false;

  bool get showBar => newVersion != null && !_dismissed;

  /// Ritorna true se c'è una versione più nuova di quella installata.
  Future<bool> check() async {
    if (!supported) return false;
    try {
      final info = await PackageInfo.fromPlatform();
      final res = await http.get(Uri.parse(_manifestUrl)).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return false;
      final m = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final url = (m['apks'] as Map?)?[info.packageName] as String?;
      final build = (m['build'] as num?)?.toInt() ?? 0;
      if (url == null || build <= (int.tryParse(info.buildNumber) ?? 0)) return false;
      newVersion = m['version'] as String? ?? '$build';
      notes = m['notes'] as String? ?? '';
      _apkUrl = url;
      _dismissed = false;
      notifyListeners();
      return true;
    } catch (_) {
      return false; // offline o GitHub non raggiungibile: si riprova al prossimo avvio
    }
  }

  void dismiss() {
    _dismissed = true;
    notifyListeners();
  }

  void install() {
    final url = _apkUrl;
    if (url == null || progress != null) return;
    progress = 0;
    error = null;
    notifyListeners();
    try {
      OtaUpdate().execute(url, destinationFilename: 'sfasciohub-update.apk').listen(
        (e) {
          switch (e.status) {
            case OtaStatus.DOWNLOADING:
              progress = int.tryParse(e.value ?? '') ?? progress;
            case OtaStatus.INSTALLING:
            case OtaStatus.INSTALLATION_DONE:
              progress = null;
            case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
              progress = null;
              error = 'Consenti a SfascioHub di installare app (Impostazioni → App → SfascioHub → Installa app sconosciute) e riprova.';
            case OtaStatus.CANCELED:
              progress = null;
            default:
              progress = null;
              error = 'Aggiornamento non riuscito (${e.value ?? e.status.name}). Riprova.';
          }
          notifyListeners();
        },
        onError: (Object e) {
          progress = null;
          error = 'Aggiornamento non riuscito: $e';
          notifyListeners();
        },
      );
    } catch (e) {
      progress = null;
      error = 'Aggiornamento non riuscito: $e';
      notifyListeners();
    }
  }
}

/// Avvolge l'app: controlla gli aggiornamenti all'avvio e mostra la barra "Aggiorna".
class UpdateGate extends StatefulWidget {
  const UpdateGate({super.key, required this.child});
  final Widget child;
  @override
  State<UpdateGate> createState() => _UpdateGateState();
}

class _UpdateGateState extends State<UpdateGate> {
  @override
  void initState() {
    super.initState();
    Updater.instance.check();
  }

  @override
  Widget build(BuildContext context) {
    final u = Updater.instance;
    return ListenableBuilder(
      listenable: u,
      builder: (context, _) => Column(children: [
        Expanded(child: widget.child),
        if (u.showBar) _UpdateBar(u),
      ]),
    );
  }
}

class _UpdateBar extends StatelessWidget {
  const _UpdateBar(this.u);
  final Updater u;

  @override
  Widget build(BuildContext context) {
    final downloading = u.progress != null;
    return Material(
      color: Brand.asphalt,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              const Icon(Icons.system_update, color: Brand.orange),
              const SizedBox(width: 12),
              Expanded(child: Text(
                downloading
                    ? 'Scarico la versione ${u.newVersion}… ${u.progress}%'
                    : 'Nuova versione ${u.newVersion} disponibile${u.notes.isEmpty ? '' : ': ${u.notes}'}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              )),
              if (!downloading) ...[
                TextButton(onPressed: u.dismiss, child: const Text('Dopo', style: TextStyle(color: Colors.white70))),
                FilledButton(onPressed: u.install, child: const Text('Aggiorna')),
              ],
            ]),
            if (downloading) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(value: (u.progress ?? 0) / 100, color: Brand.orange, backgroundColor: Colors.white24),
            ],
            if (u.error != null) ...[
              const SizedBox(height: 6),
              Text(u.error!, style: const TextStyle(color: Color(0xFFFFB4A8), fontSize: 12)),
            ],
          ]),
        ),
      ),
    );
  }
}
