import 'package:flutter/material.dart';

/// Palette "piazzale": asfalto scuro, arancio da cantiere, verde per l'integro.
class Brand {
  static const asphalt = Color(0xFF1E2326);
  static const asphaltSoft = Color(0xFF2B3236);
  static const orange = Color(0xFFF26B1D);
  static const orangeDeep = Color(0xFFD9530B);
  static const orangeSoft = Color(0xFFFFE4D2);
  static const ok = Color(0xFF2E8B57);
  static const okSoft = Color(0xFFDDF2E5);
  static const damage = Color(0xFFD64545);
  static const damageSoft = Color(0xFFFADBD8);
  static const paper = Color(0xFFF6F4F0);

  /// Sfondo delle intestazioni grandi (sito, piazzale).
  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1E2326), Color(0xFF2E3539), Color(0xFF3A2A20)],
  );

  /// Ombra morbida per le schede.
  static List<BoxShadow> softShadow(bool dark) => [
        BoxShadow(color: Colors.black.withValues(alpha: dark ? .35 : .06), blurRadius: 18, offset: const Offset(0, 6)),
      ];
}

ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: Brand.orange,
    brightness: brightness,
    primary: Brand.orange,
    onPrimary: Colors.white,
    surface: dark ? const Color(0xFF15191B) : Brand.paper,
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: brightness);
  final card = dark ? const Color(0xFF20262A) : Colors.white;
  final line = dark ? Colors.white10 : const Color(0xFFEAE5DC);
  final text = base.textTheme.copyWith(
    headlineSmall: base.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -.3),
    titleLarge: base.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -.2),
    titleMedium: base.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    bodyMedium: base.textTheme.bodyMedium?.copyWith(height: 1.4),
  );
  return base.copyWith(
    scaffoldBackgroundColor: scheme.surface,
    textTheme: text,
    appBarTheme: AppBarTheme(
      backgroundColor: dark ? const Color(0xFF15191B) : Brand.asphalt,
      foregroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: .2),
    ),
    cardTheme: CardThemeData(
      elevation: dark ? 0 : 1.5,
      shadowColor: Colors.black.withValues(alpha: .25),
      surfaceTintColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      color: card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: line)),
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: card,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: dark ? Colors.white24 : const Color(0xFFDAD4C8)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Brand.orange, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        side: BorderSide(color: dark ? Colors.white30 : const Color(0xFFD5CEC2)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: Brand.orange,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      extendedTextStyle: const TextStyle(fontWeight: FontWeight.w800),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 70,
      backgroundColor: card,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.black26,
      elevation: 8,
      indicatorColor: Brand.orangeSoft.withValues(alpha: dark ? .25 : 1),
      iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
            color: s.contains(WidgetState.selected) ? Brand.orangeDeep : (dark ? Colors.white70 : const Color(0xFF5B5550)),
          )),
      labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
            fontSize: 12,
            fontWeight: s.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w600,
            color: s.contains(WidgetState.selected) ? Brand.orangeDeep : null,
          )),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: card,
      indicatorColor: Brand.orangeSoft.withValues(alpha: dark ? .25 : 1),
      selectedIconTheme: const IconThemeData(color: Brand.orangeDeep),
      selectedLabelTextStyle: const TextStyle(color: Brand.orangeDeep, fontWeight: FontWeight.w800, fontSize: 12),
      unselectedLabelTextStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Brand.orange : card),
        foregroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : null),
        textStyle: const WidgetStatePropertyAll(TextStyle(fontWeight: FontWeight.w700)),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
      side: BorderSide(color: line),
      backgroundColor: card,
      labelStyle: const TextStyle(fontWeight: FontWeight.w600),
    ),
    dividerTheme: DividerThemeData(color: line, space: 1),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}
