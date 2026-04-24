import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:catalogo_ja/ui/theme/app_tokens.dart';

class AppTheme {
  static ThemeData light() {
    final base = ThemeData(
      brightness: Brightness.light,
      useMaterial3: true,
      splashColor: Colors.transparent,
      highlightColor: Colors.black.withOpacity(0.02),
    );

    final textTheme = GoogleFonts.interTextTheme(base.textTheme).copyWith(
      headlineLarge: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: AppTokens.textPrimary, letterSpacing: -1.2),
      headlineSmall: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppTokens.textPrimary, letterSpacing: -0.8),
      titleLarge: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTokens.textPrimary),
      bodyLarge: const TextStyle(fontSize: 15, color: AppTokens.textPrimary, height: 1.5),
      bodyMedium: const TextStyle(fontSize: 13, color: AppTokens.textSecondary),
    );

    return base.copyWith(
      scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      cardColor: Colors.white,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppTokens.electricBlue,
        brightness: Brightness.light,
      ).copyWith(
        primary: AppTokens.electricBlue,
        secondary: AppTokens.softPurple,
        surface: Colors.white,
        error: AppTokens.accentRed,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          side: BorderSide(color: Colors.black.withOpacity(0.05), width: 1),
        ),
      ),
      textTheme: textTheme,
      dividerTheme: DividerThemeData(color: Colors.black.withOpacity(0.05), thickness: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.black.withOpacity(0.1))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.black.withOpacity(0.1))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppTokens.electricBlue, width: 2)),
        hintStyle: TextStyle(color: Colors.black.withOpacity(0.3), fontSize: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTokens.electricBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
      ),
    );
  }

  static ThemeData dark() {
    final base = ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      splashColor: Colors.transparent,
      highlightColor: Colors.white.withOpacity(0.02),
    );

    final textTheme = GoogleFonts.interTextTheme(base.textTheme).copyWith(
      headlineLarge: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: AppTokens.textPrimaryDark, letterSpacing: -1.2),
      headlineSmall: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppTokens.textPrimaryDark, letterSpacing: -0.8),
      titleLarge: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTokens.textPrimaryDark),
      bodyLarge: const TextStyle(fontSize: 15, color: AppTokens.textPrimaryDark, height: 1.5),
      bodyMedium: const TextStyle(fontSize: 13, color: AppTokens.textSecondaryDark),
    );

    return base.copyWith(
      scaffoldBackgroundColor: AppTokens.deepNavy,
      cardColor: AppTokens.surfaceDark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppTokens.electricBlue,
        brightness: Brightness.dark,
      ).copyWith(
        primary: AppTokens.electricBlue,
        secondary: AppTokens.vibrantCyan,
        surface: AppTokens.surfaceDark,
        onSurface: AppTokens.textPrimaryDark,
      ),
      cardTheme: CardThemeData(
        color: AppTokens.surfaceDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          side: const BorderSide(color: AppTokens.borderDark, width: 1),
        ),
      ),
      textTheme: textTheme,
      dividerTheme: const DividerThemeData(color: AppTokens.borderDark, thickness: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppTokens.surfaceDark,
        contentPadding: const EdgeInsets.all(20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppTokens.borderDark)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppTokens.borderDark)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppTokens.electricBlue, width: 2)),
        hintStyle: const TextStyle(color: AppTokens.textSecondaryDark, fontSize: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTokens.electricBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
      ),
    );
  }
}
