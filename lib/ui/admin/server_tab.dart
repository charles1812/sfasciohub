import 'package:flutter/material.dart';

import '../../data/php_repository.dart';
import '../../data/repository.dart';
import '../theme.dart';
import '../widgets/common.dart';

PhpRepository get _repo => Repository.instance as PhpRepository;

String _bytes(num? b) {
  if (b == null) return '—';
  if (b < 1024) return '$b B';
  if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(0)} KB';
  if (b < 1024 * 1024 * 1024) return '${(b / 1024 / 1024).toStringAsFixed(1)} MB';
  return '${(b / 1024 / 1024 / 1024).toStringAsFixed(1)} GB';
}

/// "2026-10-25 14:01:16" (UTC) → "25/10 15:01" nell'ora del telefono.
String _when(String? s) {
  if (s == null || s.length < 19) return 'mai';
  final d = DateTime.tryParse('${s.replaceFirst(' ', 'T')}Z')?.toLocal();
  if (d == null) return s;
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)} ${two(d.hour)}:${two(d.minute)}';
}

/// Scheda Server dell'app Admin: cosa manca per pubblicare la piattaforma e lo stato del server.
class ServerTab extends StatefulWidget {
  const ServerTab({super.key});
  @override
  State<ServerTab> createState() => _ServerTabState();
}

class _ServerTabState extends State<ServerTab> {
  late Future<dynamic> _data = _repo.request('GET', '/admin/server');
  void _reload() => setState(() => _data = _repo.request('GET', '/admin/server'));

  static const _groups = {
    'tecnico': ('Tecnico', Icons.memory),
    'legale': ('Legale', Icons.gavel),
    'azienda': ('Azienda e pagamenti', Icons.business_center_outlined),
    'distribuzione': ('Store', Icons.storefront_outlined),
    'mercato': ('Mercato', Icons.groups_outlined),
  };

