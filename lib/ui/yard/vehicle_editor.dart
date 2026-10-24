
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../data/models.dart';
import '../../data/repository.dart';
import '../explore/vehicle_page.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/damage_map.dart';

/// Scheda di inserimento / modifica di un veicolo: foto, dati, zone danneggiate.
class VehicleEditor extends StatefulWidget {
  const VehicleEditor({super.key, required this.yard, this.vehicle});
  final Yard yard;
  final Vehicle? vehicle;
  @override
  State<VehicleEditor> createState() => _VehicleEditorState();
}

class _PendingPhoto {
  _PendingPhoto(this.bytes);
  final Uint8List bytes;
}

class _VehicleEditorState extends State<VehicleEditor> {
  late final Vehicle _v = widget.vehicle?.copy() ?? Vehicle(id: const Uuid().v4(), yardId: widget.yard.id, make: '', model: '');
  final _form = GlobalKey<FormState>();
  late final _make = TextEditingController(text: _v.make);
  late final _model = TextEditingController(text: _v.model);
  late final _version = TextEditingController(text: _v.version);
  late final _year = TextEditingController(text: _v.year?.toString() ?? '');
  late final _km = TextEditingController(text: _v.km?.toString() ?? '');
  late final _color = TextEditingController(text: _v.color);
  late final _engine = TextEditingController(text: _v.engineCode);
  late final _notes = TextEditingController(text: _v.notes);

  /// Foto già salvate + foto nuove da caricare, nell'ordine mostrato.
  late final List<Object> _photos = [..._v.photos];
  final List<VehiclePhoto> _removed = [];
  bool _busy = false;
  bool get _isNew => widget.vehicle == null;

  /// Analisi AI rimaste oggi; null = riconoscimento non disponibile.
  int? _aiRemaining;
  bool _aiBusy = false;
  AiResult? _ai;
  TextEditingController? _makeField; // il campo visibile dell'autocompletamento
  int _aiRun = 0; // cambia la chiave dei campi a valore iniziale (alimentazione)

  @override
  void initState() {
    super.initState();
    Repository.instance.aiRemaining().then((n) {
      if (mounted) setState(() => _aiRemaining = n);
    });
  }

