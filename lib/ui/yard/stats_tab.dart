import 'package:flutter/material.dart';

import '../../data/repository.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Dati del piazzale: quante persone guardano le auto, chi contatta, quali ricambi vengono chiesti.
class StatsTab extends StatefulWidget {
  const StatsTab({super.key});
  @override
  State<StatsTab> createState() => StatsTabState();
}

class StatsTabState extends State<StatsTab> {
  int _days = 30;
  Map<String, dynamic>? _data;
  Object? _error;

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    try {
      final d = await Repository.instance.myStats(days: _days);
      if (mounted) setState(() { _data = d; _error = null; });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(padding: const EdgeInsets.all(16), child: Text('$_error', textAlign: TextAlign.center)),
        FilledButton(onPressed: reload, child: const Text('Riprova')),
      ]));
    }
    final d = _data;
    if (d == null) return const Center(child: CircularProgressIndicator());
    final t = Theme.of(context).textTheme;
    final tot = (d['totals'] as Map).cast<String, dynamic>();
    final prev = (d['previous'] as Map).cast<String, dynamic>();
    final series = (d['series'] as List).cast<Map>();
    final vehicles = (d['vehicles'] as List).cast<Map>();
    final parts = (d['parts'] as List).cast<Map>();
    int n(Map m, String k) => (m[k] as num?)?.toInt() ?? 0;
    final empty = n(tot, 'view') + n(tot, 'contacts') + n(tot, 'part') + n(tot, 'yard_view') == 0;
    final wide = MediaQuery.sizeOf(context).width >= 900;

    final header = Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('I tuoi dati', style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
        Text('Visite e richieste dei clienti dal sito e dall\'app SfascioHub', style: t.bodyMedium),
      ])),
    ]);

    final period = SegmentedButton<int>(
      segments: const [
        ButtonSegment(value: 7, label: Text('7 giorni')),
        ButtonSegment(value: 30, label: Text('30 giorni')),
        ButtonSegment(value: 90, label: Text('90 giorni')),
      ],
      selected: {_days},
      showSelectedIcon: false,
      onSelectionChanged: (s) {
        setState(() { _days = s.first; _data = null; });
        reload();
      },
    );

    final kpis = GridView.count(
      crossAxisCount: wide ? 4 : 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: wide ? 1.9 : 1.45,
      children: [
        StatTile(icon: Icons.visibility_outlined, color: Brand.orange, value: '${n(tot, 'view')}', label: 'visite alle auto',
            delta: _delta(n(tot, 'view'), n(prev, 'view'))),
        StatTile(icon: Icons.people_alt_outlined, color: const Color(0xFF3B7DD8), value: '${n(tot, 'visitors')}', label: 'persone diverse',
            delta: _delta(n(tot, 'visitors'), n(prev, 'visitors'))),
        StatTile(icon: Icons.call_outlined, color: Brand.ok, value: '${n(tot, 'contacts')}', label: 'contatti',
            delta: _delta(n(tot, 'contacts'), n(prev, 'contacts'))),
        StatTile(icon: Icons.inventory_2_outlined, color: const Color(0xFF8E5BD9), value: '${n(tot, 'part')}', label: 'ricambi richiesti',
            delta: _delta(n(tot, 'part'), n(prev, 'part'))),
      ],
    );

    final contacts = Wrap(spacing: 8, runSpacing: 8, children: [
      for (final (icon, label, k) in [
        (Icons.call, 'Chiamate', 'call'),
        (Icons.chat, 'WhatsApp', 'whatsapp'),
        (Icons.directions, 'Indicazioni', 'maps'),
        (Icons.storefront, 'Visite al piazzale', 'yard_view'),
      ])
        Chip(avatar: Icon(icon, size: 18), label: Text('$label  ${n(tot, k)}', style: const TextStyle(fontWeight: FontWeight.w700))),
    ]);

    final chart = _Section(
      title: 'Giorno per giorno',
      subtitle: 'Visite (barre) e contatti (punti verdi)',
      child: SizedBox(height: 180, child: _DailyChart(series: series)),
    );

    final maxViews = vehicles.fold<int>(1, (m, v) => n(v, 'views') > m ? n(v, 'views') : m);
    final topVehicles = _Section(
      title: 'Auto più viste',
      child: vehicles.isEmpty
          ? const _Empty('Ancora nessuna visita alle tue auto in questo periodo.')
          : Column(children: [
              for (final (i, v) in vehicles.take(10).indexed)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(children: [
                    _Rank(i + 1),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${v['title']}${v['year'] == null ? '' : ' · ${v['year']}'}',
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 5),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: n(v, 'views') / maxViews,
                          minHeight: 8,
                          color: Brand.orange,
                          backgroundColor: Brand.orangeSoft.withValues(alpha: .6),
                        ),
                      ),
                    ])),
                    const SizedBox(width: 14),
                    _Count(n(v, 'views'), 'visite'),
                    const SizedBox(width: 10),
                    _Count(n(v, 'contacts') + n(v, 'parts'), 'richieste', color: Brand.ok),
                  ]),
                ),
            ]),
    );

    final topParts = _Section(
      title: 'Ricambi più richiesti',
      subtitle: 'Quando un cliente tocca "Chiedi" su un pezzo della scheda',
      child: parts.isEmpty
          ? const _Empty('Nessun ricambio richiesto in questo periodo. Le auto con la lista ricambi ricevono più richieste.')
          : Column(children: [
              for (final (i, p) in parts.take(10).indexed)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: _Rank(i + 1, color: const Color(0xFF8E5BD9)),
                  title: Text(p['name'] as String, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(n(p, 'vehicles') > 1 ? 'su ${n(p, 'vehicles')} auto' : (p['example_vehicle'] as String? ?? '')),
                  trailing: _Count(n(p, 'requests'), n(p, 'requests') == 1 ? 'richiesta' : 'richieste', color: const Color(0xFF8E5BD9)),
                ),
            ]),
    );

    return RefreshIndicator(
      onRefresh: reload,
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 18, 16, 40), children: [
        Constrained(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            header,
            const SizedBox(height: 14),
            Align(alignment: Alignment.centerLeft, child: period),
            const SizedBox(height: 16),
            if (d['demo'] == true)
              const _Empty('Nella versione demo offline non ci sono visite: i dati veri arrivano con il server.')
            else ...[
              if (empty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Card(
                    color: Brand.orangeSoft.withValues(alpha: .55),
                    child: const ListTile(
                      leading: Icon(Icons.tips_and_updates_outlined, color: Brand.orange),
                      title: Text('Qui vedrai chi guarda le tue auto', style: TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text('Ogni volta che un cliente apre una tua auto, ti chiama, ti scrive su WhatsApp o chiede un pezzo, '
                          'lo trovi contato qui. Condividi il link del piazzale per farti trovare.'),
                    ),
                  ),
                ),
              kpis,
              const SizedBox(height: 12),
              contacts,
              const SizedBox(height: 16),
              chart,
              const SizedBox(height: 16),
              if (wide)
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: topVehicles),
                  const SizedBox(width: 16),
                  Expanded(child: topParts),
                ])
              else ...[
                topVehicles,
                const SizedBox(height: 16),
                topParts,
              ],
            ],
          ]),
        ),
      ]),
    );
  }

  /// Variazione rispetto al periodo precedente; null se prima non c'era niente da confrontare.
  double? _delta(int now, int before) => before == 0 ? null : (now - before) / before;
}

