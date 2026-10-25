import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../data/php_repository.dart';
import '../../data/repository.dart';
import '../theme.dart';
import '../widgets/common.dart';

PhpRepository get _repo => Repository.instance as PhpRepository;

/// Dollari: più decimali per le cifre piccole (una richiesta costa frazioni di centesimo).
String money(num v) => '\$${v == 0 ? '0' : v < 0.001 ? v.toStringAsFixed(5) : v < 0.01 ? v.toStringAsFixed(4) : v.toStringAsFixed(2)}';
String pct(num v) => '${(v * 100).toStringAsFixed(v < .1 ? 1 : 0)}%';

/// Panoramica della piattaforma: costi per tipo di richiesta, crescita, attività di piazzali e clienti.
class BiTab extends StatefulWidget {
  const BiTab({super.key});
  @override
  State<BiTab> createState() => _BiTabState();
}

class _BiTabState extends State<BiTab> {
  int _days = 60;
  Map<String, dynamic>? _d;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await _repo.request('GET', '/admin/bi?days=$_days') as Map<String, dynamic>;
      if (mounted) setState(() { _d = d; _error = null; });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(padding: const EdgeInsets.all(16), child: Text('$_error', textAlign: TextAlign.center)),
        FilledButton(onPressed: _load, child: const Text('Riprova')),
      ]));
    }
    final d = _d;
    if (d == null) return const Center(child: CircularProgressIndicator());
    final t = Theme.of(context).textTheme;
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 900;
    final p = (d['platform'] as Map).cast<String, dynamic>();
    final c = (d['costs'] as Map).cast<String, dynamic>();
    final kinds = (c['by_kind'] as Map).cast<String, dynamic>();
    final photos = (kinds['photos'] as Map?)?.cast<String, dynamic>() ?? {};
    final parts = (kinds['parts'] as Map?)?.cast<String, dynamic>() ?? {};
    final daily = (d['daily'] as List).cast<Map>();
    final growth = (d['growth'] as List).cast<Map>();
    final cust = (d['customers'] as Map).cast<String, dynamic>();
    final topYards = (d['top_yards'] as List).cast<Map>();
    final makes = (d['makes'] as List).cast<Map>();
    final status = (d['status'] as Map).cast<String, dynamic>();
    num n(Map m, String k) => (m[k] as num?) ?? 0;

    Widget grid(List<Widget> children, {int cols = 4, double ratio = 1.6}) => GridView.count(
          crossAxisCount: wide ? cols : 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: wide ? ratio + .3 : ratio - .15,
          children: children,
        );
    Widget pair(Widget a, Widget b) => wide
        ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: a), const SizedBox(width: 16), Expanded(child: b)])
        : Column(children: [a, const SizedBox(height: 16), b]);

    final costCard = _Panel(
      index: 4,
      title: 'Quanto costa ogni cosa',
      subtitle: 'Medie calcolate sui token contati da Anthropic (Claude Haiku)',
      child: Column(children: [
        _CostRow(
          icon: Icons.photo_camera, gradient: Brand.sunset, title: 'Analisi foto (riconoscimento auto)',
          main: money(n(photos, 'avg_usd')), mainLabel: 'a richiesta',
          facts: [
            ('per foto', photos['per_image_usd'] == null ? '—' : money(n(photos, 'per_image_usd'))),
            ('foto in media', '${n(photos, 'avg_images')}'),
            ('tempo medio', photos['avg_seconds'] == null ? '—' : '${photos['avg_seconds']} s'),
            ('errori', pct(n(photos, 'error_rate'))),
            ('richieste', '${n(photos, 'requests')}'),
            ('totale', money(n(photos, 'total_usd'))),
          ],
        ),
        const Divider(height: 28),
        _CostRow(
          icon: Icons.inventory_2, gradient: Brand.berry, title: 'Lista ricambi',
          main: money(n(parts, 'avg_usd')), mainLabel: 'a richiesta',
          facts: [
            ('token in uscita', '${n(parts, 'avg_output_tokens')}'),
            ('tempo medio', parts['avg_seconds'] == null ? '—' : '${parts['avg_seconds']} s'),
            ('errori', pct(n(parts, 'error_rate'))),
            ('richieste', '${n(parts, 'requests')}'),
            ('totale', money(n(parts, 'total_usd'))),
          ],
        ),
        const Divider(height: 28),
        _CostRow(
          icon: Icons.directions_car, gradient: Brand.goldGlow, title: 'Un\'auto completa (foto + ricambi)',
          main: money(n(c, 'per_vehicle_usd')), mainLabel: 'per auto',
          facts: [
            ('con 1 €', n(c, 'per_vehicle_usd') > 0 ? '≈ ${(1.08 / n(c, 'per_vehicle_usd')).round()} auto' : '—'),
            ('questo mese', money(n(c, 'month_usd'))),
            ('previsione mese', money(n(c, 'month_forecast_usd'))),
          ],
        ),
      ]),
    );

    final costChart = _Panel(
      index: 5,
      title: 'Spesa giorno per giorno',
      legend: const [('Analisi foto', Brand.orange), ('Lista ricambi', Brand.pink)],
      child: SizedBox(height: 200, child: _StackedBars(daily: daily, a: 'cost_photos', b: 'cost_parts', money: true)),
    );

    final requestsChart = _Panel(
      index: 6,
      title: 'Richieste all\'AI',
      legend: const [('Analisi foto', Brand.orange), ('Lista ricambi', Brand.pink)],
      child: SizedBox(height: 200, child: _Lines(
        series: [
          ([for (final x in daily) n(x, 'photos').toDouble()], Brand.orange),
          ([for (final x in daily) n(x, 'parts').toDouble()], Brand.pink),
        ],
        labels: [for (final x in daily) _shortDay(x['day'] as String)],
      )),
    );

    final growthChart = _Panel(
      index: 7,
      title: 'Crescita',
      subtitle: 'Totale a fine mese, ultimi 12 mesi',
      legend: const [('Auto', Brand.gold), ('Piazzali', Brand.teal)],
      child: SizedBox(height: 200, child: _Lines(
        series: [
          ([for (final g in growth) n(g, 'vehicles').toDouble()], Brand.gold),
          ([for (final g in growth) n(g, 'yards').toDouble()], Brand.teal),
        ],
        labels: [for (final g in growth) _shortMonth(g['month'] as String)],
        dualAxis: true,
      )),
    );

    final customersChart = _Panel(
      index: 8,
      title: 'Clienti',
      subtitle: '${n(cust, 'visitors')} persone · ${pct(n(cust, 'contact_rate'))} delle visite diventa un contatto o una richiesta',
      legend: const [('Visite', Brand.blue), ('Contatti', Brand.ok), ('Pezzi chiesti', Brand.violet)],
      child: SizedBox(height: 200, child: _Lines(
        series: [
          ([for (final x in daily) n(x, 'views').toDouble()], Brand.blue),
          ([for (final x in daily) n(x, 'contacts').toDouble()], Brand.ok),
          ([for (final x in daily) n(x, 'requests').toDouble()], Brand.violet),
        ],
        labels: [for (final x in daily) _shortDay(x['day'] as String)],
      )),
    );

    final statusLabels = {'available': 'Disponibili', 'reserved': 'Riservate', 'gone': 'Demolite/vendute'};
    final statusColors = {'available': Brand.ok, 'reserved': Brand.gold, 'gone': Brand.faint};
    final statusPie = _Panel(
      index: 9,
      title: 'Auto per stato',
      child: SizedBox(
        height: 190,
        child: Row(children: [
          Expanded(child: PieChart(PieChartData(
            sectionsSpace: 3,
            centerSpaceRadius: 42,
            sections: [
              for (final e in status.entries)
                PieChartSectionData(
                  value: (e.value as num).toDouble(),
                  color: statusColors[e.key] ?? Brand.violet,
                  title: '${e.value}',
                  radius: 38,
                  titleStyle: const TextStyle(fontWeight: FontWeight.w800, color: Brand.ink),
                ),
            ],
          ))),
          Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final e in status.entries) _Dot(statusLabels[e.key] ?? e.key, statusColors[e.key] ?? Brand.violet, '${e.value}'),
          ]),
        ]),
      ),
    );

    final maxMake = makes.fold<num>(1, (m, x) => n(x, 'vehicles') > m ? n(x, 'vehicles') : m);
    final makesCard = _Panel(
      index: 10,
      title: 'Marche più presenti',
      child: Column(children: [
        for (final (i, m) in makes.indexed)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(children: [
              SizedBox(width: 92, child: Text(m['make'] as String, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700))),
              Expanded(child: _Bar(value: n(m, 'vehicles') / maxMake, color: Brand.chart[i % Brand.chart.length])),
              SizedBox(width: 34, child: Text('${m['vehicles']}', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w800))),
            ]),
          ),
      ]),
    );

    final yardsCard = _Panel(
      index: 11,
      title: 'Piazzali',
      subtitle: 'Visite nel periodo e spesa AI totale',
      child: Column(children: [
        for (final (i, y) in topYards.indexed)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: Brand.chart[i % Brand.chart.length].withValues(alpha: .18), borderRadius: BorderRadius.circular(12)),
              child: Text('${i + 1}', style: TextStyle(color: Brand.chart[i % Brand.chart.length], fontWeight: FontWeight.w900)),
            ),
            title: Text(y['name'] as String, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text('${y['vehicles']} auto · ${y['views']} visite'),
            trailing: Text(money(n(y, 'cost_usd')), style: display(16, color: Brand.gold)),
          ),
      ]),
    );

    final quality = grid(cols: 4, ratio: 1.7, [
      StatTile(index: 12, icon: Icons.directions_car_outlined, color: Brand.gold, value: '${p['vehicles_per_yard']}', label: 'auto per piazzale'),
      StatTile(index: 13, icon: Icons.photo_library_outlined, color: Brand.teal, value: '${p['photos_per_vehicle']}', label: 'foto per auto'),
      StatTile(index: 14, icon: Icons.inventory_2_outlined, color: Brand.pink, value: pct(n(p, 'parts_coverage')), label: 'auto con lista ricambi'),
      StatTile(index: 15, icon: Icons.verified_outlined, color: Brand.ok, value: pct(n(p, 'parts_confirmed')), label: 'pezzi confermati dai piazzali'),
    ]);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 18, 16, 40), children: [
        Constrained(
          maxWidth: 1200,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Panoramica', style: display(34)),
                Text('Tutta la piattaforma SfascioHub', style: t.bodyMedium?.copyWith(color: Brand.muted)),
              ])),
              SegmentedButton<int>(
                segments: const [ButtonSegment(value: 30, label: Text('30 g')), ButtonSegment(value: 60, label: Text('60 g')), ButtonSegment(value: 90, label: Text('90 g'))],
                selected: {_days},
                showSelectedIcon: false,
                onSelectionChanged: (s) {
                  setState(() { _days = s.first; _d = null; });
                  _load();
                },
              ),
            ]),
            const SizedBox(height: 16),
            grid([
              StatTile(index: 0, gradient: Brand.lagoon, icon: Icons.storefront, value: '${p['yards']}', label: '${p['active_yards']} attivi negli ultimi 30 giorni'),
              StatTile(index: 1, gradient: Brand.goldGlow, icon: Icons.directions_car, value: '${p['online']}', label: 'auto online su ${p['vehicles']}'),
              StatTile(index: 2, gradient: Brand.sunset, icon: Icons.payments_outlined, value: money(n(c, 'month_usd')), label: 'spesa AI del mese · prev. ${money(n(c, 'month_forecast_usd'))}'),
              StatTile(index: 3, gradient: Brand.ocean, icon: Icons.visibility_outlined, value: '${cust['views']}', label: 'visite dei clienti in $_days giorni'),
            ]),
            const SizedBox(height: 16),
            pair(costCard, Column(children: [costChart, const SizedBox(height: 16), requestsChart])),
            const SizedBox(height: 16),
            pair(growthChart, customersChart),
            const SizedBox(height: 16),
            quality,
            const SizedBox(height: 16),
            pair(Column(children: [statusPie, const SizedBox(height: 16), makesCard]), yardsCard),
          ]),
        ),
      ]),
    );
  }
}

