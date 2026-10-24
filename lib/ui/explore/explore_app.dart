import 'package:flutter/material.dart';

import '../../config.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/updater.dart';
import 'vehicle_page.dart';
import 'yard_page.dart';

/// App pubblica (e sito web): cerca nei piazzali di tutti gli sfasciacarrozze.
class ExploreApp extends StatelessWidget {
  const ExploreApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SfascioHub · Ricambi usati dagli sfasciacarrozze',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      builder: (_, child) => UpdateGate(child: child!),
      onGenerateRoute: (settings) {
        final parts = Uri.parse(settings.name ?? '/').pathSegments;
        Widget page = const ExploreHome();
        if (parts.length == 2 && parts[0] == 'veicolo') page = VehiclePage(id: parts[1]);
        if (parts.length == 2 && parts[0] == 'sfasciacarrozze') page = YardPage(id: parts[1]);
        return MaterialPageRoute(builder: (_) => page, settings: settings);
      },
    );
  }
}

class ExploreHome extends StatefulWidget {
  const ExploreHome({super.key});
  @override
  State<ExploreHome> createState() => _ExploreHomeState();
}

class _ExploreHomeState extends State<ExploreHome> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final pages = [const SearchTab(), const YardsTab(), const AboutTab()];
    const dests = [
      (Icons.search, 'Cerca'),
      (Icons.warehouse_outlined, 'Sfasciacarrozze'),
      (Icons.info_outline, 'Info'),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Row(children: [
          Icon(Icons.car_repair, color: Brand.orange),
          SizedBox(width: 8),
          Text('SfascioHub'),
        ]),
        actions: [
          if (wide)
            for (var i = 0; i < dests.length; i++)
              TextButton.icon(
                onPressed: () => setState(() => _tab = i),
                icon: Icon(dests[i].$1, color: _tab == i ? Brand.orange : Colors.white70),
                label: Text(dests[i].$2, style: TextStyle(color: _tab == i ? Brand.orange : Colors.white)),
              ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(children: [
        if (Repository.instance.isDemo) const DemoBanner(text: 'Versione dimostrativa: sfasciacarrozze e veicoli sono di esempio.'),
        Expanded(child: IndexedStack(index: _tab, children: pages)),
      ]),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: _tab,
              onDestinationSelected: (i) => setState(() => _tab = i),
              destinations: [for (final d in dests) NavigationDestination(icon: Icon(d.$1), label: d.$2)],
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Ricerca veicoli
// ---------------------------------------------------------------------------
class SearchTab extends StatefulWidget {
  const SearchTab({super.key, this.yardId});
  final String? yardId;
  @override
  State<SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<SearchTab> {
  final _query = TextEditingController();
  String? _make;
  String? _province;
  RangeValues? _years;
  DamageZone? _need;
  List<Vehicle>? _all;
  List<Vehicle> _shown = [];
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final all = await Repository.instance.searchVehicles(VehicleFilter(yardId: widget.yardId));
      setState(() {
        _all = all;
        _error = null;
      });
      _apply();
    } catch (e) {
      setState(() => _error = e);
    }
  }

  void _apply() {
    final f = VehicleFilter(
      query: _query.text,
      make: _make,
      province: _province,
      yearFrom: _years?.start.round(),
      yearTo: _years?.end.round(),
      needIntact: _need,
    );
    setState(() => _shown = (_all ?? []).where(f.matches).toList());
  }

  void _reset() {
    _query.clear();
    _make = _province = _need = null;
    _years = null;
    _apply();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('$_error'),
        const SizedBox(height: 12),
        FilledButton(onPressed: _load, child: const Text('Riprova')),
      ]));
    }
    if (_all == null) return const Center(child: CircularProgressIndicator());

    final makes = {for (final v in _all!) v.make}.toList()..sort();
    final provinces = {for (final v in _all!) if (v.yard?.province.isNotEmpty ?? false) v.yard!.province}.toList()..sort();
    final years = _all!.map((v) => v.year).whereType<int>().toList();
    final minY = years.isEmpty ? 2000 : years.reduce((a, b) => a < b ? a : b);
    final maxY = years.isEmpty ? DateTime.now().year : years.reduce((a, b) => a > b ? a : b);
    final filtersOn = _make != null || _province != null || _years != null || _need != null || _query.text.isNotEmpty;

    final width = MediaQuery.sizeOf(context).width;
    final cols = width >= 1200 ? 4 : width >= 860 ? 3 : width >= 560 ? 2 : 1;

    final search = TextField(
      controller: _query,
      onChanged: (_) => _apply(),
      textInputAction: TextInputAction.search,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        hintText: 'Marca, modello, codice motore… (es. "panda 2016")',
        prefixIcon: const Icon(Icons.search, color: Brand.orange),
        suffixIcon: _query.text.isEmpty
            ? null
            : IconButton(icon: const Icon(Icons.close), onPressed: () { _query.clear(); _apply(); }),
      ),
    );
    final yards = {for (final v in _all!) v.yardId}.length;

    return RefreshIndicator(
      onRefresh: _load,
      child: CustomScrollView(slivers: [
        if (widget.yardId == null)
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                gradient: Brand.heroGradient,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
              ),
              child: Constrained(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, width >= 700 ? 36 : 22, 20, 24),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: Brand.orange.withValues(alpha: .18), borderRadius: BorderRadius.circular(100)),
                      child: Text('${_all!.length} auto in $yards ${yards == 1 ? 'piazzale' : 'piazzali'}',
                          style: const TextStyle(color: Color(0xFFFFB98C), fontWeight: FontWeight.w800, fontSize: 12.5)),
                    ),
                    const SizedBox(height: 12),
                    Text('Trova il ricambio\nnel piazzale giusto',
                        style: TextStyle(color: Colors.white, fontSize: width >= 700 ? 38 : 28, fontWeight: FontWeight.w900, height: 1.1, letterSpacing: -.5)),
                    const SizedBox(height: 8),
                    const Text('Le auto presenti oggi negli sfasciacarrozze, con i pezzi ancora sani da recuperare.',
                        style: TextStyle(color: Colors.white70, fontSize: 15, height: 1.4)),
                    const SizedBox(height: 18),
                    search,
                    const SizedBox(height: 14),
                    const Text('Mi serve…', style: TextStyle(color: Colors.white60, fontWeight: FontWeight.w700, fontSize: 12.5)),
                    const SizedBox(height: 6),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(children: [
                        for (final (z, icon) in [
                          (DamageZone.front, Icons.light_mode_outlined),
                          (DamageZone.rear, Icons.flip_to_back),
                          (DamageZone.left, Icons.sensor_door_outlined),
                          (DamageZone.right, Icons.sensor_door_outlined),
                          (DamageZone.engine, Icons.settings_outlined),
                          (DamageZone.interior, Icons.event_seat_outlined),
                          (DamageZone.glass, Icons.window_outlined),
                        ])
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Material(
                              color: _need == z ? Brand.orange : Colors.white.withValues(alpha: .09),
                              shape: StadiumBorder(side: BorderSide(color: _need == z ? Brand.orange : Colors.white24)),
                              child: InkWell(
                                customBorder: const StadiumBorder(),
                                onTap: () { _need = _need == z ? null : z; _apply(); },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                                    Icon(icon, size: 17, color: _need == z ? Colors.white : const Color(0xFFFFB98C)),
                                    const SizedBox(width: 6),
                                    Text(z.label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13.5)),
                                  ]),
                                ),
                              ),
                            ),
                          ),
                      ]),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        SliverToBoxAdapter(
          child: Constrained(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                if (widget.yardId != null) ...[search, const SizedBox(height: 10)],
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    _menuChip<String>('Marca', _make, makes, (v) => v, (v) { _make = v; _apply(); }),
                    if (widget.yardId == null) _menuChip<String>('Provincia', _province, provinces, (v) => v, (v) { _province = v; _apply(); }),
                    _menuChip<DamageZone>('Mi serve', _need, DamageZone.values, (z) => z.label, (v) { _need = v; _apply(); },
                        icon: Icons.build_outlined),
                    ActionChip(
                      avatar: const Icon(Icons.calendar_month, size: 18),
                      label: Text(_years == null ? 'Anno' : '${_years!.start.round()}–${_years!.end.round()}'),
                      backgroundColor: _years != null ? Brand.orangeSoft : null,
                      onPressed: minY >= maxY ? null : () => _pickYears(minY, maxY),
                    ),
                    if (filtersOn) ...[
                      const SizedBox(width: 6),
                      TextButton.icon(onPressed: _reset, icon: const Icon(Icons.filter_alt_off, size: 18), label: const Text('Azzera')),
                    ],
                  ]),
                ),
                const SizedBox(height: 8),
                Text(
                  '${_shown.length} ${_shown.length == 1 ? 'veicolo' : 'veicoli'}'
                  '${_need == null ? '' : ' con ${_need!.label.toLowerCase()} integro · ${_need!.parts}'}',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
              ]),
            ),
          ),
        ),
        if (_shown.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: Padding(
              padding: EdgeInsets.all(32),
              child: Text('Nessun veicolo trovato con questi filtri.', textAlign: TextAlign.center),
            )),
          )
        else
          SliverToBoxAdapter(
            child: Constrained(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cols,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    mainAxisExtent: cardExtent(width, cols, showYard: widget.yardId == null),
                  ),
                  itemCount: _shown.length,
                  itemBuilder: (_, i) => VehicleCard(
                    vehicle: _shown[i],
                    showYard: widget.yardId == null,
                    onTap: () => Navigator.of(context).pushNamed('/veicolo/${_shown[i].id}').then((_) => _load()),
                  ),
                ),
              ),
            ),
          ),
      ]),
    );
  }

  Widget _menuChip<T>(String label, T? value, List<T> options, String Function(T) name, ValueChanged<T?> onPick, {IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: PopupMenuButton<T?>(
        tooltip: label,
        onSelected: (v) => onPick(v),
        itemBuilder: (_) => [
          PopupMenuItem<T?>(value: null, child: Text('Tutte / qualsiasi')),
          for (final o in options) PopupMenuItem<T?>(value: o, child: Text(name(o))),
        ],
        child: Chip(
          avatar: Icon(icon ?? Icons.arrow_drop_down, size: 18),
          label: Text(value == null ? label : '$label: ${name(value)}'),
          backgroundColor: value != null ? Brand.orangeSoft : null,
        ),
      ),
    );
  }

  Future<void> _pickYears(int minY, int maxY) async {
    var range = _years ?? RangeValues(minY.toDouble(), maxY.toDouble());
    final picked = await showModalBottomSheet<RangeValues?>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, set) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Anno: ${range.start.round()} – ${range.end.round()}', style: Theme.of(ctx).textTheme.titleMedium),
            RangeSlider(
              values: range,
              min: minY.toDouble(),
              max: maxY.toDouble(),
              divisions: maxY - minY,
              labels: RangeLabels('${range.start.round()}', '${range.end.round()}'),
              onChanged: (v) => set(() => range = v),
            ),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(onPressed: () => Navigator.pop(ctx, const RangeValues(-1, -1)), child: const Text('Qualsiasi')),
              const SizedBox(width: 8),
              FilledButton(onPressed: () => Navigator.pop(ctx, range), child: const Text('Applica')),
            ]),
          ]),
        );
      }),
    );
    if (picked == null) return;
    _years = picked.start < 0 ? null : picked;
    _apply();
  }
}

