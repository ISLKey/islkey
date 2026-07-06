import 'package:flutter/material.dart';

class ISLTheme {
  ISLTheme._();

  // ── Default ISL palette (overridden per-customer via branding) ──────────────
  static const Color primary = Color(0xFF0A2540);
  static const Color primaryLight = Color(0xFF1A3A60);
  static const Color accent = Color(0xFFE86C1F);
  static const Color background = Color(0xFFF4F5F7);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF1A2332);
  static const Color textMuted = Color(0xFF6B7280);
  static const Color success = Color(0xFF1A7A4A);
  static const Color warning = Color(0xFFD4AC0D);
  static const Color error = Color(0xFFC0392B);

  // Door / access-control status colours
  static const Color unlockColour = Color(0xFF1A7A4A); // granted / unlocking
  static const Color lockedColour = Color(0xFF0A2540); // at-rest / locked
  static const Color unlockErrorColour = Color(0xFFE86C1F); // denied / problem
  static const Color onlineColour = Color(0xFF1A7A4A);
  static const Color offlineColour = Color(0xFF6B7280);
  static const Color fireColour = Color(0xFFC0392B);

  static Color fromHex(String hex) {
    final clean = hex.replaceAll('#', '');
    final value = int.tryParse('FF$clean', radix: 16);
    return value != null ? Color(value) : primary;
  }

  static ThemeData buildTheme(Color brandColour) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: brandColour,
        primary: brandColour,
        surface: surface,
        background: background,
      ),
      scaffoldBackgroundColor: background,
      appBarTheme: AppBarTheme(
        backgroundColor: brandColour,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          letterSpacing: 0.3,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: brandColour,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: brandColour,
          side: BorderSide(color: brandColour),
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: brandColour, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
      ),
      fontFamily: 'sans-serif',
    );
  }
}
