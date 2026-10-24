import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../theme.dart';

/// Auto vista dall'alto, divisa in zone. In modifica si toccano le zone
/// danneggiate; in lettura si vede a colpo d'occhio cosa è integro.
class DamageMap extends StatelessWidget {
  const DamageMap({super.key, required this.damage, this.onToggle, this.height = 320});

  final Set<DamageZone> damage;
  final ValueChanged<DamageZone>? onToggle;
  final double height;

  // Zone disegnate sulla sagoma: rettangoli in coordinate 0..1 (larghezza, altezza).
  static const _rects = <DamageZone, Rect>{
    DamageZone.front: Rect.fromLTRB(.22, .02, .78, .17),
    DamageZone.frontLeft: Rect.fromLTRB(.06, .10, .22, .32),
    DamageZone.frontRight: Rect.fromLTRB(.78, .10, .94, .32),
    DamageZone.engine: Rect.fromLTRB(.22, .17, .78, .31),
    DamageZone.left: Rect.fromLTRB(.06, .32, .22, .68),
    DamageZone.right: Rect.fromLTRB(.78, .32, .94, .68),
    DamageZone.roof: Rect.fromLTRB(.22, .40, .78, .62),
    DamageZone.rearLeft: Rect.fromLTRB(.06, .68, .22, .90),
    DamageZone.rearRight: Rect.fromLTRB(.78, .68, .94, .90),
    DamageZone.rear: Rect.fromLTRB(.22, .83, .78, .98),
  };

  @override
  Widget build(BuildContext context) {
    final editable = onToggle != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: height,
          child: Center(
            child: AspectRatio(
              aspectRatio: .52,
              child: LayoutBuilder(builder: (context, c) {
                final size = Size(c.maxWidth, c.maxHeight);
                return Stack(children: [
                  Positioned.fill(child: CustomPaint(painter: _CarPainter(damage))),
                  for (final e in _rects.entries)
                    Positioned.fromRect(
                      rect: Rect.fromLTRB(e.value.left * size.width, e.value.top * size.height,
                          e.value.right * size.width, e.value.bottom * size.height),
                      child: Tooltip(
                        message: '${e.key.label}${damage.contains(e.key) ? ' · danneggiato' : ' · integro'}',
                        child: Semantics(
                          button: editable,
                          toggled: damage.contains(e.key),
                          label: e.key.label,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: editable ? () => onToggle!(e.key) : null,
                          ),
                        ),
                      ),
                    ),
                ]);
              }),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Zone senza un posto preciso sulla sagoma
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final z in [DamageZone.glass, DamageZone.interior])
              FilterChip(
                label: Text(z.label),
                selected: damage.contains(z),
                onSelected: editable ? (_) => onToggle!(z) : null,
                selectedColor: Brand.damageSoft,
                checkmarkColor: Brand.damage,
                avatar: editable || damage.contains(z) ? null : const Icon(Icons.check_circle, size: 18, color: Brand.ok),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _legend(Brand.damage, 'Danneggiato'),
          const SizedBox(width: 18),
          _legend(Brand.ok, 'Integro · ricambi'),
        ]),
        if (editable) ...[
          const SizedBox(height: 6),
          Text('Tocca le zone danneggiate', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
        ],
      ],
    );
  }

  Widget _legend(Color c, String t) => Row(children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        Text(t, style: const TextStyle(fontSize: 12.5)),
      ]);
}

class _CarPainter extends CustomPainter {
  _CarPainter(this.damage);
  final Set<DamageZone> damage;

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    Rect r(double l, double t, double rr, double b) => Rect.fromLTRB(l * w, t * h, rr * w, b * h);
    Paint fill(DamageZone z) => Paint()..color = damage.contains(z) ? Brand.damage.withValues(alpha: .85) : Brand.ok.withValues(alpha: .22);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Brand.asphalt.withValues(alpha: .75);

    // ruote
    final tyre = Paint()..color = const Color(0xFF2A2A2A);
    for (final t in [r(.0, .14, .08, .28), r(.92, .14, 1, .28), r(.0, .72, .08, .86), r(.92, .72, 1, .86)]) {
      canvas.drawRRect(RRect.fromRectAndRadius(t, Radius.circular(w * .03)), tyre);
    }

