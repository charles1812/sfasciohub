import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/models.dart';
import '../theme.dart';

/// Foto da URL o da `data:` URI (modalità demo).
class PhotoView extends StatelessWidget {
  const PhotoView({super.key, required this.url, this.fit = BoxFit.cover});
  final String url;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    Widget err(BuildContext c, Object e, StackTrace? s) => Container(
          color: Colors.black12,
          alignment: Alignment.center,
          child: const Icon(Icons.broken_image_outlined, color: Colors.black38),
        );
    if (url.startsWith('data:')) {
      final bytes = base64Decode(url.substring(url.indexOf(',') + 1));
      return Image.memory(bytes, fit: fit, gaplessPlayback: true, errorBuilder: err);
    }
    return Image.network(url, fit: fit, errorBuilder: err, loadingBuilder: (c, child, p) {
      if (p == null) return child;
      return Container(color: Colors.black12, alignment: Alignment.center, child: const CircularProgressIndicator(strokeWidth: 2));
    });
  }
}

const _colorNames = <String, Color>{
  'bianco': Color(0xFFF2F2F0),
  'nero': Color(0xFF2B2B2B),
  'grigio': Color(0xFF8A9096),
  'argento': Color(0xFFC3C7CB),
  'rosso': Color(0xFFC8352E),
  'blu': Color(0xFF2D5DA8),
  'azzurro': Color(0xFF5FA8D3),
  'verde': Color(0xFF3F7D4E),
  'giallo': Color(0xFFF2C230),
  'arancione': Color(0xFFF07F2A),
  'beige': Color(0xFFD9C7A3),
  'marrone': Color(0xFF7A5232),
  'viola': Color(0xFF6E4C9A),
};

Color vehicleColor(String name) {
  final n = name.toLowerCase();
  for (final e in _colorNames.entries) {
    if (n.contains(e.key)) return e.value;
  }
  return const Color(0xFFB9BEC2);
}

/// Copertina del veicolo: la prima foto, oppure una sagoma del colore dell'auto.
class VehicleCover extends StatelessWidget {
  const VehicleCover({super.key, required this.vehicle});
  final Vehicle vehicle;

  @override
  Widget build(BuildContext context) {
    if (vehicle.photos.isNotEmpty) return PhotoView(url: vehicle.photos.first.url);
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFE9ECEE), Color(0xFFCFD5D9)]),
      ),
      child: CustomPaint(painter: _SilhouettePainter(vehicleColor(vehicle.color)), child: const SizedBox.expand()),
    );
  }
}

class _SilhouettePainter extends CustomPainter {
  _SilhouettePainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width * .78, h = w * .36;
    final ox = (s.width - w) / 2, oy = (s.height - h) / 2 + h * .1;
    Offset p(double x, double y) => Offset(ox + x * w, oy + y * h);
    final body = Path()
      ..moveTo(p(0, .78).dx, p(0, .78).dy)
      ..lineTo(p(0, .5).dx, p(0, .5).dy)
      ..quadraticBezierTo(p(.02, .38).dx, p(.02, .38).dy, p(.14, .34).dx, p(.14, .34).dy)
      ..lineTo(p(.3, .3).dx, p(.3, .3).dy)
      ..quadraticBezierTo(p(.4, .02).dx, p(.4, .02).dy, p(.52, 0).dx, p(.52, 0).dy)
      ..lineTo(p(.74, 0).dx, p(.74, 0).dy)
      ..quadraticBezierTo(p(.84, .02).dx, p(.84, .02).dy, p(.9, .3).dx, p(.9, .3).dy)
      ..quadraticBezierTo(p(1, .36).dx, p(1, .36).dy, p(1, .55).dx, p(1, .55).dy)
      ..lineTo(p(1, .78).dx, p(1, .78).dy)
      ..close();
    canvas.drawShadow(body, Colors.black, 6, false);
    canvas.drawPath(body, Paint()..color = color);
    canvas.drawPath(body, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = Colors.black26);
    final glass = Path()
      ..moveTo(p(.34, .3).dx, p(.34, .3).dy)
      ..quadraticBezierTo(p(.42, .08).dx, p(.42, .08).dy, p(.52, .07).dx, p(.52, .07).dy)
      ..lineTo(p(.73, .07).dx, p(.73, .07).dy)
      ..quadraticBezierTo(p(.8, .09).dx, p(.8, .09).dy, p(.85, .3).dx, p(.85, .3).dy)
      ..close();
    canvas.drawPath(glass, Paint()..color = const Color(0xFF9CB8C7));
    canvas.drawLine(p(.6, .07), p(.6, .3), Paint()
      ..color = color
      ..strokeWidth = 3);
    for (final x in [.2, .8]) {
      canvas.drawCircle(p(x, .8), h * .2, Paint()..color = const Color(0xFF222222));
      canvas.drawCircle(p(x, .8), h * .1, Paint()..color = const Color(0xFFB0B4B8));
    }
  }

  @override
  bool shouldRepaint(_SilhouettePainter old) => old.color != color;
}

class StatusPill extends StatelessWidget {
  const StatusPill(this.status, {super.key});
  final VehicleStatus status;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (status) {
      VehicleStatus.available => (Brand.okSoft, Brand.ok),
      VehicleStatus.reserved => (Brand.orangeSoft, const Color(0xFFB4510F)),
      VehicleStatus.gone => (const Color(0xFFE4E4E4), const Color(0xFF666666)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(100)),
      child: Text(status.label, style: TextStyle(color: fg, fontSize: 11.5, fontWeight: FontWeight.w700)),
    );
  }
}

