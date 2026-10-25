import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../data/repository.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Riquadro colorato sulla scheda dell'auto: invita a chiedere un pezzo al piazzale.
class AskPartCard extends StatelessWidget {
  const AskPartCard({super.key, required this.vehicle});
  final Vehicle vehicle;

  @override
  Widget build(BuildContext context) {
    return Rise(
      child: Glass(
        gradient: Brand.sunset,
        blur: 0,
        padding: const EdgeInsets.all(18),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Ti serve un pezzo di quest\'auto?', style: display(22, color: Colors.white)),
            const SizedBox(height: 6),
            Text('Chiedi disponibilità e prezzo direttamente a ${vehicle.yard?.name ?? 'lo sfasciacarrozze'}.',
                style: TextStyle(color: Colors.white.withValues(alpha: .9), fontWeight: FontWeight.w600)),
            const SizedBox(height: 14),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFF5B2A12)),
              onPressed: () => askPart(context, vehicle),
              icon: const Icon(Icons.chat_bubble_outline),
              label: const Text('Chiedi un pezzo'),
            ),
          ])),
          const SizedBox(width: 10),
          Icon(Icons.build_circle, size: 64, color: Colors.white.withValues(alpha: .35)),
        ]),
      ),
    );
  }
}

/// Foglio per scegliere (o scrivere) il pezzo e mandare la richiesta al piazzale.
Future<void> askPart(BuildContext context, Vehicle v, {VehiclePart? preset}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: _AskSheet(vehicle: v, preset: preset),
    ),
  );
}

class _AskSheet extends StatefulWidget {
  const _AskSheet({required this.vehicle, this.preset});
  final Vehicle vehicle;
  final VehiclePart? preset;
  @override
  State<_AskSheet> createState() => _AskSheetState();
}

class _AskSheetState extends State<_AskSheet> {
  late VehiclePart? _part = widget.preset;
  DamageZone? _zone;
  final _text = TextEditingController();

  Vehicle get v => widget.vehicle;

  String get _what {
    final typed = _text.text.trim();
    if (typed.isNotEmpty) return typed;
    if (_part != null) return _part!.name;
    if (_zone != null) return 'un ricambio della zona ${_zone!.label.toLowerCase()} (${_zone!.parts.toLowerCase()})';
    return '';
  }

  void _send(String channel) {
    final y = v.yard!;
    Repository.instance.track('part', vehicleId: v.id, partId: _text.text.trim().isEmpty ? _part?.id : null, text: _what);
    final msg = 'Buongiorno, ho visto su SfascioHub la ${v.title}${v.year == null ? '' : ' ${v.year}'}. '
        'Avete ancora: $_what? Quanto costa?';
    if (channel == 'whatsapp') {
      openUrl('https://wa.me/${y.whatsapp.replaceAll(RegExp(r'[^0-9]'), '')}?text=${Uri.encodeComponent(msg)}');
    } else {
      openUrl('tel:${y.phone.replaceAll(' ', '')}');
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final y = v.yard!;
    final hasWa = y.whatsapp.replaceAll(RegExp(r'[^0-9]'), '').isNotEmpty;
    final suggestions = v.parts.where((p) => p.status != PartStatus.damaged).toList();
    final ready = _what.isNotEmpty;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Che pezzo ti serve?', style: display(24)),
          Text('${v.title}${v.year == null ? '' : ' · ${v.year}'} · ${y.name}', style: t.bodySmall),
          const SizedBox(height: 16),
          if (suggestions.isNotEmpty) ...[
            Text('Pezzi probabilmente disponibili', style: t.labelLarge?.copyWith(color: Brand.gold)),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 190),
              child: SingleChildScrollView(
                child: Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final p in suggestions)
                    ChoiceChip(
                      label: Text(p.name),
                      selected: _part?.id == p.id,
                      onSelected: (on) => setState(() { _part = on ? p : null; _zone = null; }),
                    ),
                ]),
              ),
            ),
          ] else ...[
            Text('Zona dell\'auto', style: t.labelLarge?.copyWith(color: Brand.gold)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final z in v.intactZones)
                ChoiceChip(
                  label: Text(z.label),
                  selected: _zone == z,
                  onSelected: (on) => setState(() { _zone = on ? z : null; _part = null; }),
                ),
            ]),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _text,
            onChanged: (_) => setState(() {}),
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Oppure scrivi il pezzo', hintText: 'es. specchietto destro elettrico'),
          ),
          const SizedBox(height: 18),
          Row(children: [
            if (hasWa)
              Expanded(child: FilledButton.icon(
                onPressed: ready ? () => _send('whatsapp') : null,
                icon: const Icon(Icons.chat),
                label: const Text('Chiedi su WhatsApp'),
              )),
            if (hasWa && y.phone.isNotEmpty) const SizedBox(width: 10),
            if (y.phone.isNotEmpty)
              Expanded(child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                onPressed: ready ? () => _send('call') : null,
                icon: const Icon(Icons.call),
                label: const Text('Chiama'),
              )),
          ]),
          if (!hasWa && y.phone.isEmpty)
            const Text('Questo piazzale non ha ancora inserito telefono o WhatsApp.'),
        ]),
      ),
    );
  }
}
