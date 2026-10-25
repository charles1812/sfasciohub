import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config.dart';
import '../../data/php_repository.dart';
import '../../data/repository.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/updater.dart';
import 'bi_tab.dart';

PhpRepository get _repo => Repository.instance as PhpRepository;

/// Dollari: 4 decimali sotto il centesimo, altrimenti 2.
String usd(num v) => '\$${v == 0 ? '0' : v < 0.001 ? v.toStringAsFixed(5) : v < 0.01 ? v.toStringAsFixed(4) : v.toStringAsFixed(2)}';

String _date(String? s) {
  if (s == null || s.length < 10) return '—';
  return '${s.substring(8, 10)}/${s.substring(5, 7)}/${s.substring(0, 4)}';
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SfascioHub Admin',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: ThemeMode.dark,
      builder: (_, child) => AppBackground(child: UpdateGate(child: child!)),
      home: !AppConfig.hasServer
          ? const Scaffold(body: Center(child: Text("L'app Admin funziona solo collegata al server.")))
          : ListenableBuilder(
              listenable: Repository.instance,
              builder: (_, _) => Repository.instance.currentUser == null ? const _Login() : const _AdminGate(),
            ),
    );
  }
}

class _Login extends StatefulWidget {
  const _Login();
  @override
  State<_Login> createState() => _LoginState();
}

class _LoginState extends State<_Login> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _signUp = false;
  bool _busy = false;

  Future<void> _submit() async {
    setState(() => _busy = true);
    try {
      _signUp
          ? await _repo.signUp(_email.text, _password.text)
          : await _repo.signIn(_email.text, _password.text);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: Brand.asphalt,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Constrained(
              maxWidth: 420,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: AutofillGroup(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      const Icon(Icons.admin_panel_settings, color: Brand.orange, size: 44),
                      const SizedBox(height: 8),
                      Text('SfascioHub Admin', textAlign: TextAlign.center, style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                      Text('Account, piazzali e costi della piattaforma', textAlign: TextAlign.center, style: t.bodyMedium),
                      const SizedBox(height: 20),
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
                        autofillHints: const [AutofillHints.password],
                        onSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          helperText: _signUp ? 'Almeno 8 caratteri' : null,
                        ),
                      ),
                      const SizedBox(height: 18),
                      FilledButton(onPressed: _busy ? null : _submit, child: Text(_signUp ? 'Crea il mio account' : 'Accedi')),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => setState(() => _signUp = !_signUp),
                        child: Text(_signUp ? 'Ho già un account' : 'Primo accesso? Crea il tuo account'),
                      ),
                      if (_signUp)
                        Text("Poi scrivi la tua email in api/admins.php sul server: solo così l'account diventa admin.",
                            textAlign: TextAlign.center, style: t.bodySmall),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminGate extends StatefulWidget {
  const _AdminGate();
  @override
  State<_AdminGate> createState() => _AdminGateState();
}

class _AdminGateState extends State<_AdminGate> {
  late Future<bool> _admin = _repo.isAdmin();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _admin,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        if (snap.data == true) return const _AdminHome();
        return Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.lock_person_outlined, size: 48, color: Brand.orange),
                const SizedBox(height: 12),
                Text(snap.hasError ? '${snap.error}' : '${_repo.currentUser?.email} non è un account admin.', textAlign: TextAlign.center),
                const SizedBox(height: 6),
                const Text('Aggiungi la tua email in api/admins.php sul server, poi tocca Riprova.', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(onPressed: () => setState(() => _admin = _repo.isAdmin()), child: const Text('Riprova')),
                TextButton(onPressed: _repo.signOut, child: const Text('Esci')),
              ]),
            ),
          ),
        );
      },
    );
  }
}