  Future<void> _analyze() async {
    final shots = _photos.take(5).toList();
    setState(() => _aiBusy = true);
    try {
      final r = await Repository.instance.analyzePhotos(
        images: [for (final p in shots) if (p is _PendingPhoto) p.bytes],
        photoIds: [for (final p in shots) if (p is VehiclePhoto) p.id],
      );
      if (!mounted) return;
      void put(TextEditingController c, String value) {
        if (value.isNotEmpty) c.text = value;
      }
      setState(() {
        put(_make, r.make);
        if (_makeField != null) put(_makeField!, r.make);
        put(_model, r.model);
        put(_version, r.version);
        if (r.year != null) _year.text = '${r.year}';
        put(_color, r.color);
        if (r.fuel.isNotEmpty) _v.fuel = r.fuel;
        _v.damage = {...r.damage};
        if (_notes.text.trim().isEmpty) _notes.text = r.notes;
        _ai = r;
        _aiRemaining = r.remaining ?? _aiRemaining;
        _aiRun++;
      });
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _aiBusy = false);
    }
  }

  Future<void> _addPhotos(ImageSource source) async {
    final picker = ImagePicker();
    try {
      final files = source == ImageSource.camera
          ? [?await picker.pickImage(source: source, maxWidth: 1600, maxHeight: 1600, imageQuality: 72)]
          : await picker.pickMultiImage(maxWidth: 1600, maxHeight: 1600, imageQuality: 72);
      for (final f in files) {
        final bytes = await f.readAsBytes();
        setState(() => _photos.add(_PendingPhoto(bytes)));
      }
    } catch (e) {
      if (mounted) showError(context, 'Impossibile aprire ${source == ImageSource.camera ? 'la fotocamera' : 'la galleria'}: $e');
    }
  }

  void _collect() {
    _v
      ..make = _make.text.trim()
      ..model = _model.text.trim()
      ..version = _version.text.trim()
      ..year = int.tryParse(_year.text.trim())
      ..km = int.tryParse(_km.text.replaceAll('.', '').trim())
      ..color = _color.text.trim()
      ..engineCode = _engine.text.trim().toUpperCase()
      ..notes = _notes.text.trim();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    _collect();
    setState(() => _busy = true);
    final repo = Repository.instance;
    try {
      final saved = await repo.saveVehicle(_v);
      for (final p in _removed) {
        await repo.removePhoto(saved, p);
      }
      for (var i = 0; i < _photos.length; i++) {
        final p = _photos[i];
        if (p is _PendingPhoto) {
          final uploaded = await repo.addPhoto(saved, p.bytes, i);
          _photos[i] = uploaded;
        }
      }
      final order = [for (final p in _photos) (p as VehiclePhoto).id];
      if (order.isNotEmpty) await repo.reorderPhotos(saved, order);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_v.published ? '${_v.title} è online' : '${_v.title} salvato (non pubblicato)'),
        behavior: SnackBarBehavior.floating,
      ));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        showError(context, e);
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Eliminare il veicolo?'),
        content: Text('${_v.title} sparirà dal sito e dal tuo piazzale, insieme alle foto.\n\nSe è solo stato demolito puoi invece segnarlo come "Demolito / venduto".'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annulla')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: Brand.damage), onPressed: () => Navigator.pop(c, true), child: const Text('Elimina')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await Repository.instance.deleteVehicle(_v);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        showError(context, e);
        setState(() => _busy = false);
      }
    }
  }

  void _preview() {
    _collect();
    final v = _v.copy()
      ..yard = widget.yard
      ..photos = [
        for (final (i, p) in _photos.indexed)
          p is VehiclePhoto ? p : VehiclePhoto(id: 'p$i', url: Uri.dataFromBytes((p as _PendingPhoto).bytes, mimeType: 'image/jpeg').toString(), position: i),
      ];
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => VehicleDetails(vehicle: v, preview: true)));
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final camera = !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

    final photos = _section('Foto', Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SizedBox(
        height: 120,
        child: ReorderableListView.builder(
          scrollDirection: Axis.horizontal,
          buildDefaultDragHandles: false,
          itemCount: _photos.length + 1,
          onReorderItem: (a, b) {
            if (a >= _photos.length) return;
            setState(() => _photos.insert(b.clamp(0, _photos.length - 1), _photos.removeAt(a)));
          },
          itemBuilder: (_, i) {
            if (i == _photos.length) {
              return Padding(
                key: const ValueKey('add'),
                padding: const EdgeInsets.only(right: 10),
                child: Row(children: [
                  if (camera) _addTile(Icons.photo_camera, 'Scatta', () => _addPhotos(ImageSource.camera)),
                  _addTile(Icons.photo_library_outlined, camera ? 'Galleria' : 'Aggiungi foto', () => _addPhotos(ImageSource.gallery)),
                ]),
              );
            }
            final p = _photos[i];
            return ReorderableDelayedDragStartListener(
              key: ObjectKey(p),
              index: i,
              child: Padding(
                padding: const EdgeInsets.only(right: 10),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 150,
                    child: Stack(fit: StackFit.expand, children: [
                      p is VehiclePhoto ? PhotoView(url: p.url) : Image.memory((p as _PendingPhoto).bytes, fit: BoxFit.cover),
                      if (i == 0)
                        Positioned(left: 6, bottom: 6, child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(color: Brand.orange, borderRadius: BorderRadius.circular(100)),
                          child: const Text('Copertina', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                        )),
                      Positioned(
                        right: 4, top: 4,
                        child: IconButton.filled(
                          style: IconButton.styleFrom(backgroundColor: Colors.black54, minimumSize: const Size(32, 32), padding: EdgeInsets.zero),
                          iconSize: 18,
                          tooltip: 'Rimuovi',
                          onPressed: () => setState(() {
                            _photos.removeAt(i);
                            if (p is VehiclePhoto) _removed.add(p);
                          }),
                          icon: const Icon(Icons.close, color: Colors.white),
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
            );
          },
        ),
      ),
      const SizedBox(height: 6),
      Text('Tieni premuto e trascina per cambiare ordine. La prima è la copertina. Consigliate: davanti, dietro, i due lati, il motore.',
          style: t.bodySmall),
      if (_aiRemaining != null) ...[
        const SizedBox(height: 12),
        FilledButton.tonalIcon(
          onPressed: _photos.isEmpty || _aiBusy || _busy || _aiRemaining == 0 ? null : _analyze,
          icon: _aiBusy
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.auto_awesome),
          label: Text(_aiBusy
              ? 'Sto guardando le foto…'
              : _photos.isEmpty
                  ? 'Aggiungi le foto per compilare in automatico'
                  : _aiRemaining == 0
                      ? 'Analisi di oggi esaurite'
                      : 'Compila dalle foto (marca, modello, anno, danni)'),
        ),
        if (_aiRemaining! > 0 && !_aiBusy) ...[
          const SizedBox(height: 4),
          Text('Usa fino a 5 foto · ancora $_aiRemaining analisi oggi', style: t.bodySmall, textAlign: TextAlign.center),
        ],
        if (_ai case final r?) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Brand.orangeSoft.withValues(alpha: .6), borderRadius: BorderRadius.circular(12)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.auto_awesome, color: Brand.orange, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(
                [
                  'Compilato dalle foto (affidabilità ${r.confidence}).',
                  if (r.yearRange.isNotEmpty) 'Serie: ${r.yearRange}.',
                  'Controlla i dati e la mappa dei danni prima di salvare.',
                ].join(' '),
                style: t.bodySmall,
              )),
            ]),
          ),
        ],
      ],
    ]));

    final data = _section('Dati del veicolo', Column(children: [
      Row(children: [
        Expanded(
          child: Autocomplete<String>(
            initialValue: _make.value,
            optionsBuilder: (v) => v.text.isEmpty
                ? const Iterable<String>.empty()
                : commonMakes.where((m) => m.toLowerCase().startsWith(v.text.toLowerCase())),
            onSelected: (m) => _make.text = m,
            fieldViewBuilder: (context, ctrl, focus, onSubmit) {
              if (_makeField != ctrl) {
                _makeField = ctrl;
                ctrl.addListener(() => _make.text = ctrl.text);
              }
              return TextFormField(
                controller: ctrl,
                focusNode: focus,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Marca *'),
                validator: (s) => (s ?? '').trim().isEmpty ? 'Obbligatoria' : null,
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: TextFormField(
          controller: _model,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Modello *'),
          validator: (s) => (s ?? '').trim().isEmpty ? 'Obbligatorio' : null,
        )),
      ]),
      const SizedBox(height: 12),
      TextFormField(controller: _version, decoration: const InputDecoration(labelText: 'Versione / allestimento', hintText: 'es. 1.2 Easy, 2.0 TDI Sport')),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: TextFormField(
          controller: _year,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
          decoration: const InputDecoration(labelText: 'Anno'),
          validator: (s) {
            if ((s ?? '').isEmpty) return null;
            final y = int.tryParse(s!);
            return y == null || y < 1950 || y > DateTime.now().year + 1 ? 'Anno non valido' : null;
          },
        )),
        const SizedBox(width: 12),
        Expanded(child: DropdownButtonFormField<String>(
          key: ValueKey('fuel$_aiRun'),
          initialValue: _v.fuel,
          decoration: const InputDecoration(labelText: 'Alimentazione'),
          items: [for (final e in fuels.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
          onChanged: (f) => _v.fuel = f ?? '',
        )),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: TextFormField(
          controller: _km,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(labelText: 'Chilometri'),
        )),
        const SizedBox(width: 12),
        Expanded(child: TextFormField(controller: _color, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Colore'))),
      ]),
      const SizedBox(height: 12),
      TextFormField(
        controller: _engine,
        textCapitalization: TextCapitalization.characters,
        decoration: const InputDecoration(labelText: 'Codice motore', hintText: 'es. 169A4000 — utile a chi cerca il motore'),
      ),
    ]));

    final damage = _section('Dove è incidentata', DamageMap(
      damage: _v.damage,
      height: 340,
      onToggle: (z) => setState(() {
        final d = {..._v.damage};
        d.contains(z) ? d.remove(z) : d.add(z);
        _v.damage = d;
      }),
    ));

    final notes = _section('Note e stato', Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TextFormField(
        controller: _notes,
        maxLines: 4,
        minLines: 3,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(hintText: 'Cosa c\'è di buono, cosa è già stato smontato, dettagli per chi cerca…'),
      ),
      const SizedBox(height: 14),
      SegmentedButton<VehicleStatus>(
        segments: [for (final s in VehicleStatus.values) ButtonSegment(value: s, label: Text(s.label, textAlign: TextAlign.center))],
        selected: {_v.status},
        onSelectionChanged: (s) => setState(() => _v.status = s.first),
      ),
      const SizedBox(height: 6),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: _v.published,
        onChanged: (b) => setState(() => _v.published = b),
        title: const Text('Visibile sul sito pubblico'),
        subtitle: const Text('Spegni per tenerlo solo nel tuo magazzino'),
      ),
    ]));

    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isNew ? 'Nuovo veicolo' : _v.title),
          actions: [
            IconButton(tooltip: 'Anteprima pubblica', onPressed: _busy ? null : _preview, icon: const Icon(Icons.visibility_outlined)),
            if (!_isNew) IconButton(tooltip: 'Elimina', onPressed: _busy ? null : _delete, icon: const Icon(Icons.delete_outline)),
          ],
        ),
        body: Form(
          key: _form,
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 110), children: [
            Constrained(
              child: wide
                  ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(child: Column(children: [photos, data, notes])),
                      const SizedBox(width: 16),
                      SizedBox(width: 380, child: damage),
                    ])
                  : Column(children: [photos, data, damage, notes]),
            ),
          ]),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Constrained(
              maxWidth: 600,
              child: SizedBox(width: double.infinity, child: FilledButton.icon(
                onPressed: _busy ? null : _save,
                icon: _busy
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.cloud_upload_outlined),
                label: Text(_busy ? 'Salvataggio…' : _isNew ? 'Salva e pubblica' : 'Salva modifiche'),
              )),
            ),
          ),
        ),
      ),
    );
  }

  Widget _section(String title, Widget child) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              child,
            ]),
          ),
        ),
      );

  Widget _addTile(IconData icon, String label, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(right: 10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 110,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Brand.orange, width: 1.5),
              color: Brand.orangeSoft.withValues(alpha: .5),
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, color: Brand.orange, size: 30),
              const SizedBox(height: 6),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF9A4510))),
            ]),
          ),
        ),
      );
}
