import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../data/repository.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Account dei clienti nell'app SfascioHub: accesso, profilo, richieste di ricambi e auto preferite.

String _day(DateTime? d) {
  if (d == null) return '';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)} ${two(d.hour)}:${two(d.minute)}';
}

/// Auto preferite dell'utente, tenute in memoria per mostrare il cuore pieno o vuoto.
class Favorites extends ChangeNotifier {
  Favorites._();
  static final instance = Favorites._();

  Set<String>? _ids;
  String? _userId;

  bool contains(String vehicleId) => _ids?.contains(vehicleId) ?? false;

  Future<void> load({bool force = false}) async {
    final u = Repository.instance.currentUser;
    if (u == null) {
      _ids = null;
      _userId = null;
      return;
    }
    if (!force && _ids != null && _userId == u.id) return;
    try {
      _ids = (await Repository.instance.favorites()).map((v) => v.id).toSet();
      _userId = u.id;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> toggle(Vehicle v) async {
    final on = !contains(v.id);
    (_ids ??= {}).toggle(v.id, on);
    notifyListeners();
    try {
      await Repository.instance.setFavorite(v, on);
    } catch (e) {
      _ids!.toggle(v.id, !on);
      notifyListeners();
      rethrow;
    }
  }
}

extension on Set<String> {
  void toggle(String id, bool on) => on ? add(id) : remove(id);
}

/// Cuore sulla scheda dell'auto: salva tra i preferiti (chiede di accedere se serve).
class FavoriteButton extends StatefulWidget {
  const FavoriteButton({super.key, required this.vehicle});
  final Vehicle vehicle;
  @override
  State<FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends State<FavoriteButton> {
  @override
  void initState() {
    super.initState();
    Favorites.instance.load();
  }

  Future<void> _tap() async {
    if (Repository.instance.currentUser == null) {
      final ok = await requireLogin(context, reason: 'Accedi per salvare le auto che ti interessano.');
      if (!ok) return;
      await Favorites.instance.load(force: true);
    }
    try {
      await Favorites.instance.toggle(widget.vehicle);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Favorites.instance,
      builder: (context, _) {
        final on = Favorites.instance.contains(widget.vehicle.id);
        return IconButton(
          tooltip: on ? 'Togli dai preferiti' : 'Salva nei preferiti',
          icon: Icon(on ? Icons.favorite : Icons.favorite_border, color: on ? Brand.pink : null),
          onPressed: _tap,
        );
      },
    );
  }
}

/// Se non c'è un account apre la pagina di accesso. Ritorna true se ora l'utente è dentro.
Future<bool> requireLogin(BuildContext context, {String? reason}) async {
  if (Repository.instance.currentUser != null) return true;
  await Navigator.of(context).push(MaterialPageRoute(
    fullscreenDialog: true,
    builder: (_) => Scaffold(
      appBar: AppBar(title: const Text('Accedi')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Constrained(maxWidth: 440, child: CustomerAuthForm(reason: reason, popOnDone: true)),
        ),
      ),
    ),
  ));
  return Repository.instance.currentUser != null;
}

/// Accesso o iscrizione del cliente.
class CustomerAuthForm extends StatefulWidget {
  const CustomerAuthForm({super.key, this.reason, this.popOnDone = false});
  final String? reason;
  final bool popOnDone;
  @override
  State<CustomerAuthForm> createState() => _CustomerAuthFormState();
}

class _CustomerAuthFormState extends State<CustomerAuthForm> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _signUp = false;
  bool _busy = false;

  Future<void> _submit() async {
    setState(() => _busy = true);
    try {
      final repo = Repository.instance;
      _signUp ? await repo.signUp(_email.text, _password.text) : await repo.signIn(_email.text, _password.text);
      if (mounted && widget.popOnDone) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: AutofillGroup(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(_signUp ? 'Crea il tuo account' : 'Accedi a SfascioHub', style: display(24)),
            const SizedBox(height: 6),
            Text(widget.reason ?? 'Con un account chiedi i pezzi ai piazzali e ricevi la risposta qui, e salvi le auto che ti interessano.',
                style: t.bodyMedium),
            const SizedBox(height: 18),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              obscureText: true,
              autofillHints: [_signUp ? AutofillHints.newPassword : AutofillHints.password],
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline),
                helperText: _signUp ? 'Almeno 8 caratteri' : null,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(_signUp ? 'Crea account' : 'Accedi'),
            ),
            if (!_signUp)
              TextButton(onPressed: () => askPasswordReset(context, _email.text), child: const Text('Password dimenticata?')),
            TextButton(
              onPressed: () => setState(() => _signUp = !_signUp),
              child: Text(_signUp ? 'Hai già un account? Accedi' : 'Non hai un account? Iscriviti gratis'),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Scheda Profilo: dati, richieste mandate ai piazzali con le risposte, auto preferite.
class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});
  @override
  State<ProfileTab> createState() => ProfileTabState();
}

class ProfileTabState extends State<ProfileTab> {
  Future<(List<PartRequest>, List<Vehicle>)>? _data;
  String? _loadedFor;

