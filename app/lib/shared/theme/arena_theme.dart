import 'package:flutter/material.dart';

class ArenaTheme {
  ArenaTheme._();

  // Core palette — dark industrial with hot accent
  static const Color background = Color(0xFF0A0A0F);
  static const Color surface = Color(0xFF111118);
  static const Color surfaceElevated = Color(0xFF1A1A24);
  static const Color surfaceBorder = Color(0xFF2A2A3A);

  static const Color accent = Color(0xFFFF3C3C);       // hot red
  static const Color accentBlue = Color(0xFF3C8EFF);   // electric blue
  static const Color accentGold = Color(0xFFFFB800);   // score gold
  static const Color accentGreen = Color(0xFF00FF94);  // win green

  static const Color textPrimary = Color(0xFFEEEEF5);
  static const Color textSecondary = Color(0xFF8888A0);
  static const Color textMuted = Color(0xFF44445A);

  // Fighter side colors
  static const Color fighterA = Color(0xFF3C8EFF);
  static const Color fighterB = Color(0xFFFF3C3C);

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: background,
        colorScheme: const ColorScheme.dark(
          primary: accent,
          secondary: accentBlue,
          tertiary: accentGold,
          surface: surface,
          onPrimary: textPrimary,
          onSecondary: textPrimary,
          onSurface: textPrimary,
          error: accent,
        ),
        fontFamily: 'Rajdhani',
        textTheme: const TextTheme(
          displayLarge: TextStyle(
            fontFamily: 'SpaceMono',
            fontSize: 48,
            fontWeight: FontWeight.bold,
            color: textPrimary,
            letterSpacing: -1,
          ),
          displayMedium: TextStyle(
            fontFamily: 'SpaceMono',
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: textPrimary,
            letterSpacing: -0.5,
          ),
          headlineLarge: TextStyle(
            fontFamily: 'Rajdhani',
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: textPrimary,
            letterSpacing: 1.5,
          ),
          headlineMedium: TextStyle(
            fontFamily: 'Rajdhani',
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: textPrimary,
            letterSpacing: 1.2,
          ),
          titleLarge: TextStyle(
            fontFamily: 'Rajdhani',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: textPrimary,
            letterSpacing: 0.8,
          ),
          bodyLarge: TextStyle(
            fontFamily: 'SpaceMono',
            fontSize: 14,
            color: textPrimary,
            height: 1.6,
          ),
          bodyMedium: TextStyle(
            fontFamily: 'SpaceMono',
            fontSize: 12,
            color: textSecondary,
            height: 1.5,
          ),
          labelLarge: TextStyle(
            fontFamily: 'Rajdhani',
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: textPrimary,
            letterSpacing: 2.0,
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: background,
          foregroundColor: textPrimary,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            fontFamily: 'Rajdhani',
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: textPrimary,
            letterSpacing: 2.0,
          ),
        ),
        cardTheme: CardTheme(
          color: surfaceElevated,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
            side: const BorderSide(color: surfaceBorder, width: 1),
          ),
        ),
        dividerTheme: const DividerThemeData(
          color: surfaceBorder,
          thickness: 1,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: const BorderSide(color: surfaceBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: const BorderSide(color: surfaceBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: const BorderSide(color: accentBlue, width: 1.5),
          ),
          labelStyle: const TextStyle(
            color: textSecondary,
            fontFamily: 'Rajdhani',
            fontWeight: FontWeight.w600,
            letterSpacing: 1.0,
          ),
          hintStyle: const TextStyle(color: textMuted, fontFamily: 'SpaceMono', fontSize: 12),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: accent,
            foregroundColor: textPrimary,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            textStyle: const TextStyle(
              fontFamily: 'Rajdhani',
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.0,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: textPrimary,
            side: const BorderSide(color: surfaceBorder),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            textStyle: const TextStyle(
              fontFamily: 'Rajdhani',
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.0,
            ),
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: surfaceElevated,
          labelStyle: const TextStyle(
            fontFamily: 'Rajdhani',
            fontWeight: FontWeight.w600,
            color: textSecondary,
            letterSpacing: 1.0,
          ),
          side: const BorderSide(color: surfaceBorder),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.selected) ? accent : textMuted),
          trackColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.selected) ? accent.withOpacity(0.3) : surfaceBorder),
        ),
        sliderTheme: const SliderThemeData(
          activeTrackColor: accentBlue,
          thumbColor: accentBlue,
          inactiveTrackColor: surfaceBorder,
        ),
      );
}