class _AdminHome extends StatefulWidget {
  const _AdminHome();
  @override
  State<_AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<_AdminHome> {
  int _tab = 0;
  int _reload = 0; // cambia per ricaricare le schede

  @override
  Widget build(BuildContext context) {
    final pages = [
      BiTab(key: ValueKey('o$_reload')),
      _Users(key: ValueKey('u$_reload')),
      _Yards(key: ValueKey('y$_reload')),
      _Requests(key: ValueKey('r$_reload')),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('SfascioHub Admin'),
        actions: [
          IconButton(tooltip: 'Aggiorna dati', icon: const Icon(Icons.refresh), onPressed: () => setState(() => _reload++)),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'out') _repo.signOut();
              if (v == 'update') {
                final messenger = ScaffoldMessenger.of(context);
                if (!await Updater.instance.check()) {
                  messenger.showSnackBar(const SnackBar(content: Text("Hai già l'ultima versione.")));
                }
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(enabled: false, child: Text(_repo.currentUser?.email ?? '')),
              if (Updater.supported)
                const PopupMenuItem(value: 'update', child: ListTile(leading: Icon(Icons.system_update), title: Text('Cerca aggiornamenti'))),
              const PopupMenuItem(value: 'out', child: ListTile(leading: Icon(Icons.logout), title: Text('Esci'))),
            ],
          ),
        ],
      ),
      body: IndexedStack(index: _tab, children: pages),
      floatingActionButton: _tab == 1
          ? FloatingActionButton.extended(
              onPressed: () async {
                final created = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const _NewAccount()));
                if (created == true) setState(() => _reload++);
              },
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Nuovo account'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.insights_outlined), selectedIcon: Icon(Icons.insights), label: 'Panoramica'),
          NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'Account'),
          NavigationDestination(icon: Icon(Icons.storefront_outlined), selectedIcon: Icon(Icons.storefront), label: 'Piazzali'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'Richieste'),
        ],
      ),
    );
  }
}

/// Carica una rotta e mostra caricamento / errore / contenuto.
class _Loader extends StatefulWidget {
  const _Loader({super.key, required this.route, required this.builder});
  final String route;
  final Widget Function(BuildContext context, dynamic data, VoidCallback reload) builder;
  @override
  State<_Loader> createState() => _LoaderState();
}

class _LoaderState extends State<_Loader> {
  late Future<dynamic> _data = _repo.request('GET', widget.route);
  void _reload() => setState(() => _data = _repo.request('GET', widget.route));

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
        return RefreshIndicator(onRefresh: () async => _reload(), child: widget.builder(context, snap.data, _reload));
      },
    );
  }
}

class _Users extends StatefulWidget {
  const _Users({super.key});
  @override
  State<_Users> createState() => _UsersState();
}