  void reload() {
    final repo = Repository.instance;
    if (repo.currentUser == null) return;
    _loadedFor = repo.currentUser!.id;
    setState(() => _data = () async {
          final r = await repo.myRequests();
          final f = await repo.favorites();
          return (r, f);
        }());
    Favorites.instance.load(force: true);
  }

  Future<void> _editProfile() async {
    final u = Repository.instance.currentUser!;
    final name = TextEditingController(text: u.name);
    final phone = TextEditingController(text: u.phone);
    await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('I tuoi dati'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Li vede solo il piazzale a cui chiedi un pezzo, per poterti rispondere.'),
          const SizedBox(height: 12),
          TextField(controller: name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Nome e cognome')),
          const SizedBox(height: 10),
          TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Telefono')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Annulla')),
          FilledButton(
            onPressed: () async {
              try {
                await Repository.instance.updateProfile(name: name.text, phone: phone.text);
                if (c.mounted) Navigator.pop(c);
              } catch (e) {
                if (c.mounted) showError(c, e);
              }
            },
            child: const Text('Salva'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Repository.instance,
      builder: (context, _) {
        final u = Repository.instance.currentUser;
        if (u == null) {
          _data = null;
          return ListView(padding: const EdgeInsets.all(16), children: const [Constrained(maxWidth: 440, child: CustomerAuthForm())]);
        }
        if (_loadedFor != u.id) WidgetsBinding.instance.addPostFrameCallback((_) => reload());
        return RefreshIndicator(
          onRefresh: () async => reload(),
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 32), children: [
            Constrained(
              maxWidth: 760,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                _header(context, u),
                const SizedBox(height: 22),
                FutureBuilder(
                  future: _data,
                  builder: (context, snap) {
                    if (snap.connectionState != ConnectionState.done) {
                      return const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()));
                    }
                    if (snap.hasError) {
                      return Column(children: [
                        Text('${snap.error}'),
                        TextButton(onPressed: reload, child: const Text('Riprova')),
                      ]);
                    }
                    final (requests, favorites) = snap.data!;
                    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Text('Le mie richieste', style: display(22)),
                      const SizedBox(height: 4),
                      Text('I pezzi che hai chiesto ai piazzali. Quando rispondono lo vedi qui e ti arriva un\'email.',
                          style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: 10),
                      if (requests.isEmpty)
                        const Card(child: Padding(
                          padding: EdgeInsets.all(18),
                          child: Text('Nessuna richiesta ancora. Apri un\'auto e tocca "Chiedi un pezzo".'),
                        )),
                      for (final r in requests) RequestCard(request: r, onTap: r.vehicleId == null
                          ? null
                          : () => Navigator.of(context).pushNamed('/veicolo/${r.vehicleId}')),
                      const SizedBox(height: 22),
                      Text('Auto preferite', style: display(22)),
                      const SizedBox(height: 10),
                      if (favorites.isEmpty)
                        const Card(child: Padding(
                          padding: EdgeInsets.all(18),
                          child: Text('Tocca il cuore su un\'auto per ritrovarla qui.'),
                        )),
                      for (final v in favorites)
                        Card(
                          child: ListTile(
                            onTap: () => Navigator.of(context).pushNamed('/veicolo/${v.id}').then((_) => reload()),
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: SizedBox(
                                width: 64,
                                height: 48,
                                child: v.photos.isEmpty
                                    ? const ColoredBox(color: Brand.surface2, child: Icon(Icons.directions_car))
                                    : Image.network(v.photos.first.url, fit: BoxFit.cover),
                              ),
                            ),
                            title: Text(v.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                            subtitle: Text([if (v.year != null) '${v.year}', v.yard?.name ?? ''].where((s) => s.isNotEmpty).join(' · ')),
                            trailing: const Icon(Icons.chevron_right),
                          ),
                        ),
                    ]);
                  },
                ),
              ]),
            ),
          ]),
        );
      },
    );
  }

  Widget _header(BuildContext context, AppUser u) {
    final t = Theme.of(context).textTheme;
    return Glass(
      gradient: Brand.ocean,
      blur: 0,
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.white24,
            child: Text((u.name.isNotEmpty ? u.name : u.email).substring(0, 1).toUpperCase(),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20)),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(u.name.isNotEmpty ? u.name : 'Il tuo profilo', style: display(22, color: Colors.white)),
            Text(u.email, style: const TextStyle(color: Colors.white70)),
            if (u.phone.isNotEmpty) Text(u.phone, style: const TextStyle(color: Colors.white70)),
          ])),
        ]),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          FilledButton.tonalIcon(onPressed: _editProfile, icon: const Icon(Icons.edit, size: 18), label: const Text('I miei dati')),
          TextButton.icon(
            onPressed: Repository.instance.signOut,
            icon: const Icon(Icons.logout, size: 18, color: Colors.white),
            label: const Text('Esci', style: TextStyle(color: Colors.white)),
          ),
        ]),
        if (!u.emailVerified) ...[
          const SizedBox(height: 8),
          Text('Conferma la tua email con il link che ti abbiamo mandato.', style: t.bodySmall?.copyWith(color: Colors.white)),
        ],
      ]),
    );
  }
}

