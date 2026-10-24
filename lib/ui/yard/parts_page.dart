import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../data/repository.dart';
import '../theme.dart';
import '../widgets/common.dart';

Color partColor(PartStatus s) => switch (s) { PartStatus.ok => Brand.ok, PartStatus.check => Brand.orange, PartStatus.damaged => Brand.damage };
Color partSoft(PartStatus s) =>
    switch (s) { PartStatus.ok => Brand.okSoft, PartStatus.check => Brand.orangeSoft, PartStatus.damaged => Brand.damageSoft };

/// Lista dei ricambi di un veicolo: l'AI la propone, il piazzale tocca per confermare o correggere.
class PartsPage extends StatefulWidget {
  const PartsPage({super.key, required this.vehicle});
  final Vehicle vehicle;
  @override
  State<PartsPage> createState() => _PartsPageState();
}

class _PartsPageState extends State<PartsPage> {
  List<VehiclePart>? _parts;
  Object? _error;
  bool _generating = false;
  PartStatus? _filter;
  final Map<String, VehiclePart> _dirty = {};
  Timer? _saveTimer;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    // uscendo, salva le ultime modifiche senza toccare lo stato della pagina
    if (_dirty.isNotEmpty) Repository.instance.updateParts(widget.vehicle, _dirty.values.toList()).ignore();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final p = await Repository.instance.parts(widget.vehicle);
      if (mounted) setState(() { _parts = p; _error = null; });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _generate() async {
    if ((_parts ?? []).isNotEmpty) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Rigenerare la lista?'),
          content: const Text("L'AI rifà la lista. I pezzi che hai già confermato restano come li hai segnati."),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annulla')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Rigenera')),
          ],
        ),
      );
      if (ok != true) return;
    }
    await _flush();
    setState(() => _generating = true);
    try {
      final p = await Repository.instance.generateParts(widget.vehicle);
      if (mounted) setState(() => _parts = p);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  void _toggle(VehiclePart p) {
    setState(() {
      p.status = p.status.next;
      p.confirmed = true;
      _dirty[p.id] = p;
    });
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 900), _flush);
  }

  Future<void> _flush() async {
    if (_dirty.isEmpty) return;
    final changed = _dirty.values.toList();
    _dirty.clear();
    if (mounted) setState(() => _saving = true);
    try {
      await Repository.instance.updateParts(widget.vehicle, changed);
    } catch (e) {
      for (final p in changed) {
        _dirty[p.id] = p;
      }
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final parts = _parts;
    return Scaffold(
      appBar: AppBar(
        title: Text('Ricambi · ${widget.vehicle.make} ${widget.vehicle.model}', overflow: TextOverflow.ellipsis),
        actions: [
          if (_saving) const Padding(padding: EdgeInsets.all(16), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))),
          if (parts != null && parts.isNotEmpty)
            IconButton(tooltip: 'Rigenera con AI', onPressed: _generating ? null : _generate, icon: const Icon(Icons.auto_awesome)),
        ],
      ),
      body: _error != null
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Padding(padding: const EdgeInsets.all(16), child: Text('$_error', textAlign: TextAlign.center)),
              FilledButton(onPressed: _load, child: const Text('Riprova')),
            ]))
          : parts == null
              ? const Center(child: CircularProgressIndicator())
              : _generating
                  ? Center(child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text('Preparo la lista dei ricambi…', style: t.titleMedium),
                        const SizedBox(height: 4),
                        Text('Guardo modello, danni e foto. Ci vogliono 10–30 secondi.', style: t.bodySmall, textAlign: TextAlign.center),
                      ]),
                    ))
                  : parts.isEmpty
                      ? _empty(t)
                      : _list(parts, t),
    );
  }

  Widget _empty(TextTheme t) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Constrained(
            maxWidth: 460,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.inventory_2_outlined, size: 56, color: Brand.orange),
              const SizedBox(height: 12),
              Text('Nessuna lista ricambi', style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text("L'AI parte da circa 150 ricambi vendibili e li adatta a questo modello: per ognuno dice se è "
                  'probabilmente sano, danneggiato o da verificare. Poi tu tocchi per confermare o correggere.',
                  textAlign: TextAlign.center, style: t.bodyMedium),
              const SizedBox(height: 18),
              FilledButton.icon(onPressed: _generate, icon: const Icon(Icons.auto_awesome), label: const Text('Genera la lista con AI')),
            ]),
          ),
        ),
      );

  Widget _list(List<VehiclePart> parts, TextTheme t) {
    final counts = {for (final s in PartStatus.values) s: parts.where((p) => p.status == s).length};
    final confirmed = parts.where((p) => p.confirmed).length;
    final shown = _filter == null ? parts : parts.where((p) => p.status == _filter).toList();
    final byZone = <DamageZone?, List<VehiclePart>>{};
    for (final p in shown) {
      byZone.putIfAbsent(p.zone, () => []).add(p);
    }
    return ListView(padding: const EdgeInsets.fromLTRB(12, 12, 12, 40), children: [
      Constrained(
        maxWidth: 800,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Wrap(spacing: 8, runSpacing: 8, children: [
            ChoiceChip(label: Text('Tutti ${parts.length}'), selected: _filter == null, onSelected: (_) => setState(() => _filter = null)),
            for (final s in PartStatus.values)
              ChoiceChip(
                label: Text('${s.label} ${counts[s]}'),
                selected: _filter == s,
                selectedColor: partSoft(s),
                avatar: CircleAvatar(backgroundColor: partColor(s), radius: 6),
                onSelected: (_) => setState(() => _filter = _filter == s ? null : s),
              ),
          ]),
          const SizedBox(height: 8),
          Text('Tocca un pezzo per cambiarlo: sano → danneggiato → da verificare. Confermati da te: $confirmed su ${parts.length}.',
              style: t.bodySmall),
          const SizedBox(height: 8),
          for (final MapEntry(key: zone, value: list) in byZone.entries) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 14, 4, 6),
              child: Text(zone?.label ?? 'Altro', style: t.titleSmall?.copyWith(fontWeight: FontWeight.w800, color: Brand.orange)),
            ),
            Card(
              child: Column(children: [
                for (final (i, p) in list.indexed) ...[
                  if (i > 0) const Divider(height: 1),
                  ListTile(
                    dense: true,
                    onTap: () => _toggle(p),
                    title: Text(p.name, style: TextStyle(
                      fontWeight: FontWeight.w600,
                      decoration: p.status == PartStatus.damaged ? TextDecoration.lineThrough : null,
                    )),
                    subtitle: p.confirmed ? const Text('confermato') : null,
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: partSoft(p.status), borderRadius: BorderRadius.circular(100)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        if (p.confirmed) Icon(Icons.check, size: 14, color: partColor(p.status)),
                        if (p.confirmed) const SizedBox(width: 4),
                        Text(p.status.label, style: TextStyle(color: partColor(p.status), fontWeight: FontWeight.w700, fontSize: 12)),
                      ]),
                    ),
                  ),
                ],
              ]),
            ),
          ],
        ]),
      ),
    ]);
  }
}
