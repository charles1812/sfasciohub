import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Palette ispirata a Gruzzolo: inchiostro verde petrolio, superfici traslucide, accento arancio da piazzale
/// più oro e una tavolozza vivace per grafici e riquadri.
class Brand {
  static const ink = Color(0xFF0F1A1C);
  static const surface = Color(0xFF16262A);
  static const surface2 = Color(0xFF1E3338);
  static const line = Color(0xFF2A4045);
  static const text = Color(0xFFEAF2EF);
  static const muted = Color(0xFF8FA6A2);
  static const faint = Color(0xFF5E7470);

  static const orange = Color(0xFFF26B1D);
  static const orangeDeep = Color(0xFFFF8A4C);
  static const gold = Color(0xFFE0B15E);
  static const ok = Color(0xFF6FCF97);
  static const damage = Color(0xFFE08A6B);
  static const blue = Color(0xFF6FA8E8);
  static const teal = Color(0xFF5BB6A9);
  static const violet = Color(0xFF8FA0E0);
  static const pink = Color(0xFFD98BA6);

  /// Versioni "morbide" (traslucide) per sfondi di etichette e chip.
  static const orangeSoft = Color(0x2EF26B1D);
  static const okSoft = Color(0x296FCF97);
  static const damageSoft = Color(0x2EE08A6B);
  static const goldSoft = Color(0x29E0B15E);

  /// Nomi storici, ora sulle superfici scure.
  static const asphalt = surface;
  static const asphaltSoft = surface2;
  static const paper = ink;

  /// Tavolozza dei grafici (come --c0…--c7 di Gruzzolo).
  static const chart = [gold, teal, violet, pink, ok, Color(0xFFE0A03E), Color(0xFF7FC8D9), Color(0xFFC98B6B)];

  /// Sfumature vivaci per i riquadri in evidenza.
  static const sunset = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
      colors: [Color(0xFF5B2A12), Color(0xFFE8956A), Color(0xFFF7C9A8)], stops: [0, .6, 1]);
  static const goldGlow = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
      colors: [Color(0xFF3A2A0E), Color(0xFFE0B15E), Color(0xFFFFF1C4)], stops: [0, .6, 1]);
  static const emerald = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
      colors: [Color(0xFF1F5A43), Color(0xFF3FAE7C), Color(0xFFB9E7C9)], stops: [0, .6, 1]);
  static const ocean = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
      colors: [Color(0xFF1E2A5B), Color(0xFF4F7FD6), Color(0xFFA9C3F2)], stops: [0, .6, 1]);
  static const lagoon = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
      colors: [Color(0xFF16262A), Color(0xFF3C9AA6), Color(0xFFA6E0E6)], stops: [0, .6, 1]);
  static const berry = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
      colors: [Color(0xFF4A1D4F), Color(0xFFC2566A), Color(0xFFF2A3B3)], stops: [0, .6, 1]);

  /// Sfondo delle intestazioni grandi.
  static const heroGradient = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
      colors: [Color(0xFF1E3338), Color(0xFF16262A), Color(0xFF3A2A20)]);

  /// Riflesso dall'alto delle superfici a vetro.
  static const sheen = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
      colors: [Color(0x14FFFFFF), Color(0x03FFFFFF)]);

  static List<BoxShadow> softShadow([bool _ = true]) => [
        BoxShadow(color: Colors.black.withValues(alpha: .35), blurRadius: 24, offset: const Offset(0, 10)),
      ];
}

/// Carattere dei numeri grandi e dei titoli (come in Gruzzolo).
TextStyle display(double size, {Color color = Brand.text, FontWeight weight = FontWeight.w600}) =>
    GoogleFonts.fraunces(fontSize: size, color: color, fontWeight: weight, height: 1.05, letterSpacing: -.4);