/// Una richiesta di ricambio con il suo stato: in attesa, c'è (con prezzo), non disponibile.
class RequestCard extends StatelessWidget {
  const RequestCard({super.key, required this.request, this.onTap, this.forYard = false, this.trailing});
  final PartRequest request;
  final VoidCallback? onTap;
  final bool forYard;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final r = request;
    final t = Theme.of(context).textTheme;
    final (label, color, icon) = r.open
        ? (forYard ? 'Da rispondere' : 'In attesa di risposta', Brand.gold, Icons.hourglass_top)
        : r.available
            ? ('C\'è${r.price.isNotEmpty ? ' · ${r.price}' : ''}', Brand.ok, Icons.check_circle)
            : ('Non disponibile', Brand.damage, Icons.cancel_outlined);
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(r.part, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: color.withValues(alpha: .16), borderRadius: BorderRadius.circular(20)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(icon, size: 15, color: color),
                  const SizedBox(width: 5),
                  Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12.5)),
                ]),
              ),
            ]),
            const SizedBox(height: 4),
            Text([
              if (r.vehicle.isNotEmpty) r.vehicle,
              if (forYard) (r.customerName.isNotEmpty ? r.customerName : r.customerEmail) else r.yardName,
              _day(r.createdAt),
            ].join(' · '), style: t.bodySmall),
            if (r.note.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('"${r.note}"', style: t.bodyMedium?.copyWith(fontStyle: FontStyle.italic)),
            ],
            if (r.reply.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Brand.surface2, borderRadius: BorderRadius.circular(12)),
                child: Text(forYard ? 'Hai risposto: ${r.reply}' : '${r.yardName}: ${r.reply}'),
              ),
            ],
            ?trailing,
          ]),
        ),
      ),
    );
  }
}
