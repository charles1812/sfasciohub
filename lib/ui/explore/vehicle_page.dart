import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/damage_map.dart';

class VehiclePage extends StatefulWidget {
  const VehiclePage({super.key, required this.id});
  final String id;
  @override
  State<VehiclePage> createState() => _VehiclePageState();
}

class _VehiclePageState extends State<VehiclePage> {
  late final Future<Vehicle?> _vehicle = Repository.instance.vehicle(widget.id).then((v) {
    if (v != null) Repository.instance.track('view', vehicleId: v.id);
    return v;
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _vehicle,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
        }
        final v = snap.data;
        if (v == null) {
          return Scaffold(appBar: AppBar(), body: const Center(child: Text('Questo veicolo non è più disponibile.')));
        }
        return VehicleDetails(vehicle: v);
      },
    );
  }
}

/// Scheda completa di un veicolo. Usata dal sito pubblico e come anteprima
/// nell'app di gestione.
class VehicleDetails extends StatelessWidget {
  const VehicleDetails({super.key, required this.vehicle, this.preview = false});
  final Vehicle vehicle;
  final bool preview;

  @override
  Widget build(BuildContext context) {
    final v = vehicle;
    final t = Theme.of(context).textTheme;
    final wide = MediaQuery.sizeOf(context).width >= 900;

    final gallery = ClipRRect(
      borderRadius: BorderRadius.circular(wide ? 16 : 0),
      child: AspectRatio(aspectRatio: 16 / 10, child: _Gallery(vehicle: v)),
    );

    final specs = Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          for (final (k, val) in [
            ('Anno', v.year?.toString() ?? '—'),
            ('Alimentazione', fuels[v.fuel] ?? '—'),
            ('Chilometri', v.km == null ? '—' : v.subtitle.split(' · ').firstWhere((s) => s.endsWith('km'), orElse: () => '—')),
            ('Colore', v.color.isEmpty ? '—' : v.color),
            ('Codice motore', v.engineCode.isEmpty ? '—' : v.engineCode),
            ('Nel piazzale dal', '${v.arrivedOn.day.toString().padLeft(2, '0')}/${v.arrivedOn.month.toString().padLeft(2, '0')}/${v.arrivedOn.year}'),
          ])
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(children: [
                Expanded(child: Text(k, style: t.bodyMedium?.copyWith(color: t.bodySmall?.color))),
                Text(val, style: const TextStyle(fontWeight: FontWeight.w700)),
              ]),
            ),
        ]),
      ),
    );

    final parts = v.parts.isNotEmpty ? _PartsList(vehicle: v, preview: preview) : Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Ricambi probabilmente recuperabili', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('Zone senza danni segnalati. Chiama per conferma prima di andare.', style: t.bodySmall),
          const SizedBox(height: 10),
          for (final z in v.intactZones)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.check_circle, color: Brand.ok, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text.rich(TextSpan(children: [
                  TextSpan(text: '${z.label}  ', style: const TextStyle(fontWeight: FontWeight.w700)),
                  TextSpan(text: z.parts, style: t.bodySmall),
                ]))),
              ]),
            ),
          if (v.damage.isNotEmpty) ...[
            const Divider(height: 24),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final z in v.damage)
                Chip(
                  label: Text(z.label),
                  avatar: const Icon(Icons.close, size: 16, color: Brand.damage),
                  backgroundColor: Brand.damageSoft,
                  visualDensity: VisualDensity.compact,
                ),
            ]),
          ],
        ]),
      ),
    );

    final damage = Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Mappa dei danni', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          DamageMap(damage: v.damage, height: 300),
        ]),
      ),
    );

    final yard = v.yard == null
        ? const SizedBox.shrink()
        : Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Dove si trova', style: t.labelLarge?.copyWith(color: Brand.orange)),
                const SizedBox(height: 4),
                InkWell(
                  onTap: preview ? null : () => Navigator.of(context).pushNamed('/sfasciacarrozze/${v.yard!.id}'),
                  child: Text(v.yard!.name, style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                ),
                Text([v.yard!.address, v.yard!.place].where((s) => s.isNotEmpty).join(', ')),
                if (v.yard!.hours.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.schedule, size: 18),
                    const SizedBox(width: 6),
                    Expanded(child: Text(v.yard!.hours, style: t.bodySmall)),
                  ]),
                ],
                const SizedBox(height: 14),
                ContactButtons(yard: v.yard!, vehicle: v),
              ]),
            ),
          );

    final header = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [StatusPill(v.status), const SizedBox(width: 8), if (!v.published) const Chip(label: Text('Non pubblicato'))]),
      const SizedBox(height: 8),
      Text(v.title, style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
      Text(v.subtitle, style: t.bodyLarge),
      if (v.notes.isNotEmpty) ...[
        const SizedBox(height: 12),
        Text(v.notes, style: t.bodyLarge?.copyWith(height: 1.45)),
      ],
    ]);

    return Scaffold(
      appBar: AppBar(
        title: Text(preview ? 'Anteprima pubblica' : v.title),
        actions: [
          if (!preview)
            IconButton(
              tooltip: 'Copia link',
              icon: const Icon(Icons.share),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: '${AppConfig.site}#/veicolo/${v.id}'));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link copiato')));
              },
            ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.symmetric(vertical: wide ? 20 : 0),
        children: [
          Constrained(
            child: wide
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        gallery, const SizedBox(height: 18), header, const SizedBox(height: 18), parts,
                      ])),
                      const SizedBox(width: 20),
                      Expanded(flex: 2, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        yard, const SizedBox(height: 16), damage, const SizedBox(height: 16), specs,
                      ])),
                    ]),
                  )
                : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    gallery,
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        header, const SizedBox(height: 16), yard, const SizedBox(height: 14), parts,
                        const SizedBox(height: 14), damage, const SizedBox(height: 14), specs, const SizedBox(height: 24),
                      ]),
                    ),
                  ]),
          ),
        ],
      ),
    );
  }
}

