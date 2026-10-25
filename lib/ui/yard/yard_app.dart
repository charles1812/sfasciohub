import 'package:flutter/material.dart';

import '../../config.dart';
import '../../data/demo_repository.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/updater.dart';
import 'stats_tab.dart';
import 'vehicle_editor.dart';
import 'yard_profile.dart';

/// App per chi lavora nello sfasciacarrozze (Android, desktop, web).
class YardApp extends StatelessWidget {
  const YardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SfascioHub Gestione',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: ThemeMode.dark,
      builder: (_, child) => AppBackground(child: UpdateGate(child: child!)),
      home: ListenableBuilder(
        listenable: Repository.instance,
        builder: (_, _) => Repository.instance.currentUser == null ? const AuthPage() : const _YardGate(),
      ),
    );
  }
}

/// Utente loggato: se non ha ancora uno sfasciacarrozze, lo crea.
class _YardGate extends StatefulWidget {
  const _YardGate();
  @override
  State<_YardGate> createState() => _YardGateState();
}

class _YardGateState extends State<_YardGate> {
  late Future<Yard?> _yard = Repository.instance.myYard();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _yard,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        if (snap.hasError) {
          return Scaffold(body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('${snap.error}'),
            const SizedBox(height: 12),
            FilledButton(onPressed: () => setState(() => _yard = Repository.instance.myYard()), child: const Text('Riprova')),
            TextButton(onPressed: Repository.instance.signOut, child: const Text('Esci')),
          ])));
        }
        final y = snap.data;
        if (y == null) {
          return YardProfilePage(
            onboarding: true,
            onSaved: () => setState(() => _yard = Repository.instance.myYard()),
          );
        }
        return YardHome(yard: y, onYardChanged: () => setState(() => _yard = Repository.instance.myYard()));
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Accesso
// ---------------------------------------------------------------------------
class AuthPage extends StatefulWidget {
  const AuthPage({super.key});
  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _signUp = false;
  bool _busy = false;
  String? _info;

  Future<void> _submit() async {
    setState(() { _busy = true; _info = null; });
    try {
      final repo = Repository.instance;
      if (_signUp) {
        final confirm = await repo.signUp(_email.text, _password.text);
        if (confirm && mounted) setState(() => _info = 'Ti abbiamo mandato un\'email: apri il link per confermare, poi accedi.');
      } else {
        await repo.signIn(_email.text, _password.text);
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final local = Repository.instance.isDemo;
    final demo = local || AppConfig.demoLogin;
    return Scaffold(
      backgroundColor: Brand.asphalt,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: AutofillGroup(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      const Icon(Icons.car_repair, size: 44, color: Brand.orange),
                      const SizedBox(height: 8),
                      Text('SfascioHub Gestione', textAlign: TextAlign.center, style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                      Text('Il magazzino del tuo sfasciacarrozze, online', textAlign: TextAlign.center, style: t.bodyMedium),
                      const SizedBox(height: 20),
                      if (demo)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Brand.orangeSoft, borderRadius: BorderRadius.circular(12)),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                            Text(local ? 'Versione demo: i dati restano su questo dispositivo.' : "Vuoi solo provare? C'è un piazzale di prova condiviso.",
                                style: const TextStyle(color: Brand.gold, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 6),
                            TextButton.icon(
                              onPressed: () {
                                _email.text = demoEmail;
                                _password.text = demoPassword;
                                setState(() => _signUp = false);
                                _submit();
                              },
                              icon: const Icon(Icons.play_arrow),
                              label: const Text('Entra come sfasciacarrozze di prova'),
                            ),
                          ]),
                        ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline)),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _password,
                        obscureText: true,
                        autofillHints: [_signUp ? AutofillHints.newPassword : AutofillHints.password],
                        onSubmitted: (_) => _submit(),
                        decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock_outline)),
                      ),
                      if (_info != null) ...[
                        const SizedBox(height: 12),
                        Text(_info!, style: const TextStyle(color: Brand.ok)),
                      ],
                      const SizedBox(height: 18),
                      FilledButton(
                        onPressed: _busy ? null : _submit,
                        child: _busy
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Text(_signUp ? 'Crea account' : 'Accedi'),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => setState(() => _signUp = !_signUp),
                        child: Text(_signUp ? 'Hai già un account? Accedi' : 'Nuovo sfasciacarrozze? Iscriviti gratis'),
                      ),
                      const Divider(height: 24),
                      TextButton.icon(
                        onPressed: () => openUrl(AppConfig.site),
                        icon: const Icon(Icons.public, size: 18),
                        label: const Text('Vedi il sito pubblico'),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Home gestione
// ---------------------------------------------------------------------------
class YardHome extends StatefulWidget {
  const YardHome({super.key, required this.yard, required this.onYardChanged});
  final Yard yard;
  final VoidCallback onYardChanged;
  @override
  State<YardHome> createState() => _YardHomeState();
}

class _YardHomeState extends State<YardHome> {
  int _tab = 0;
  final _vehiclesKey = GlobalKey<_VehiclesTabState>();
  final _statsKey = GlobalKey<StatsTabState>();

  Future<void> _newVehicle() async {
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => VehicleEditor(yard: widget.yard),
      fullscreenDialog: true,
    ));
    if (saved == true) _vehiclesKey.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 840;
    final body = IndexedStack(index: _tab, children: [
      VehiclesTab(key: _vehiclesKey, yard: widget.yard),
      StatsTab(key: _statsKey),
      YardProfilePage(yard: widget.yard, onSaved: widget.onYardChanged),
    ]);
    const dests = [
      (Icons.directions_car_outlined, Icons.directions_car, 'Veicoli'),
      (Icons.insights_outlined, Icons.insights, 'Dati'),
      (Icons.storefront_outlined, Icons.storefront, 'Il mio piazzale'),
    ];
    void select(int i) {
      setState(() => _tab = i);
      if (i == 1) _statsKey.currentState?.reload();
    }
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: Brand.orange, borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.car_repair, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.yard.name, overflow: TextOverflow.ellipsis),
            const Text('SfascioHub Gestione', style: TextStyle(fontSize: 11.5, color: Colors.white60, fontWeight: FontWeight.w600)),
          ])),
        ]),
        actions: [
          IconButton(
            tooltip: 'Vedi sul sito pubblico',
            icon: const Icon(Icons.public),
            onPressed: () => openUrl('${AppConfig.site}#/sfasciacarrozze/${widget.yard.id}'),
          ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'out') Repository.instance.signOut();
            },
            itemBuilder: (_) => [
              PopupMenuItem(enabled: false, child: Text(Repository.instance.currentUser?.email ?? '')),
              const PopupMenuItem(value: 'out', child: ListTile(leading: Icon(Icons.logout), title: Text('Esci'))),
            ],
          ),
        ],
      ),
      body: Column(children: [
        if (Repository.instance.isDemo) const DemoBanner(text: 'Demo: le modifiche restano su questo dispositivo. Nel browser le vedi anche sul sito pubblico.'),
        Expanded(
          child: wide
              ? Row(children: [
                  NavigationRail(
                    selectedIndex: _tab,
                    onDestinationSelected: select,
                    labelType: NavigationRailLabelType.all,
                    leading: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: FloatingActionButton(onPressed: _newVehicle, tooltip: 'Nuovo veicolo', child: const Icon(Icons.add_a_photo)),
                    ),
                    destinations: [
                      for (final d in dests) NavigationRailDestination(icon: Icon(d.$1), selectedIcon: Icon(d.$2), label: Text(d.$3)),
                    ],
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(child: body),
                ])
              : body,
        ),
      ]),
      floatingActionButton: !wide && _tab == 0
          ? FloatingActionButton.extended(onPressed: _newVehicle, icon: const Icon(Icons.add_a_photo), label: const Text('Nuovo veicolo'))
          : null,
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: _tab,
              onDestinationSelected: select,
              destinations: [for (final d in dests) NavigationDestination(icon: Icon(d.$1), selectedIcon: Icon(d.$2), label: d.$3)],
            ),
    );
  }
}