class _UsersState extends State<_Users> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return _Loader(
      route: '/admin/users',
      builder: (context, d, reload) {
        final users = (d as List).cast<Map>().where((u) {
          final s = '${u['email']} ${u['yard_name'] ?? ''}'.toLowerCase();
          return _q.isEmpty || s.contains(_q.toLowerCase());
        }).toList();
        return ListView(padding: const EdgeInsets.fromLTRB(12, 12, 12, 90), children: [
          Constrained(
            maxWidth: 900,
            child: Column(children: [
              TextField(
                decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Cerca per email o piazzale'),
                onChanged: (s) => setState(() => _q = s),
              ),
              const SizedBox(height: 8),
              for (final u in users)
                Card(
                  child: ListTile(
                    onTap: () => _actions(context, u, reload),
                    leading: CircleAvatar(
                      backgroundColor: u['disabled'] == true ? Brand.damageSoft : Brand.orangeSoft,
                      child: Icon(u['disabled'] == true ? Icons.block : u['is_admin'] == true ? Icons.admin_panel_settings : Icons.person,
                          color: u['disabled'] == true ? Brand.damage : Brand.orange),
                    ),
                    title: Text(u['email'] as String, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text([
                      (u['yard_name'] as String?) ?? 'nessun piazzale',
                      if (u['is_admin'] == true) 'admin',
                      if (u['disabled'] == true) 'SOSPESO',
                      'ultimo accesso ${_date(u['last_login'] as String?)}',
                    ].join(' · ')),
                    trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(usd((u['ai'] as Map)['cost_month_usd'] as num), style: t.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                      Text('${(u['ai'] as Map)['analyses_month']} AI nel mese', style: t.bodySmall),
                    ]),
                  ),
                ),
              if (users.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Text('Nessun account.')),
            ]),
          ),
        ]);
      },
    );
  }

  Future<void> _update(BuildContext context, Map u, Map<String, dynamic> body, VoidCallback reload) async {
    try {
      final r = await _repo.request('PUT', '/admin/users/${u['id']}', json: body) as Map;
      if (r['password'] != null && context.mounted) {
        await showCredentials(context, u['email'] as String, r['password'] as String, title: 'Nuova password');
      }
      reload();
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  void _actions(BuildContext context, Map u, VoidCallback reload) {
    final ai = u['ai'] as Map;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            title: Text(u['email'] as String, style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text('${u['yard_name'] ?? 'nessun piazzale'} · creato il ${_date(u['created_at'] as String?)}\n'
                'AI: ${ai['analyses']} analisi, ${usd(ai['cost_usd'] as num)} in totale · ${usd(ai['cost_month_usd'] as num)} questo mese'),
            isThreeLine: true,
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.password),
            title: const Text('Reimposta password'),
            subtitle: const Text('Genera una password nuova e chiude le sessioni aperte'),
            onTap: () {
              Navigator.pop(sheet);
              _update(context, u, {'reset_password': true}, reload);
            },
          ),
          if (u['is_me'] != true) ...[
            ListTile(
              leading: Icon(u['disabled'] == true ? Icons.lock_open : Icons.block, color: u['disabled'] == true ? Brand.ok : Brand.damage),
              title: Text(u['disabled'] == true ? 'Riattiva account' : 'Sospendi account'),
              subtitle: Text(u['disabled'] == true ? 'Può di nuovo accedere' : 'Esce subito da tutte le app e non può più entrare'),
              onTap: () {
                Navigator.pop(sheet);
                _update(context, u, {'disabled': u['disabled'] != true}, reload);
              },
            ),
            if (u['admin_from_file'] != true)
              ListTile(
                leading: const Icon(Icons.admin_panel_settings_outlined),
                title: Text(u['is_admin'] == true ? 'Togli ruolo admin' : 'Rendi admin'),
                onTap: () {
                  Navigator.pop(sheet);
                  _update(context, u, {'is_admin': u['is_admin'] != true}, reload);
                },
              ),
          ],
        ]),
      ),
    );
  }
}

/// Mostra email e password da consegnare, con i pulsanti per copiarle.
Future<void> showCredentials(BuildContext context, String email, String password, {String title = 'Account creato'}) {
  final text = 'Ciao! Ecco il tuo accesso a SfascioHub Gestione.\n'
      'Email: $email\nPassword: $password\n'
      'App Android: https://github.com/charles1812/sfasciohub/releases/latest/download/SfascioHub-Gestione.apk\n'
      'Dal computer: ${AppConfig.site}gestione/';
  return showDialog(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Mandali a chi usa l\'account. La password non si potrà più rivedere (al massimo la reimposti).'),
        const SizedBox(height: 12),
        SelectableText('Email: $email\nPassword: $password', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
      ]),
      actions: [
        TextButton(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: text));
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Messaggio copiato: incollalo su WhatsApp o email')));
          },
          child: const Text('Copia messaggio'),
        ),
        FilledButton(onPressed: () => Navigator.pop(c), child: const Text('Fatto')),
      ],
    ),
  );
}

class _NewAccount extends StatefulWidget {
  const _NewAccount();
  @override
  State<_NewAccount> createState() => _NewAccountState();
}

