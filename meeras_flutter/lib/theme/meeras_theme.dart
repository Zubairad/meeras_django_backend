import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class MeerasTheme {
  // Base tonal palette
  static const Color bg = Color(0xFF0C0C0D);
  static const Color surface = Color(0xFF141416);
  static const Color surfaceElevated = Color(0xFF1D1E22);
  static const Color surfaceSubtle = Color(0xFF27282E);
  static const Color cardBg = Color(0xFF17181B);

  // Borders & Dividers
  static const Color divider = Color(0xFF23252A);
  static const Color cardBorder = Color(0xFF292B32);

  // Accents & Brand tones
  static const Color accent = Color(0xFFC79555); // refined luxury amber
  static const Color accentLight = Color(0xFFE2B77A);
  static const Color accentGlow = Color(0x33C79555);

  // Semantic
  static const Color danger = Color(0xFFF25A5A);
  static const Color success = Color(0xFF38C172);
  static const Color warning = Color(0xFFF5A623);

  // Typography
  static const Color textPrimary = Color(0xFFF4F5F7);
  static const Color textSecondary = Color(0xFFA2A5B0);
  static const Color textMuted = Color(0xFF6B6E79);

  static ThemeData get dark => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: bg,
    splashFactory: InkSparkle.splashFactory,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
    colorScheme: const ColorScheme.dark(
      primary: accent,
      secondary: accentLight,
      surface: surface,
      error: danger,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: bg,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
      ),
      iconTheme: IconThemeData(color: textPrimary),
    ),
    cardTheme: CardThemeData(
      color: cardBg,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: cardBorder, width: 0.8),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceElevated,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      hintStyle: const TextStyle(color: textMuted, fontSize: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: divider, width: 1.0),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: divider, width: 1.0),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: accent, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: danger, width: 1.0),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: Colors.black,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        textStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 15,
          letterSpacing: -0.2,
        ),
      ),
    ),
    dividerColor: divider,
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        color: textPrimary,
        fontSize: 28,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.8,
      ),
      headlineMedium: TextStyle(
        color: textPrimary,
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
      titleLarge: TextStyle(
        color: textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
      titleMedium: TextStyle(
        color: textPrimary,
        fontSize: 15,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
      ),
      bodyLarge: TextStyle(
        color: textPrimary,
        fontSize: 15,
        letterSpacing: -0.1,
        height: 1.45,
      ),
      bodyMedium: TextStyle(
        color: textSecondary,
        fontSize: 13,
        letterSpacing: -0.1,
        height: 1.4,
      ),
      labelSmall: TextStyle(
        color: textMuted,
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
      ),
    ),
  );
}