String _shortDay(String d) => d.length >= 10 ? '${d.substring(8, 10)}/${d.substring(5, 7)}' : d;
const _months = ['gen', 'feb', 'mar', 'apr', 'mag', 'giu', 'lug', 'ago', 'set', 'ott', 'nov', 'dic'];
String _shortMonth(String m) => m.length >= 7 ? _months[(int.tryParse(m.substring(5, 7)) ?? 1) - 1] : m;

class _Panel extends StatelessWidget {
  const _Panel({required this.title, this.subtitle, this.legend = const [], required this.child, this.index = 0});
  final String title;
  final String? subtitle;
  final List<(String, Color)> legend;
  final Widget child;
  final int index;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Rise(
      index: index,
      child: Glass(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(title, style: display(21)),
          if (subtitle != null) ...[const SizedBox(height: 2), Text(subtitle!, style: t.bodySmall)],
          if (legend.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 14, runSpacing: 4, children: [for (final (l, c) in legend) _Dot(l, c, null)]),
          ],
          const SizedBox(height: 14),
          child,
        ]),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot(this.label, this.color, this.value);
  final String label;
  final Color color;
  final String? value;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 12.5, color: Brand.muted, fontWeight: FontWeight.w600)),
          if (value != null) ...[const SizedBox(width: 6), Text(value!, style: const TextStyle(fontWeight: FontWeight.w800))],
        ]),
      );
}

