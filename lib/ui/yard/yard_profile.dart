import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../data/repository.dart';
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