class _NewAccountState extends State<_NewAccount> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _yard = TextEditingController();
  final _city = TextEditingController();
  final _province = TextEditingController();
  final _phone = TextEditingController();
  final _limit = TextEditingController();
  bool _admin = false;
  bool _busy = false;

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final r = await _repo.request('POST', '/admin/users', json: {
        'email': _email.text.trim(),
        'yard_name': _yard.text.trim(),
        'city': _city.text.trim(),
        'province': _province.text.trim(),
        'phone': _phone.text.trim(),
        if (int.tryParse(_limit.text) != null) 'ai_daily_limit': int.parse(_limit.text),
        'is_admin': _admin,
      }) as Map;
      if (!mounted) return;
      await showCredentials(context, r['email'] as String, r['password'] as String);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        showError(context, e);
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Nuovo account')),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Constrained(
            maxWidth: 600,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email di chi userà l\'account *'),
                validator: (s) => (s ?? '').contains('@') ? null : 'Email non valida',
              ),
              const SizedBox(height: 20),
              Text('Sfasciacarrozze', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              Text('Lascia vuoto il nome per creare solo l\'account: il piazzale lo compilerà lui al primo accesso.', style: t.bodySmall),
              const SizedBox(height: 10),
              TextFormField(controller: _yard, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Nome del piazzale')),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(flex: 3, child: TextFormField(controller: _city, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Città'))),
                const SizedBox(width: 12),
                Expanded(child: TextFormField(
                  controller: _province,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [LengthLimitingTextInputFormatter(2)],
                  decoration: const InputDecoration(labelText: 'Prov.'),
                )),
              ]),
              const SizedBox(height: 12),
              TextFormField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Telefono')),
              const SizedBox(height: 12),
              TextFormField(
                controller: _limit,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: 'Analisi AI al giorno', helperText: 'Vuoto = limite predefinito del server'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _admin,
                onChanged: (b) => setState(() => _admin = b),
                title: const Text('Anche amministratore'),
                subtitle: const Text('Potrà usare questa app Admin'),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _busy ? null : _save,
                icon: const Icon(Icons.person_add_alt_1),
                label: Text(_busy ? 'Creo…' : 'Crea account e genera password'),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _Yards extends StatelessWidget {
  const _Yards({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return _Loader(
      route: '/admin/yards',
      builder: (context, d, reload) {
        final yards = (d as List).cast<Map>();
        return ListView(padding: const EdgeInsets.all(12), children: [
          Constrained(
            maxWidth: 900,
            child: Column(children: [
              for (final y in yards)
                Card(
                  child: ListTile(
                    onTap: () => _edit(context, y, reload),
                    leading: CircleAvatar(
                      backgroundColor: y['published'] == true ? Brand.okSoft : Brand.damageSoft,
                      child: Icon(Icons.storefront, color: y['published'] == true ? Brand.ok : Brand.damage),
                    ),
                    title: Text(y['name'] as String, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text([
                      [y['city'], y['province']].where((s) => (s as String? ?? '').isNotEmpty).join(' '),
                      '${y['vehicles']} veicoli',
                      'AI ${y['ai_daily_limit'] ?? 'predef.'}/giorno',
                      if (y['published'] != true) 'NASCOSTO',
                      y['owner_email'] ?? '',
                    ].where((s) => s.toString().isNotEmpty).join(' · ')),
                    trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(usd((y['ai'] as Map)['cost_month_usd'] as num), style: t.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                      Text('tot. ${usd((y['ai'] as Map)['cost_usd'] as num)}', style: t.bodySmall),
                    ]),
                  ),
                ),
            ]),
          ),
        ]);
      },
    );
  }

  void _edit(BuildContext context, Map y, VoidCallback reload) {
    final limit = TextEditingController(text: y['ai_daily_limit']?.toString() ?? '');
    var published = y['published'] == true;
    final ai = y['ai'] as Map;
    showDialog(
      context: context,
      builder: (c) => StatefulBuilder(builder: (c, set) => AlertDialog(
        title: Text(y['name'] as String),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('AI: ${ai['analyses']} analisi · ${usd(ai['cost_usd'] as num)} in totale\n'
              'Questo mese: ${ai['analyses_month']} · ${usd(ai['cost_month_usd'] as num)} · oggi ${ai['analyses_today']}'),
          const SizedBox(height: 12),
          TextField(
            controller: limit,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: 'Analisi AI al giorno', helperText: 'Vuoto = predefinito · 0 = AI spenta'),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: published,
            onChanged: (b) => set(() => published = b),
            title: const Text('Visibile sul sito'),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Annulla')),
          FilledButton(
            onPressed: () async {
              try {
                await _repo.request('PUT', '/admin/yards/${y['id']}', json: {
                  'ai_daily_limit': int.tryParse(limit.text),
                  'published': published,
                });
                if (c.mounted) Navigator.pop(c);
                reload();
              } catch (e) {
                if (context.mounted) showError(context, e);
              }
            },
            child: const Text('Salva'),
          ),
        ],
      )),
    );
  }
}

/// Ogni singola richiesta all'AI: chi, cosa, quante immagini, tempo, costo, esito.
class _Requests extends StatefulWidget {
  const _Requests({super.key});
  @override
  State<_Requests> createState() => _RequestsState();
}

class _RequestsState extends State<_Requests> {
  String _filter = ''; // '', 'photos', 'parts', 'failed'

  String get _route => switch (_filter) {
        'photos' => '/admin/requests?kind=photos',
        'parts' => '/admin/requests?kind=parts',
        'failed' => '/admin/requests?status=failed',
        _ => '/admin/requests',
      };

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        child: Constrained(
          maxWidth: 900,
          child: Wrap(spacing: 8, children: [
            for (final (k, label) in [('', 'Tutte'), ('photos', 'Analisi foto'), ('parts', 'Lista ricambi'), ('failed', 'Errori')])
              ChoiceChip(label: Text(label), selected: _filter == k, onSelected: (_) => setState(() => _filter = k)),
          ]),
        ),
      ),
      Expanded(
        child: _Loader(
          key: ValueKey(_route),
          route: _route,
          builder: (context, d, _) {
            final rows = (d as List).cast<Map>();
            if (rows.isEmpty) {
              return ListView(children: const [Padding(padding: EdgeInsets.all(32), child: Center(child: Text('Nessuna richiesta.')))]);
            }
            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: rows.length,
              itemBuilder: (context, i) {
                final r = rows[i];
                final ok = r['status'] == 'ok';
                final photos = r['kind'] == 'photos';
                final at = (r['at'] as String?) ?? '';
                final vehicle = (r['vehicle'] as String?) ?? '';
                return Constrained(
                  maxWidth: 900,
                  child: Card(
                    child: ListTile(
                      onTap: () => _detail(context, r),
                      leading: CircleAvatar(
                        backgroundColor: ok ? Brand.orangeSoft : Brand.damageSoft,
                        child: Icon(ok ? (photos ? Icons.photo_camera : Icons.inventory_2) : Icons.error_outline,
                            color: ok ? Brand.orange : Brand.damage),
                      ),
                      title: Text([photos ? 'Analisi foto' : 'Lista ricambi', if (vehicle.isNotEmpty) vehicle].join(' · '),
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text([
                        if (at.length >= 16) '${_date(at)} ${at.substring(11, 16)}',
                        (r['yard_name'] ?? r['email'] ?? '').toString(),
                        '${r['images']} foto',
                        '${r['seconds']} s',
                        if (!ok) ((r['error'] as String?) ?? '${r['status']}'),
                      ].where((s) => s.isNotEmpty).join(' · '), maxLines: 2, overflow: TextOverflow.ellipsis),
                      trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text(usd(r['cost_usd'] as num), style: t.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                        if (r['cost_per_image_usd'] != null) Text('${usd(r['cost_per_image_usd'] as num)}/foto', style: t.bodySmall),
                      ]),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    ]);
  }

  void _detail(BuildContext context, Map r) {
    final at = (r['at'] as String?) ?? '';
    final perImage = r['cost_per_image_usd'] == null ? '' : ' (${usd(r['cost_per_image_usd'] as num)} per foto)';
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(r['kind'] == 'photos' ? 'Analisi foto' : 'Lista ricambi'),
        content: SelectableText([
          'Quando: ${_date(at)} ${at.length >= 19 ? at.substring(11, 19) : ''} (UTC)',
          'Piazzale: ${r['yard_name'] ?? '—'}',
          'Account: ${r['email'] ?? '—'}',
          if (((r['vehicle'] as String?) ?? '').isNotEmpty) 'Veicolo: ${r['vehicle']}',
          'Immagini: ${r['images']}',
          'Tempo di risposta: ${r['seconds']} s',
          'Token in entrata: ${r['input_tokens']}',
          'Token in uscita: ${r['output_tokens']}',
          'Costo: ${usd(r['cost_usd'] as num)}$perImage',
          'Esito: ${r['status']}',
          if (((r['error'] as String?) ?? '').isNotEmpty) 'Errore: ${r['error']}',
        ].join('\n')),
        actions: [FilledButton(onPressed: () => Navigator.pop(c), child: const Text('Chiudi'))],
      ),
    );
  }
}