class _Bar extends StatelessWidget {
  const _Bar({required this.value, required this.color});
  final double value;
  final Color color;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value.clamp(0, 1)),
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeOutCubic,
        builder: (_, v, _) => ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(children: [
            Container(height: 10, color: Brand.surface2),
            FractionallySizedBox(
              widthFactor: v,
              child: Container(height: 10, decoration: BoxDecoration(gradient: LinearGradient(colors: [color.withValues(alpha: .6), color]))),
            ),
          ]),
        ),
      );
}

class _CostRow extends StatelessWidget {
  const _CostRow({required this.icon, required this.gradient, required this.title, required this.main, required this.mainLabel, required this.facts});
  final IconData icon;
  final Gradient gradient;
  final String title;
  final String main;
  final String mainLabel;
  final List<(String, String)> facts;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(gradient: gradient, borderRadius: BorderRadius.circular(13)),
          child: Icon(icon, color: Colors.white, size: 21),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(title, style: t.titleSmall?.copyWith(fontWeight: FontWeight.w800))),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(main, style: display(24, color: Brand.gold)),
          Text(mainLabel, style: t.bodySmall),
        ]),
      ]),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final (k, v) in facts)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: Brand.surface2.withValues(alpha: .8), borderRadius: BorderRadius.circular(10), border: Border.all(color: Brand.line)),
            child: Text.rich(TextSpan(children: [
              TextSpan(text: '$k  ', style: const TextStyle(color: Brand.muted, fontSize: 12)),
              TextSpan(text: v, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
            ])),
          ),
      ]),
    ]);
  }
}