    // carrozzeria
    final body = RRect.fromRectAndCorners(r(.06, .02, .94, .98),
        topLeft: Radius.circular(w * .28), topRight: Radius.circular(w * .28),
        bottomLeft: Radius.circular(w * .18), bottomRight: Radius.circular(w * .18));
    canvas.save();
    canvas.clipRRect(body);
    canvas.drawRect(r(0, 0, 1, 1), Paint()..color = Colors.white);
    final zones = {
      DamageZone.front: r(.22, 0, .78, .17),
      DamageZone.frontLeft: r(0, 0, .22, .32),
      DamageZone.frontRight: r(.78, 0, 1, .32),
      DamageZone.engine: r(.22, .17, .78, .31),
      DamageZone.left: r(0, .32, .22, .68),
      DamageZone.right: r(.78, .32, 1, .68),
      DamageZone.rearLeft: r(0, .68, .22, 1),
      DamageZone.rearRight: r(.78, .68, 1, 1),
      DamageZone.rear: r(.22, .83, .78, 1),
    };
    zones.forEach((z, rect) => canvas.drawRect(rect, fill(z)));
    // abitacolo
    canvas.drawRect(r(.22, .31, .78, .83), Paint()..color = damage.contains(DamageZone.interior) ? Brand.damageSoft : const Color(0xFFF1F3F2));
    canvas.restore();

    // vetri
    final glassPaint = Paint()..color = damage.contains(DamageZone.glass) ? Brand.damage.withValues(alpha: .7) : const Color(0xFF9CC3D5);
    final windshield = Path()
      ..moveTo(.25 * w, .36 * h)
      ..quadraticBezierTo(.5 * w, .30 * h, .75 * w, .36 * h)
      ..lineTo(.72 * w, .41 * h)
      ..quadraticBezierTo(.5 * w, .37 * h, .28 * w, .41 * h)
      ..close();
    canvas.drawPath(windshield, glassPaint);
    final rearGlass = Path()
      ..moveTo(.28 * w, .76 * h)
      ..quadraticBezierTo(.5 * w, .79 * h, .72 * w, .76 * h)
      ..lineTo(.74 * w, .80 * h)
      ..quadraticBezierTo(.5 * w, .83 * h, .26 * w, .80 * h)
      ..close();
    canvas.drawPath(rearGlass, glassPaint);

    // tetto
    final roof = RRect.fromRectAndRadius(r(.27, .42, .73, .74), Radius.circular(w * .06));
    canvas.drawRRect(roof, fill(DamageZone.roof));
    canvas.drawRRect(roof, stroke..strokeWidth = 1.2);

    // fari
    final light = Paint()..color = const Color(0xFFFFE9A8);
    canvas.drawRRect(RRect.fromRectAndRadius(r(.2, .045, .34, .075), const Radius.circular(4)), light);
    canvas.drawRRect(RRect.fromRectAndRadius(r(.66, .045, .8, .075), const Radius.circular(4)), light);
    final tail = Paint()..color = const Color(0xFFE85C5C);
    canvas.drawRRect(RRect.fromRectAndRadius(r(.18, .945, .32, .965), const Radius.circular(3)), tail);
    canvas.drawRRect(RRect.fromRectAndRadius(r(.68, .945, .82, .965), const Radius.circular(3)), tail);

    // specchietti
    final mirror = Paint()..color = Brand.asphalt.withValues(alpha: .8);
    canvas.drawRRect(RRect.fromRectAndRadius(r(.0, .345, .06, .375), const Radius.circular(3)), mirror);
    canvas.drawRRect(RRect.fromRectAndRadius(r(.94, .345, 1, .375), const Radius.circular(3)), mirror);

    canvas.drawRRect(body, stroke..strokeWidth = 2.2);
    // linee porte
    final line = Paint()
      ..color = Brand.asphalt.withValues(alpha: .35)
      ..strokeWidth = 1.2;
    canvas.drawLine(Offset(.06 * w, .52 * h), Offset(.22 * w, .52 * h), line);
    canvas.drawLine(Offset(.78 * w, .52 * h), Offset(.94 * w, .52 * h), line);
    canvas.drawLine(Offset(.22 * w, .17 * h), Offset(.78 * w, .17 * h), line);
  }

  @override
  bool shouldRepaint(_CarPainter old) => old.damage != damage;
}