  Future<void> _toggle(Map item, bool done) async {
    try {
      await _repo.request('PUT', '/admin/checklist/${item['id']}', json: {'done': done});
      _reload();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _data,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (snap.hasError) {
          return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(padding: const EdgeInsets.all(16), child: Text('${snap.error}', textAlign: TextAlign.center)),
            FilledButton(onPressed: _reload, child: const Text('Riprova')),
          ]));
        }
        final d = snap.data as Map;
        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: ListView(padding: const EdgeInsets.fromLTRB(12, 12, 12, 32), children: [
            Constrained(
              maxWidth: 900,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                _launch(context, (d['checklist'] as List).cast<Map>()),
                const SizedBox(height: 20),
                _server(context, d),
              ]),
            ),
          ]),
        );
      },
    );
  }

  // ---- cosa manca per pubblicare ----
  Widget _launch(BuildContext context, List<Map> items) {
    final t = Theme.of(context).textTheme;
    final done = items.where((i) => i['status'] == 'done').length;
    final byGroup = <String, List<Map>>{};
    for (final i in items) {
      byGroup.putIfAbsent(i['group'] as String, () => []).add(i);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(gradient: Brand.sunset, borderRadius: BorderRadius.circular(20)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Pronto per la pubblicazione', style: display(22, color: Colors.white)),
          const SizedBox(height: 4),
          Text('$done di ${items.length} fatte', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: items.isEmpty ? 0 : done / items.length,
              minHeight: 10,
              color: Colors.white,
              backgroundColor: Colors.white24,
            ),
          ),
          const SizedBox(height: 10),
          const Text('Le voci tecniche si controllano da sole. Le altre le spunti tu quando le hai fatte. Tocca una voce per sapere come si fa.',
              style: TextStyle(color: Colors.white, fontSize: 13)),
        ]),
      ),
      for (final g in _groups.entries)
        if (byGroup[g.key] != null) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 18, 4, 6),
            child: Row(children: [
              Icon(g.value.$2, size: 18, color: Brand.muted),
              const SizedBox(width: 8),
              Text(g.value.$1, style: t.titleSmall?.copyWith(color: Brand.muted, fontWeight: FontWeight.w800)),
            ]),
          ),
          for (final i in byGroup[g.key]!) _item(context, i),
        ],
    ]);
  }

  Widget _item(BuildContext context, Map i) {
    final status = i['status'] as String;
    final (icon, color) = switch (status) {
      'done' => (Icons.check_circle, Brand.ok),
      'warn' => (Icons.error_outline, Brand.gold),
      _ => (Icons.radio_button_unchecked, Brand.faint),
    };
    return Card(
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Icon(icon, color: color),
          title: Text(i['title'] as String, style: TextStyle(
            fontWeight: FontWeight.w700,
            color: status == 'done' ? Brand.muted : Brand.text,
            decoration: status == 'done' && i['auto'] != true ? TextDecoration.lineThrough : null,
          )),
          subtitle: Text(i['auto'] == true ? (status == 'done' ? 'a posto' : status == 'warn' ? 'da controllare' : 'da fare') : 'da fare tu',
              style: TextStyle(fontSize: 12, color: color == Brand.faint ? Brand.muted : color)),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(i['how'] as String, style: const TextStyle(height: 1.45)),
            if (i['auto'] != true) ...[
              const SizedBox(height: 10),
              status == 'done'
                  ? TextButton.icon(onPressed: () => _toggle(i, false), icon: const Icon(Icons.undo), label: const Text('Non è ancora fatto'))
                  : FilledButton.icon(onPressed: () => _toggle(i, true), icon: const Icon(Icons.check), label: const Text('Fatto')),
            ],
          ],
        ),
      ),
    );
  }

  // ---- il server ----
  Widget _server(BuildContext context, Map d) {
    final t = Theme.of(context).textTheme;
    final up = d['uploads'] as Map;
    final free = d['disk_free_bytes'] as num?;
    final total = d['disk_total_bytes'] as num?;
    final limits = d['limits'] as Map;
    final tiles = [
      StatTile(icon: Icons.storage, value: _bytes(d['db_bytes'] as num?), label: 'database', color: Brand.blue, index: 0),
      StatTile(icon: Icons.photo_library_outlined, value: _bytes(up['bytes'] as num?), label: '${up['files']} foto', color: Brand.teal, index: 1),
      StatTile(icon: Icons.save_outlined, value: _when(d['last_backup'] as String?), label: 'ultimo backup', color: Brand.ok, index: 2),
      StatTile(icon: Icons.cloud_upload_outlined, value: _when(d['last_deploy'] as String?), label: 'ultima pubblicazione', color: Brand.violet, index: 3),
      StatTile(icon: Icons.devices, value: '${d['sessions_active']}', label: 'accessi attivi', color: Brand.gold, index: 4),
      StatTile(icon: Icons.bug_report_outlined, value: '${d['errors_24h']}', label: 'errori in 24 ore', color: Brand.damage, index: 5),
    ];
    final rows = <(String, String)>[
      ('Indirizzo', '${d['https'] == true ? 'https' : 'http'}://${d['host']}'),
      ('PHP', '${d['php']}'),
      ('Database', '${d['database']} · schema v${d['schema_version']}'),
      if (free != null) ('Spazio libero', total != null && total > 0 ? '${_bytes(free)} di ${_bytes(total)}' : _bytes(free)),
      ('Foto più grande accettata', _bytes(limits['upload_max'] as num?)),
      ('Memoria PHP', '${limits['memory']} · ${limits['max_execution_seconds']} s per richiesta'),
      ('Analisi AI', d['ai_key'] == true ? 'chiave impostata' : 'manca la chiave'),
      ('Mittente email', '${d['mail_from']}'),
      ('Estensioni', (d['extensions'] as List).join(', ')),
      if ((d['missing_extensions'] as List).isNotEmpty) ('Estensioni mancanti', (d['missing_extensions'] as List).join(', ')),
      ('Account da confermare', '${d['users_unverified']}'),
      ('Ora del server', '${d['server_time']} UTC'),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Il server', style: display(22)),
      const SizedBox(height: 10),
      LayoutBuilder(builder: (context, c) {
        final cols = c.maxWidth >= 700 ? 3 : 2;
        final w = (c.maxWidth - (cols - 1) * 10) / cols;
        return Wrap(spacing: 10, runSpacing: 10, children: [for (final tile in tiles) SizedBox(width: w, child: tile)]);
      }),
      const SizedBox(height: 12),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            for (final (k, v) in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(width: 150, child: Text(k, style: t.bodyMedium?.copyWith(color: Brand.muted))),
                  Expanded(child: SelectableText(v, style: const TextStyle(fontWeight: FontWeight.w600))),
                ]),
              ),
          ]),
        ),
      ),
      const SizedBox(height: 12),
      Card(
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            leading: const Icon(Icons.table_rows_outlined),
            title: const Text('Tabelle del database', style: TextStyle(fontWeight: FontWeight.w700)),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            children: [
              for (final tb in (d['tables'] as List).cast<Map>())
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(children: [
                    Expanded(child: Text('${tb['name']}')),
                    Text('${tb['rows']} righe', style: const TextStyle(fontWeight: FontWeight.w600)),
                    if (tb['bytes'] != null) SizedBox(width: 80, child: Text(_bytes(tb['bytes'] as num), textAlign: TextAlign.right, style: t.bodySmall)),
                  ]),
                ),
            ],
          ),
        ),
      ),
    ]);
  }
}