// ---------------------------------------------------------------------------
// Elenco sfasciacarrozze
// ---------------------------------------------------------------------------
class YardsTab extends StatefulWidget {
  const YardsTab({super.key});
  @override
  State<YardsTab> createState() => _YardsTabState();
}

class _YardsTabState extends State<YardsTab> {
  late Future<(List<Yard>, Map<String, int>)> _data = _fetch();

  Future<(List<Yard>, Map<String, int>)> _fetch() async =>
      (await Repository.instance.yards(), await Repository.instance.vehicleCounts());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _data,
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text('${snap.error}'));
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final (yards, counts) = snap.data!;
        return RefreshIndicator(
          onRefresh: () async => setState(() => _data = _fetch()),
          child: ListView(padding: const EdgeInsets.all(16), children: [
            Constrained(
              maxWidth: 800,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('${yards.length} sfasciacarrozze sulla piattaforma',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                for (final y in yards) ...[
                  Card(
                    child: InkWell(
                      onTap: () => Navigator.of(context).pushNamed('/sfasciacarrozze/${y.id}'),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(children: [
                          Container(
                            width: 54,
                            height: 54,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(gradient: Brand.heroGradient, borderRadius: BorderRadius.circular(16)),
                            child: Text(y.name.characters.first.toUpperCase(),
                                style: const TextStyle(color: Brand.orange, fontWeight: FontWeight.w900, fontSize: 22)),
                          ),
                          const SizedBox(width: 14),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(y.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                            const SizedBox(height: 2),
                            Row(children: [
                              const Icon(Icons.place_outlined, size: 15, color: Brand.orange),
                              const SizedBox(width: 3),
                              Expanded(child: Text(y.place, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall)),
                            ]),
                          ])),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(color: Brand.okSoft, borderRadius: BorderRadius.circular(100)),
                            child: Text('${counts[y.id] ?? 0} auto', style: const TextStyle(color: Brand.ok, fontWeight: FontWeight.w800)),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.chevron_right),
                        ]),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ]),
            ),
          ]),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Info
