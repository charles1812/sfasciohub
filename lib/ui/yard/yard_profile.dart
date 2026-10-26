import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/models.dart';
import '../../data/repository.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Dati dello sfasciacarrozze: alla prima apertura (onboarding) e poi in
/// "Il mio piazzale".
class YardProfilePage extends StatefulWidget {
  const YardProfilePage({super.key, this.yard, required this.onSaved, this.onboarding = false});
  final Yard? yard;
  final VoidCallback onSaved;
  final bool onboarding;
  @override
  State<YardProfilePage> createState() => _YardProfilePageState();
}

class _YardProfilePageState extends State<YardProfilePage> {
  final _form = GlobalKey<FormState>();
  late final Yard _y = widget.yard != null
      ? Yard.fromJson(widget.yard!.toJson())
      : Yard(id: '', ownerId: Repository.instance.currentUser?.id ?? '', name: '');
  late final _c = {
    'name': TextEditingController(text: _y.name),
    'city': TextEditingController(text: _y.city),
    'province': TextEditingController(text: _y.province),
    'address': TextEditingController(text: _y.address),
    'phone': TextEditingController(text: _y.phone),
    'whatsapp': TextEditingController(text: _y.whatsapp),
    'email': TextEditingController(text: _y.email),
    'hours': TextEditingController(text: _y.hours),
    'description': TextEditingController(text: _y.description),
  };
  bool _busy = false;

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    _y
      ..name = _c['name']!.text.trim()
      ..city = _c['city']!.text.trim()
      ..province = _c['province']!.text.trim().toUpperCase()
      ..address = _c['address']!.text.trim()
      ..phone = _c['phone']!.text.trim()
      ..whatsapp = _c['whatsapp']!.text.trim()
      ..email = _c['email']!.text.trim()
      ..hours = _c['hours']!.text.trim()
      ..description = _c['description']!.text.trim();
    setState(() => _busy = true);
    try {
      if (widget.onboarding) {
        await Repository.instance.createYard(_y);
      } else {
        await Repository.instance.updateYard(_y);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dati del piazzale salvati')));
      }
      widget.onSaved();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    Widget field(String key, String label, {String? hint, TextInputType? type, int lines = 1, String? Function(String?)? validator}) =>
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextFormField(
            controller: _c[key],
            keyboardType: type,
            maxLines: lines,
            textCapitalization: type == null ? TextCapitalization.sentences : TextCapitalization.none,
            decoration: InputDecoration(labelText: label, hintText: hint),
            validator: validator,
          ),
        );

    final form = Form(
      key: _form,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        Constrained(
          maxWidth: 720,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (widget.onboarding) ...[
              Text('Benvenuto! Come si chiama il tuo sfasciacarrozze?', style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              const Text('Queste informazioni compaiono sul sito pubblico, accanto a ogni veicolo. Puoi cambiarle quando vuoi.'),
              const SizedBox(height: 18),
            ],
            // _y è una copia senza i campi del server: il link lo prende dal piazzale originale
            if (!widget.onboarding && (widget.yard?.catalogUrl ?? '').isNotEmpty) ...[
              CatalogCard(yard: widget.yard!),
              const SizedBox(height: 16),
            ],
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  field('name', 'Nome dell\'attività *', validator: (s) => (s ?? '').trim().length < 2 ? 'Inserisci il nome' : null),
                  Row(children: [
                    Expanded(flex: 3, child: field('city', 'Comune *', validator: (s) => (s ?? '').trim().isEmpty ? 'Obbligatorio' : null)),
                    const SizedBox(width: 12),
                    Expanded(child: field('province', 'Prov.', hint: 'MI', validator: (s) => (s ?? '').trim().length > 2 ? 'Sigla' : null)),
                  ]),
                  field('address', 'Indirizzo'),
                  Row(children: [
                    Expanded(child: field('phone', 'Telefono', type: TextInputType.phone)),
                    const SizedBox(width: 12),
                    Expanded(child: field('whatsapp', 'WhatsApp', type: TextInputType.phone, hint: '+39…')),
                  ]),
                  field('email', 'Email', type: TextInputType.emailAddress),
                  field('hours', 'Orari', hint: 'Lun–Ven 8:30–12:30 / 14–18'),
                  field('description', 'Descrizione', lines: 3, hint: 'Cosa trattate, servizi (spedizione, smontaggio…)'),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Piazzale visibile sul sito'),
                    value: _y.published,
                    onChanged: (b) => setState(() => _y.published = b),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Richieste anche su WhatsApp'),
                    subtitle: const Text('Quando un cliente chiede un pezzo dall\'app, ti arriva anche un messaggio sul numero WhatsApp qui sopra'),
                    value: _y.waLeads,
                    onChanged: (b) => setState(() => _y.waLeads = b),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: Text(widget.onboarding ? 'Crea il mio piazzale' : 'Salva'),
            ),
            if (widget.onboarding)
              TextButton(onPressed: Repository.instance.signOut, child: const Text('Esci')),
          ]),
        ),
      ]),
    );
    return widget.onboarding ? Scaffold(appBar: AppBar(title: const Text('Il tuo piazzale')), body: form) : form;
  }
}

/// Il catalogo del piazzale da condividere: un link corto che su WhatsApp mostra foto e nome.
class CatalogCard extends StatelessWidget {
  const CatalogCard({super.key, required this.yard});
  final Yard yard;

  @override
  Widget build(BuildContext context) {
    final url = yard.catalogUrl;
    return Glass(
      gradient: Brand.emerald,
      blur: 0,
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Il tuo catalogo', style: display(22, color: Colors.white)),
        const SizedBox(height: 4),
        const Text('Mandalo ai clienti, mettilo nello stato di WhatsApp o su Facebook: vedono tutte le tue auto '
            'e ti chiedono i pezzi su WhatsApp.', style: TextStyle(color: Colors.white)),
        if (!yard.published || !yard.approved) ...[
          const SizedBox(height: 8),
          Text(!yard.approved ? 'Il catalogo si apre appena il piazzale viene approvato.' : 'Il piazzale è nascosto: rendilo visibile qui sotto per aprire il catalogo.',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        ],
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(12)),
          child: SelectableText(url, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF25D366), foregroundColor: const Color(0xFF06331B)),
            onPressed: () => openUrl('https://wa.me/?text=${Uri.encodeComponent('Le auto di ${yard.name} da cui recuperare ricambi: $url')}'),
            icon: const Icon(Icons.chat),
            label: const Text('Manda su WhatsApp'),
          ),
          FilledButton.tonalIcon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: url));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link del catalogo copiato')));
            },
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('Copia link'),
          ),
          TextButton.icon(
            onPressed: () => openUrl(url),
            icon: const Icon(Icons.open_in_new, size: 18, color: Colors.white),
            label: const Text('Apri', style: TextStyle(color: Colors.white)),
          ),
        ]),
      ]),
    );
  }
}