ThemeData buildTheme(Brightness _) {
  final scheme = ColorScheme.fromSeed(
    seedColor: Brand.orange,
    brightness: Brightness.dark,
    primary: Brand.orange,
    onPrimary: Colors.white,
    secondary: Brand.gold,
    surface: Brand.surface,
    onSurface: Brand.text,
    onSurfaceVariant: Brand.muted,
    outline: Brand.line,
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: Brightness.dark);
  final inter = base.textTheme.apply(fontFamily: GoogleFonts.inter().fontFamily, bodyColor: Brand.text, displayColor: Brand.text);
  final text = inter.copyWith(
    headlineLarge: GoogleFonts.fraunces(textStyle: inter.headlineLarge, fontWeight: FontWeight.w600),
    headlineMedium: GoogleFonts.fraunces(textStyle: inter.headlineMedium, fontWeight: FontWeight.w600),
    headlineSmall: GoogleFonts.fraunces(textStyle: inter.headlineSmall, fontWeight: FontWeight.w600, letterSpacing: -.3),
    titleLarge: inter.titleLarge?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -.2),
    titleMedium: inter.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    bodyMedium: inter.bodyMedium?.copyWith(height: 1.4),
    bodySmall: inter.bodySmall?.copyWith(color: Brand.muted),
  );
  final glassCard = Brand.surface.withValues(alpha: .72);
  return base.copyWith(
    scaffoldBackgroundColor: Colors.transparent,
    canvasColor: Brand.surface,
    textTheme: text,
    appBarTheme: AppBarTheme(
      backgroundColor: Brand.ink.withValues(alpha: .55),
      foregroundColor: Brand.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.inter(fontSize: 19, fontWeight: FontWeight.w800, color: Brand.text, letterSpacing: .1),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      color: glassCard,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: Brand.line)),
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Brand.surface2.withValues(alpha: .8),
      hintStyle: const TextStyle(color: Brand.faint),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Brand.line)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Brand.orange, width: 2)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Brand.text,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        side: const BorderSide(color: Brand.line),
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: Brand.orangeDeep)),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: Brand.orange,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      extendedTextStyle: GoogleFonts.inter(fontWeight: FontWeight.w800),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 70,
      backgroundColor: Brand.ink.withValues(alpha: .72),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      indicatorColor: Brand.orange.withValues(alpha: .22),
      iconTheme: WidgetStateProperty.resolveWith((s) =>
          IconThemeData(color: s.contains(WidgetState.selected) ? Brand.orangeDeep : Brand.muted)),
      labelTextStyle: WidgetStateProperty.resolveWith((s) => GoogleFonts.inter(
            fontSize: 12,
            fontWeight: s.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w600,
            color: s.contains(WidgetState.selected) ? Brand.orangeDeep : Brand.muted,
          )),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: Brand.ink.withValues(alpha: .5),
      indicatorColor: Brand.orange.withValues(alpha: .22),
      selectedIconTheme: const IconThemeData(color: Brand.orangeDeep),
      unselectedIconTheme: const IconThemeData(color: Brand.muted),
      selectedLabelTextStyle: GoogleFonts.inter(color: Brand.orangeDeep, fontWeight: FontWeight.w800, fontSize: 12),
      unselectedLabelTextStyle: GoogleFonts.inter(color: Brand.muted, fontWeight: FontWeight.w600, fontSize: 12),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Brand.orange : Brand.surface2),
        foregroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : Brand.text),
        side: const WidgetStatePropertyAll(BorderSide(color: Brand.line)),
        textStyle: WidgetStatePropertyAll(GoogleFonts.inter(fontWeight: FontWeight.w700)),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
      side: const BorderSide(color: Brand.line),
      backgroundColor: Brand.surface2.withValues(alpha: .7),
      selectedColor: Brand.orange.withValues(alpha: .3),
      labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Brand.text),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Brand.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: const BorderSide(color: Brand.line)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Brand.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      showDragHandle: true,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: Brand.surface2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Brand.line)),
    ),
    dividerTheme: const DividerThemeData(color: Brand.line, space: 1),
    listTileTheme: const ListTileThemeData(iconColor: Brand.muted),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Brand.surface2,
      contentTextStyle: GoogleFonts.inter(color: Brand.text, fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: Brand.orange),
  );
}

