import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../data/repository.dart';
import '../explore/account.dart' show RequestCard;
import '../theme.dart';
import '../widgets/common.dart';

/// Scheda Richieste della Gestione: i clienti chiedono se c'è un pezzo, il piazzale risponde.
class RequestsTab extends StatefulWidget {
  const RequestsTab({super.key, this.onOpenCount});

  /// Quante richieste aspettano una risposta (per il numerino sulla scheda).
  final ValueChanged<int>? onOpenCount;
  @override
  State<RequestsTab> createState() => RequestsTabState();
}

class RequestsTabState extends State<RequestsTab> {
  late Future<List<PartRequest>> _data = _load();
  bool _onlyOpen = false;

  Future<List<PartRequest>> _load() async {
    final list = await Repository.instance.yardRequests();
    widget.onOpenCount?.call(list.where((r) => r.open).length);
    return list;
  }

  void reload() => setState(() => _data = _load());

  Future<void> _reply(PartRequest r, {bool? available}) async {
    final done = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (c) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(c).bottom),
        child: _ReplySheet(request: r, available: available),
      ),
    );
    if (done == true) reload();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return FutureBuilder(
      future: _data,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (snap.hasError) {
          return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(padding: const EdgeInsets.all(16), child: Text('${snap.error}', textAlign: TextAlign.center)),
            FilledButton(onPressed: reload, child: const Text('Riprova')),
          ]));
        }
        final all = snap.data!;
        final open = all.where((r) => r.open).length;
        final shown = _onlyOpen ? all.where((r) => r.open).toList() : all;
        return RefreshIndicator(
          onRefresh: () async => reload(),
          child: ListView(padding: const EdgeInsets.fromLTRB(12, 12, 12, 90), children: [
            Constrained(
              maxWidth: 900,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('Richieste dei clienti', style: display(24)),
                const SizedBox(height: 4),
                Text(open == 0
                    ? 'Nessuna richiesta da rispondere.'
                    : open == 1
                        ? '1 cliente aspetta una risposta.'
                        : '$open clienti aspettano una risposta.',
                    style: t.bodyMedium),
                const SizedBox(height: 10),
                Wrap(spacing: 8, children: [
                  ChoiceChip(label: Text('Tutte (${all.length})'), selected: !_onlyOpen, onSelected: (_) => setState(() => _onlyOpen = false)),
                  ChoiceChip(label: Text('Da rispondere ($open)'), selected: _onlyOpen, onSelected: (_) => setState(() => _onlyOpen = true)),
                ]),
                const SizedBox(height: 10),
                if (shown.isEmpty)
                  const Card(child: Padding(
                    padding: EdgeInsets.all(18),
                    child: Text('Quando un cliente chiede un pezzo di una tua auto lo vedi qui, e ti arriva anche un\'email.'),
                  )),
                for (final r in shown)
                  RequestCard(
                    request: r,
                    forYard: true,
                    onTap: () => _reply(r),
                    trailing: Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Wrap(spacing: 8, runSpacing: 8, children: [
                        if (r.open) ...[
                          FilledButton.icon(
                            onPressed: () => _reply(r, available: true),
                            icon: const Icon(Icons.check, size: 18),
                            label: const Text("C'è"),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _reply(r, available: false),
                            icon: const Icon(Icons.close, size: 18),
                            label: const Text('Non c\'è'),
                          ),
                        ] else
                          TextButton.icon(onPressed: () => _reply(r), icon: const Icon(Icons.edit, size: 18), label: const Text('Cambia risposta')),
                        if (r.customerPhone.isNotEmpty)
                          IconButton(
                            tooltip: 'Chiama ${r.customerName}',
                            onPressed: () => openUrl('tel:${r.customerPhone.replaceAll(' ', '')}'),
                            icon: const Icon(Icons.call),
                          ),
                        if (r.customerPhone.isNotEmpty)
                          IconButton(
                            tooltip: 'WhatsApp',
                            onPressed: () => openUrl('https://wa.me/${_waNumber(r.customerPhone)}?text=${Uri.encodeComponent(
                                'Buongiorno ${r.customerName}, la contatto per il ricambio che ha chiesto su SfascioHub: ${r.part}${r.vehicle.isEmpty ? '' : ' (${r.vehicle})'}.')}'),
                            icon: const Icon(Icons.chat),
                          ),
                      ]),
                    ),
                  ),
              ]),
            ),
          ]),
        );
      },
    );
  }

  /// Numero per wa.me: solo cifre, con il prefisso italiano se manca.
  static String _waNumber(String phone) {
    var n = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (n.startsWith('+')) return n.substring(1);
    if (n.startsWith('00')) return n.substring(2);
    return n.startsWith('39') && n.length > 10 ? n : '39$n';
  }
}

class _ReplySheet extends StatefulWidget {
  const _ReplySheet({required this.request, this.available});
  final PartRequest request;
  final bool? available;
  @override
  State<_ReplySheet> createState() => _ReplySheetState();
}

class _ReplySheetState extends State<_ReplySheet> {
  late bool _available = widget.available ?? (widget.request.open || widget.request.available);
  late final _price = TextEditingController(text: widget.request.price);
  late final _reply = TextEditingController(text: widget.request.reply);
  bool _busy = false;

  Future<void> _send() async {
    setState(() => _busy = true);
    try {
      await Repository.instance.replyRequest(widget.request, available: _available, price: _price.text, reply: _reply.text);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showError(context, e);
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    final t = Theme.of(context).textTheme;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(r.part, style: display(24)),
          Text([if (r.vehicle.isNotEmpty) r.vehicle, if (r.customerName.isNotEmpty) r.customerName, r.customerPhone]
              .where((s) => s.isNotEmpty).join(' · '), style: t.bodySmall),
          if (r.note.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Il cliente scrive: "${r.note}"', style: t.bodyMedium?.copyWith(fontStyle: FontStyle.italic)),
          ],
          const SizedBox(height: 16),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, icon: Icon(Icons.check), label: Text("C'è")),
              ButtonSegment(value: false, icon: Icon(Icons.close), label: Text('Non c\'è')),
            ],
            selected: {_available},
            onSelectionChanged: (s) => setState(() => _available = s.first),
          ),
          if (_available) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _price,
              keyboardType: TextInputType.text,
              decoration: const InputDecoration(labelText: 'Prezzo (facoltativo)', hintText: 'es. 80 €'),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _reply,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'Messaggio per il cliente (facoltativo)',
              hintText: _available ? 'es. È in buono stato, passi quando vuole' : 'es. Venduto la settimana scorsa',
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _busy ? null : _send,
            icon: const Icon(Icons.send),
            label: Text(_busy ? 'Invio…' : 'Manda la risposta'),
          ),
          const SizedBox(height: 6),
          Text('Il cliente la vede nell\'app SfascioHub e la riceve per email.', textAlign: TextAlign.center, style: t.bodySmall),
        ]),
      ),
    );
  }
}