class _Gallery extends StatefulWidget {
  const _Gallery({required this.vehicle});
  final Vehicle vehicle;
  @override
  State<_Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<_Gallery> {
  final _page = PageController();
  int _i = 0;

  @override
  Widget build(BuildContext context) {
    final photos = widget.vehicle.photos;
    if (photos.isEmpty) {
      return Stack(fit: StackFit.expand, children: [
        Hero(tag: 'cover-${widget.vehicle.id}', child: VehicleCover(vehicle: widget.vehicle)),
        const Positioned(
          bottom: 10, right: 12,
          child: Text('Foto non ancora disponibili', style: TextStyle(color: Colors.black54, fontSize: 12)),
        ),
      ]);
    }
    return Stack(fit: StackFit.expand, children: [
      PageView.builder(
        controller: _page,
        itemCount: photos.length,
        onPageChanged: (i) => setState(() => _i = i),
        itemBuilder: (_, i) => GestureDetector(
          onTap: () => _openFull(context, i),
          child: i == 0 ? Hero(tag: 'cover-${widget.vehicle.id}', child: PhotoView(url: photos[i].url)) : PhotoView(url: photos[i].url),
        ),
      ),
      if (photos.length > 1) ...[
        Positioned(
          bottom: 10, left: 0, right: 0,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var k = 0; k < photos.length; k++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: k == _i ? 18 : 7, height: 7,
                decoration: BoxDecoration(color: k == _i ? Colors.white : Colors.white60, borderRadius: BorderRadius.circular(10)),
              ),
          ]),
        ),
        for (final (align, dir, icon) in [(Alignment.centerLeft, -1, Icons.chevron_left), (Alignment.centerRight, 1, Icons.chevron_right)])
          Align(
            alignment: align,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: IconButton.filledTonal(
                onPressed: () => _page.animateToPage((_i + dir).clamp(0, photos.length - 1),
                    duration: const Duration(milliseconds: 250), curve: Curves.easeOut),
                icon: Icon(icon),
              ),
            ),
          ),
      ],
    ]);
  }

  void _openFull(BuildContext context, int start) {
    Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(backgroundColor: Colors.black),
        body: PageView(
          controller: PageController(initialPage: start),
          children: [
            for (final p in widget.vehicle.photos)
              InteractiveViewer(child: Center(child: PhotoView(url: p.url, fit: BoxFit.contain))),
          ],
        ),
      ),
    ));
  }
}

/// Ricambi della lista del piazzale: prima i sani, poi quelli da verificare.
class _PartsList extends StatefulWidget {
  const _PartsList({required this.vehicle, this.preview = false});
  final Vehicle vehicle;
  final bool preview;
  List<VehiclePart> get parts => vehicle.parts;
  @override
  State<_PartsList> createState() => _PartsListState();
}

class _PartsListState extends State<_PartsList> {
  bool _all = false;

  /// Il cliente chiede un pezzo: si conta nelle statistiche del piazzale e si apre WhatsApp (o il telefono).
  void _ask(VehiclePart p) {
    final v = widget.vehicle;
    final y = v.yard!;
    Repository.instance.track('part', vehicleId: v.id, partId: p.id);
    final text = 'Buongiorno, ho visto su SfascioHub la ${v.title}${v.year == null ? '' : ' ${v.year}'}. '
        'Avete ancora: ${p.name}? Quanto costa?';
    final digits = y.whatsapp.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isNotEmpty) {
      openUrl('https://wa.me/$digits?text=${Uri.encodeComponent(text)}');
    } else if (y.phone.isNotEmpty) {
      openUrl('tel:${y.phone.replaceAll(' ', '')}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final ok = widget.parts.where((p) => p.status == PartStatus.ok).toList();
    final check = widget.parts.where((p) => p.status == PartStatus.check).toList();
    final shown = _all ? [...ok, ...check] : ok.take(12).toList();
    final byZone = <DamageZone?, List<VehiclePart>>{};
    for (final p in shown) {
      byZone.putIfAbsent(p.zone, () => []).add(p);
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Ricambi disponibili', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('${ok.length} probabilmente sani${check.isEmpty ? '' : ' · ${check.length} da verificare'}. Chiama per conferma prima di andare.',
              style: t.bodySmall),
          for (final MapEntry(key: zone, value: list) in byZone.entries) ...[
            const SizedBox(height: 12),
            Text(zone?.label ?? 'Altro', style: t.labelLarge?.copyWith(color: Brand.orange)),
            const SizedBox(height: 4),
            for (final p in list)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(p.status == PartStatus.ok ? Icons.check_circle : Icons.help_outline,
                      color: p.status == PartStatus.ok ? Brand.ok : Brand.orange, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(p.name)),
                  if (p.confirmed) Text('verificato', style: t.bodySmall?.copyWith(color: Brand.ok)),
                  if (!widget.preview && widget.vehicle.yard != null)
                    TextButton(
                      style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 10)),
                      onPressed: () => _ask(p),
                      child: const Text('Chiedi'),
                    ),
                ]),
              ),
          ],
          if (ok.length > 12 || check.isNotEmpty) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => setState(() => _all = !_all),
              child: Text(_all ? 'Mostra meno' : 'Mostra tutti (${ok.length + check.length})'),
            ),
          ],
        ]),
      ),
    );
  }
}