class _Section extends StatelessWidget {
  const _Section({required this.title, this.subtitle, required this.child});
  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(title, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
          if (subtitle != null) Text(subtitle!, style: t.bodySmall),
          const SizedBox(height: 14),
          child,
        ]),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Row(children: [
          Icon(Icons.hourglass_empty, color: Theme.of(context).colorScheme.outline),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium)),
        ]),
      );
}

class _Rank extends StatelessWidget {
  const _Rank(this.n, {this.color = Brand.orange});
  final int n;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: color.withValues(alpha: .13), borderRadius: BorderRadius.circular(9)),
        child: Text('$n', style: TextStyle(color: color, fontWeight: FontWeight.w900)),
      );
}

class _Count extends StatelessWidget {
  const _Count(this.n, this.label, {this.color = Brand.orange});
  final int n;
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
        Text('$n', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: color)),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ]);
}

/// Barre delle visite al giorno, con un punto per i giorni con contatti.
class _DailyChart extends StatelessWidget {
  const _DailyChart({required this.series});
  final List<Map> series;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final first = series.isEmpty ? '' : series.first['day'] as String;
    final last = series.isEmpty ? '' : series.last['day'] as String;
    String short(String d) => d.length >= 10 ? '${d.substring(8, 10)}/${d.substring(5, 7)}' : d;
    return Column(children: [
      Expanded(
        child: CustomPaint(
          size: Size.infinite,
          painter: _ChartPainter(series: series, grid: Theme.of(context).dividerColor),
        ),
      ),
      const SizedBox(height: 6),
      Row(children: [
        Text(short(first), style: t.bodySmall),
        const Spacer(),
        Text(short(last), style: t.bodySmall),
      ]),
    ]);
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter({required this.series, required this.grid});
  final List<Map> series;
  final Color grid;

  @override
  void paint(Canvas canvas, Size size) {
    if (series.isEmpty) return;
    int v(Map m, String k) => (m[k] as num?)?.toInt() ?? 0;
    final maxV = series.fold<int>(1, (m, d) => v(d, 'views') > m ? v(d, 'views') : m);
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (final f in [0.0, .5, 1.0]) {
      final y = size.height * (1 - f);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    final slot = size.width / series.length;
    final barW = (slot * .62).clamp(2.0, 22.0);
    final bar = Paint()..color = Brand.orange;
    final dot = Paint()..color = Brand.ok;
    for (final (i, d) in series.indexed) {
      final x = i * slot + (slot - barW) / 2;
      final h = size.height * v(d, 'views') / maxV;
      if (h > 0) {
        canvas.drawRRect(
          RRect.fromRectAndCorners(Rect.fromLTWH(x, size.height - h, barW, h), topLeft: const Radius.circular(4), topRight: const Radius.circular(4)),
          bar,
        );
      }
      if (v(d, 'contacts') + v(d, 'parts') > 0) {
        canvas.drawCircle(Offset(x + barW / 2, size.height - h - 8), 4, dot);
      }
    }
  }

  @override
  bool shouldRepaint(_ChartPainter old) => old.series != series;
}
