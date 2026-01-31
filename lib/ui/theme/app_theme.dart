import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gravity/ui/theme/app_tokens.dart';

class AppTheme {
  static ThemeData light() {
    final base = ThemeData(brightness: Brightness.light, useMaterial3: true);
    final textTheme = GoogleFonts.manropeTextTheme(base.textTheme).copyWith(
      headlineSmall: const TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: AppTokens.textPrimary,
      ),
      titleMedium: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppTokens.textPrimary,
      ),
      bodyMedium: const TextStyle(
        fontSize: 15,
        color: AppTokens.textPrimary,
      ),
      bodySmall: const TextStyle(
        fontSize: 12,
        color: AppTokens.textMuted,
      ),
      labelSmall: const TextStyle(
        fontSize: 12,
        color: AppTokens.textMuted,
      ),
    );

    return base.copyWith(
      scaffoldBackgroundColor: AppTokens.bg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppTokens.accentBlue,
        brightness: Brightness.light,
      ).copyWith(
        primary: AppTokens.accentBlue,
        secondary: AppTokens.accentGreen,
        error: AppTokens.accentRed,
        surface: AppTokens.card,
      ),
      cardTheme: CardThemeData(
        color: AppTokens.card,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          side: const BorderSide(color: AppTokens.border),
        ),
      ),
      textTheme: textTheme,
      dividerTheme: const DividerThemeData(
        color: AppTokens.border,
        thickness: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppTokens.card,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppTokens.space16,
          vertical: AppTokens.space16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          borderSide: const BorderSide(color: AppTokens.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          borderSide: const BorderSide(color: AppTokens.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          borderSide: const BorderSide(color: AppTokens.accentBlue, width: 1.2),
        ),
        hintStyle: const TextStyle(color: AppTokens.textMuted),
      ),
    );
  }

  static ThemeData dark() {
    const darkBg = Color(0xFF0B0F14);
    const darkCard = Color(0xFF111827);
    const darkText = Color(0xFFE5E7EB);
    const darkMuted = Color(0xFF9CA3AF);
    const darkBorder = Color(0xFF1F2937);

    final base = ThemeData(brightness: Brightness.dark, useMaterial3: true);
    final textTheme = GoogleFonts.manropeTextTheme(base.textTheme).copyWith(
      headlineSmall: const TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: darkText,
      ),
      titleMedium: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: darkText,
      ),
      bodyMedium: const TextStyle(
        fontSize: 15,
        color: darkText,
      ),
      bodySmall: const TextStyle(
        fontSize: 12,
        color: darkMuted,
      ),
      labelSmall: const TextStyle(
        fontSize: 12,
        color: darkMuted,
      ),
    );

    return base.copyWith(
      scaffoldBackgroundColor: darkBg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppTokens.accentBlue,
        brightness: Brightness.dark,
      ).copyWith(
        primary: AppTokens.accentBlue,
        secondary: AppTokens.accentGreen,
        error: AppTokens.accentRed,
        surface: darkCard,
      ),
      cardTheme: CardThemeData(
        color: darkCard,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          side: const BorderSide(color: darkBorder),
        ),
      ),
      textTheme: textTheme,
      dividerTheme: const DividerThemeData(
        color: darkBorder,
        thickness: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkCard,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppTokens.space16,
          vertical: AppTokens.space16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          borderSide: const BorderSide(color: darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          borderSide: const BorderSide(color: darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          borderSide: const BorderSide(color: AppTokens.accentBlue, width: 1.2),
        ),
        hintStyle: const TextStyle(color: darkMuted),
      ),
    );
  }
}