// ---------------------------------------------------------------------------
class AboutTab extends StatelessWidget {
  const AboutTab({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    Widget step(IconData i, String title, String body) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CircleAvatar(backgroundColor: Brand.orangeSoft, foregroundColor: Brand.orange, child: Icon(i)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              Text(body),
            ])),
          ]),
        );
    return ListView(padding: const EdgeInsets.all(20), children: [
      Constrained(
        maxWidth: 760,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Come funziona', style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 16),
          step(Icons.photo_camera_outlined, 'Lo sfasciacarrozze fotografa l\'auto',
              'Appena un veicolo entra nel piazzale, dall\'app Gestione si scattano le foto e si segnano anno, modello e zone danneggiate.'),
          step(Icons.public, 'Il veicolo compare qui',
              'Subito visibile a tutti, con la mappa delle zone integre: frontale, fiancate, motore, interni…'),
          step(Icons.call_outlined, 'Chiami e vai a prendere il pezzo',
              'Contatti lo sfasciacarrozze per telefono o WhatsApp e ti fai preparare il ricambio.'),
          const Divider(height: 36),
          Text('Hai uno sfasciacarrozze?', style: t.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          const Text('Iscriviti gratis e metti online il tuo piazzale: app Android, programma per computer o direttamente dal browser.'),
          const SizedBox(height: 14),
          Wrap(spacing: 10, runSpacing: 10, children: [
            FilledButton.icon(
              onPressed: () => openUrl('${AppConfig.site}gestione/'),
              icon: const Icon(Icons.dashboard_customize_outlined),
              label: const Text('Apri la gestione web'),
            ),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16)),
              onPressed: () => openUrl('https://github.com/charles1812/sfasciohub/releases/latest'),
              icon: const Icon(Icons.android),
              label: const Text('Scarica le app'),
            ),
          ]),
          const SizedBox(height: 30),
          Text('SfascioHub · un progetto di @charles1812', style: t.bodySmall),
        ]),
      ),
    ]);
  }
}