FlTitlesData _titles(List<String> labels, {bool money = false}) => FlTitlesData(
      topTitles: const AxisTitles(),
      rightTitles: const AxisTitles(),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: money ? 52 : 34,
          // il valore massimo cade quasi sopra l'ultima riga: non si ripete
          getTitlesWidget: (v, meta) => v == meta.max && v != meta.min
              ? const SizedBox.shrink()
              : Text(money ? '\$${v.toStringAsFixed(v < .01 ? 3 : 2)}' : v.toStringAsFixed(v < 10 && v % 1 != 0 ? 1 : 0),
                  style: const TextStyle(color: Brand.faint, fontSize: 10.5)),
        ),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 22,
          interval: 1,
          getTitlesWidget: (v, meta) {
            final i = v.round();
            final step = (labels.length / 6).ceil().clamp(1, 999);
            if (i < 0 || i >= labels.length || (i % step != 0 && i != labels.length - 1)) return const SizedBox.shrink();
            return Padding(padding: const EdgeInsets.only(top: 6), child: Text(labels[i], style: const TextStyle(color: Brand.faint, fontSize: 10.5)));
          },
        ),
      ),
    );

FlGridData get _grid => FlGridData(
      drawVerticalLine: false,
      getDrawingHorizontalLine: (_) => const FlLine(color: Brand.line, strokeWidth: 1, dashArray: [4, 4]),
    );