class VehiclesTab extends StatefulWidget {
  const VehiclesTab({super.key, required this.yard});
  final Yard yard;
  @override
  State<VehiclesTab> createState() => _VehiclesTabState();
}

class _VehiclesTabState extends State<VehiclesTab> {
  List<Vehicle>? _vehicles;
  Object? _error;
  final _query = TextEditingController();
  VehicleStatus? _status;

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    try {
      final list = await Repository.instance.myVehicles();
      if (mounted) setState(() { _vehicles = list; _error = null; });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _open(Vehicle v) async {
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => VehicleEditor(yard: widget.yard, vehicle: v)));
    if (saved == true) reload();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) return Center(child: Text('$_error'));
    final all = _vehicles;
    if (all == null) return const Center(child: CircularProgressIndicator());
    final f = VehicleFilter(query: _query.text);
    final shown = all.where((v) => f.matches(v) && (_status == null || v.status == _status)).toList();
    final width = MediaQuery.sizeOf(context).width - (width840(context) ? 81 : 0);
    final cols = width >= 1200 ? 4 : width >= 860 ? 3 : width >= 560 ? 2 : 1;
    final count = {for (final s in VehicleStatus.values) s: all.where((v) => v.status == s).length};

    return RefreshIndicator(
      onRefresh: reload,
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 96), children: [
        Constrained(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (all.any((v) => v.photos.isEmpty))
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Glass(
                  blur: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(children: [
                    const Icon(Icons.no_photography_outlined, color: Brand.damage, size: 20),
                    const SizedBox(width: 10),
                    Expanded(child: Text('${all.where((v) => v.photos.isEmpty).length} auto senza foto: con le foto ricevono molte più visite.',
                        style: const TextStyle(fontWeight: FontWeight.w600))),
                  ]),
                ),
              ),
            TextField(
              controller: _query,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Cerca nel tuo piazzale'),
            ),
            const SizedBox(height: 10),
            Wrap(spacing: 8, children: [
              ChoiceChip(label: const Text('Tutti'), selected: _status == null, onSelected: (_) => setState(() => _status = null)),
              for (final s in VehicleStatus.values)
                ChoiceChip(label: Text('${s.label} (${count[s]})'), selected: _status == s, onSelected: (_) => setState(() => _status = s)),
            ]),
            const SizedBox(height: 14),
            if (all.isEmpty)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Text('Nessun veicolo ancora.\nTocca "Nuovo veicolo" e fotografa la prima auto del piazzale.', textAlign: TextAlign.center),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  mainAxisExtent: cardExtent(width, cols, showYard: false),
                ),
                itemCount: shown.length,
                itemBuilder: (_, i) => VehicleCard(
                  vehicle: shown[i],
                  showYard: false,
                  onTap: () => _open(shown[i]),
                  trailing: shown[i].published ? null : const Tooltip(message: 'Non pubblicato', child: Icon(Icons.visibility_off, size: 18)),
                ),
              ),
          ]),
        ),
      ]),
    );
  }

  bool width840(BuildContext c) => MediaQuery.sizeOf(c).width >= 840;
}
