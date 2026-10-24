import 'package:flutter/material.dart';

/// Palette "piazzale": asfalto scuro, arancio da cantiere, verde per l'integro.
class Brand {
  static const asphalt = Color(0xFF1E2326);
  static const asphaltSoft = Color(0xFF2B3236);
  static const orange = Color(0xFFF26B1D);
  static const orangeSoft = Color(0xFFFFE4D2);
  static const ok = Color(0xFF2E8B57);
  static const okSoft = Color(0xFFDDF2E5);
  static const damage = Color(0xFFD64545);
  static const damageSoft = Color(0xFFFADBD8);
  static const paper = Color(0xFFF6F4F0);
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
  return base.copyWith(
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: dark ? const Color(0xFF15191B) : Brand.asphalt,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: .2),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      color: dark ? const Color(0xFF20262A) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: dark ? Colors.white10 : const Color(0xFFE6E1D8)),
      ),
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? const Color(0xFF20262A) : Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: dark ? Colors.white24 : const Color(0xFFDAD4C8)),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100))),
  );
}