/// Linee morbide con riempimento sfumato, come i grafici di Gruzzolo.
class _Lines extends StatelessWidget {
  const _Lines({required this.series, required this.labels, this.dualAxis = false});
  final List<(List<double>, Color)> series;
  final List<String> labels;

  /// Seconda serie riportata sulla scala della prima (es. piazzali e auto, numeri molto diversi).
  final bool dualAxis;

  @override
  Widget build(BuildContext context) {
    var data = series;
    if (dualAxis && series.length == 2) {
      final m0 = series[0].$1.fold<double>(0, (m, v) => v > m ? v : m);
      final m1 = series[1].$1.fold<double>(0, (m, v) => v > m ? v : m);
      final k = m1 == 0 ? 1.0 : (m0 == 0 ? 1.0 : m0 / m1);
      data = [series[0], ([for (final v in series[1].$1) v * k], series[1].$2)];
    }
    return LineChart(
      LineChartData(
        gridData: _grid,
        borderData: FlBorderData(show: false),
        titlesData: _titles(labels),
        minY: 0,
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => Brand.surface2,
            getTooltipItems: (spots) => [
              for (final s in spots)
                LineTooltipItem(
                  (dualAxis && s.barIndex == 1 ? series[1].$1[s.x.round()] : s.y).toStringAsFixed(0),
                  TextStyle(color: series[s.barIndex].$2, fontWeight: FontWeight.w800),
                ),
            ],
          ),
        ),
        lineBarsData: [
          for (final (values, color) in data)
            LineChartBarData(
              spots: [for (final (i, v) in values.indexed) FlSpot(i.toDouble(), v)],
              isCurved: true,
              curveSmoothness: .25,
              preventCurveOverShooting: true,
              color: color,
              barWidth: 3,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [color.withValues(alpha: .28), color.withValues(alpha: 0)]),
              ),
            ),
        ],
      ),
      duration: const Duration(milliseconds: 600),
    );
  }
}

/// Barre impilate per giorno (due serie).
class _StackedBars extends StatelessWidget {
  const _StackedBars({required this.daily, required this.a, required this.b, this.money = false});
  final List<Map> daily;
  final String a;
  final String b;
  final bool money;

  @override
  Widget build(BuildContext context) {
    double v(Map m, String k) => ((m[k] as num?) ?? 0).toDouble();
    final width = (MediaQuery.sizeOf(context).width / daily.length * .35).clamp(2.0, 12.0);
    return BarChart(
      BarChartData(
        gridData: _grid,
        borderData: FlBorderData(show: false),
        titlesData: _titles([for (final x in daily) _shortDay(x['day'] as String)], money: money),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => Brand.surface2,
            getTooltipItem: (group, _, rod, _) => BarTooltipItem(
              '${_shortDay(daily[group.x]['day'] as String)}\n${money ? '\$${rod.toY.toStringAsFixed(4)}' : rod.toY.toStringAsFixed(0)}',
              const TextStyle(color: Brand.text, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        barGroups: [
          for (final (i, x) in daily.indexed)
            BarChartGroupData(x: i, barRods: [
              BarChartRodData(
                toY: v(x, a) + v(x, b),
                width: width,
                borderRadius: BorderRadius.circular(3),
                rodStackItems: [
                  BarChartRodStackItem(0, v(x, a), Brand.orange),
                  BarChartRodStackItem(v(x, a), v(x, a) + v(x, b), Brand.pink),
                ],
              ),
            ]),
        ],
      ),
      duration: const Duration(milliseconds: 600),
    );
  }
}