// ---------------------------------------------------------------------------
// Elementi grafici condivisi: sfondo con bagliori, vetro, comparsa animata, numeri che contano
// ---------------------------------------------------------------------------

/// Sfondo di tutte le app: inchiostro con tre bagliori colorati che si muovono piano.
class AppBackground extends StatefulWidget {
  const AppBackground({super.key, required this.child});
  final Widget child;
  @override
  State<AppBackground> createState() => _AppBackgroundState();
}

class _AppBackgroundState extends State<AppBackground> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(seconds: 24))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(fit: StackFit.expand, children: [
      const ColoredBox(color: Brand.ink),
      RepaintBoundary(
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, _) => CustomPaint(painter: _GlowPainter(_c.value)),
        ),
      ),
      widget.child,
    ]);
  }
}

class _GlowPainter extends CustomPainter {
  _GlowPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final a = t * 2 * math.pi;
    void glow(Offset c, double r, Color color) {
      canvas.drawCircle(c, r, Paint()..shader = RadialGradient(colors: [color, color.withValues(alpha: 0)]).createShader(Rect.fromCircle(center: c, radius: r)));
    }

    final r = math.max(size.width, size.height);
    glow(Offset(size.width * (.15 + .05 * math.sin(a)), size.height * (.08 + .04 * math.cos(a))), r * .55, Brand.gold.withValues(alpha: .13));
    glow(Offset(size.width * (.9 + .04 * math.cos(a)), size.height * (.35 + .06 * math.sin(a))), r * .5, Brand.orange.withValues(alpha: .10));
    glow(Offset(size.width * (.3 + .06 * math.cos(a + 1)), size.height * (.95 + .03 * math.sin(a))), r * .55, Brand.ok.withValues(alpha: .09));
  }

  @override
  bool shouldRepaint(_GlowPainter old) => old.t != t;
}

/// Superficie a vetro: sfocatura di ciò che c'è dietro, riflesso e bordo sottile.
class Glass extends StatelessWidget {
  const Glass({super.key, required this.child, this.radius = 18, this.padding, this.blur = 18, this.gradient, this.onTap});
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry? padding;
  final double blur;

  /// Se c'è, il vetro si colora con questa sfumatura (riquadri in evidenza).
  final Gradient? gradient;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final br = BorderRadius.circular(radius);
    Widget content = Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: br,
        gradient: gradient ?? Brand.sheen,
        color: gradient == null ? Brand.surface.withValues(alpha: .55) : null,
        border: Border.all(color: gradient == null ? Brand.line : Colors.white.withValues(alpha: .18)),
      ),
      child: child,
    );
    if (onTap != null) {
      content = Material(type: MaterialType.transparency, child: InkWell(borderRadius: br, onTap: onTap, child: content));
    }
    return ClipRRect(
      borderRadius: br,
      child: blur > 0 ? BackdropFilter(filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur), child: content) : content,
    );
  }
}

/// Comparsa "a salire" (come l'animazione rise di Gruzzolo), con un piccolo ritardo per creare la cascata.
class Rise extends StatelessWidget {
  const Rise({super.key, required this.child, this.index = 0});
  final Widget child;
  final int index;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 420 + 45 * index.clamp(0, 12)),
      curve: Curves.easeOutCubic,
      builder: (_, v, child) => Opacity(
        opacity: v.clamp(0, 1),
        child: Transform.translate(offset: Offset(0, (1 - v) * 18), child: child),
      ),
      child: child,
    );
  }
}

/// Numero che sale fino al valore quando compare.
class CountUp extends StatelessWidget {
  const CountUp(this.value, {super.key, required this.style, this.format});
  final num value;
  final TextStyle style;
  final String Function(num)? format;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (_, v, _) => Text(format != null ? format!(v) : v.round().toString(), style: style),
    );
  }
}