/// Riassunto in una riga: quante zone integre ci sono.
class IntactSummary extends StatelessWidget {
  const IntactSummary(this.vehicle, {super.key});
  final Vehicle vehicle;

  @override
  Widget build(BuildContext context) {
    final damaged = vehicle.damage.map((z) => z.label.toLowerCase()).join(', ');
    return Row(children: [
      Icon(Icons.build_circle_outlined, size: 16, color: Brand.ok),
      const SizedBox(width: 5),
      Expanded(
        child: Text(
          vehicle.damage.isEmpty ? 'Nessun danno segnalato' : 'Danni: $damaged',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12.5, color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ),
    ]);
  }
}

class VehicleCard extends StatelessWidget {
  const VehicleCard({super.key, required this.vehicle, required this.onTap, this.showYard = true, this.trailing});
  final Vehicle vehicle;
  final VoidCallback onTap;
  final bool showYard;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          AspectRatio(
            aspectRatio: 16 / 10,
            child: Stack(fit: StackFit.expand, children: [
              Hero(tag: 'cover-${vehicle.id}', child: VehicleCover(vehicle: vehicle)),
              Positioned(left: 10, top: 10, child: StatusPill(vehicle.status)),
              if (vehicle.photos.length > 1)
                Positioned(
                  right: 10,
                  top: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(100)),
                    child: Row(children: [
                      const Icon(Icons.photo_camera, size: 13, color: Colors.white),
                      const SizedBox(width: 4),
                      Text('${vehicle.photos.length}', style: const TextStyle(color: Colors.white, fontSize: 12)),
                    ]),
                  ),
                ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(vehicle.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
                ?trailing,
              ]),
              const SizedBox(height: 2),
              Text(vehicle.subtitle, style: t.bodySmall),
              const SizedBox(height: 8),
              IntactSummary(vehicle),
              if (showYard && vehicle.yard != null) ...[
                const SizedBox(height: 6),
                Row(children: [
                  Icon(Icons.place_outlined, size: 16, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text('${vehicle.yard!.name} · ${vehicle.yard!.place}',
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
                  ),
                ]),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Pulsanti per contattare uno sfasciacarrozze.
class ContactButtons extends StatelessWidget {
  const ContactButtons({super.key, required this.yard, this.vehicle});
  final Yard yard;
  final Vehicle? vehicle;

  @override
  Widget build(BuildContext context) {
    final digits = yard.whatsapp.replaceAll(RegExp(r'[^0-9]'), '');
    final text = vehicle == null
        ? 'Buongiorno, vi contatto da SfascioHub.'
        : 'Buongiorno, ho visto su SfascioHub la ${vehicle!.title} ${vehicle!.year ?? ''}. Vorrei informazioni su un ricambio:';
    return Wrap(spacing: 10, runSpacing: 10, children: [
      if (yard.phone.isNotEmpty)
        FilledButton.icon(
          onPressed: () => launchUrl(Uri(scheme: 'tel', path: yard.phone.replaceAll(' ', ''))),
          icon: const Icon(Icons.call),
          label: const Text('Chiama'),
        ),
      if (digits.isNotEmpty)
        FilledButton.tonalIcon(
          onPressed: () => launchUrl(Uri.parse('https://wa.me/$digits?text=${Uri.encodeComponent(text)}'), mode: LaunchMode.externalApplication),
          icon: const Icon(Icons.chat),
          label: const Text('WhatsApp'),
        ),
      if (yard.address.isNotEmpty || yard.lat != null)
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16)),
          onPressed: () {
            final q = yard.lat != null ? '${yard.lat},${yard.lng}' : '${yard.address}, ${yard.city}';
            launchUrl(Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(q)}'), mode: LaunchMode.externalApplication);
          },
          icon: const Icon(Icons.directions),
          label: const Text('Indicazioni'),
        ),
    ]);
  }
}

class DemoBanner extends StatelessWidget {
  const DemoBanner({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        color: Brand.orangeSoft,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(children: [
          const Icon(Icons.science_outlined, size: 18, color: Color(0xFF9A4510)),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12.5, color: Color(0xFF6B300B)))),
        ]),
      );
}

/// Altezza di una [VehicleCard] in una griglia di [cols] colonne larga [width].
double cardExtent(double width, int cols, {bool showYard = true, double maxWidth = 1100, double padding = 32}) {
  final cell = ((width < maxWidth ? width : maxWidth) - padding - (cols - 1) * 14) / cols;
  return cell * 10 / 16 + (showYard ? 128 : 104);
}

Future<void> openUrl(String url) => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

void showError(BuildContext context, Object e) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), behavior: SnackBarBehavior.floating));
}

/// Larghezza massima del contenuto su schermi grandi (desktop / web).
class Constrained extends StatelessWidget {
  const Constrained({super.key, required this.child, this.maxWidth = 1100});
  final Widget child;
  final double maxWidth;
  @override
  Widget build(BuildContext context) =>
      Center(heightFactor: 1, child: ConstrainedBox(constraints: BoxConstraints(maxWidth: maxWidth), child: child));
}
