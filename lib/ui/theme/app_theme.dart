import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gravity/ui/theme/app_tokens.dart';

class AppTheme {
  static ThemeData light() {
    final base = ThemeData(
      brightness: Brightness.light,
      useMaterial3: true,
      splashColor: Colors.transparent,
      highlightColor: Colors.black.withOpacity(0.02),
    );

    final textTheme = GoogleFonts.interTextTheme(base.textTheme).copyWith(
      headlineLarge: const TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        color: AppTokens.textPrimary,
        letterSpacing: -1,
      ),
      headlineSmall: const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: AppTokens.textPrimary,
        letterSpacing: -0.5,
      ),
      titleLarge: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: AppTokens.textPrimary,
      ),
      titleMedium: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppTokens.textPrimary,
      ),
      bodyLarge: const TextStyle(
        fontSize: 16,
        color: AppTokens.textPrimary,
        height: 1.5,
      ),
      bodyMedium: const TextStyle(fontSize: 14, color: AppTokens.textSecondary),
      bodySmall: const TextStyle(fontSize: 12, color: AppTokens.textMuted),
    );

    return base.copyWith(
      scaffoldBackgroundColor: AppTokens.bg,
      colorScheme:
          ColorScheme.fromSeed(
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
        shadowColor: Colors.black.withOpacity(0.05),
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          side: const BorderSide(color: AppTokens.border, width: 0.5),
        ),
      ),
      textTheme: textTheme,
      dividerTheme: const DividerThemeData(
        color: AppTokens.border,
        thickness: 0.8,
        space: 1,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppTokens.bg,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: AppTokens.textPrimary),
        titleTextStyle: textTheme.titleLarge,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppTokens.card,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppTokens.space16,
          vertical: 18, // Height ~52
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
          borderSide: const BorderSide(color: AppTokens.accentBlue, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          borderSide: const BorderSide(color: AppTokens.accentRed),
        ),
        hintStyle: const TextStyle(color: AppTokens.textMuted, fontSize: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTokens.accentBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTokens.textPrimary,
          side: const BorderSide(color: AppTokens.border),
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
      headlineLarge: const TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        color: AppTokens.textPrimaryDark,
        letterSpacing: -1,
      ),
      headlineSmall: const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: AppTokens.textPrimaryDark,
        letterSpacing: -0.5,
      ),
      titleLarge: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: AppTokens.textPrimaryDark,
      ),
      titleMedium: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppTokens.textPrimaryDark,
      ),
      bodyLarge: const TextStyle(
        fontSize: 16,
        color: AppTokens.textPrimaryDark,
        height: 1.5,
      ),
      bodyMedium: const TextStyle(
        fontSize: 14,
        color: AppTokens.textSecondaryDark,
      ),
      bodySmall: const TextStyle(fontSize: 12, color: AppTokens.textMutedDark),
    );

    return base.copyWith(
      scaffoldBackgroundColor: AppTokens.bgDark,
      colorScheme:
          ColorScheme.fromSeed(
            seedColor: AppTokens.accentBlue,
            brightness: Brightness.dark,
          ).copyWith(
            primary: AppTokens.accentBlue,
            secondary: AppTokens.accentGreen,
            error: AppTokens.accentRed,
            surface: AppTokens.cardDark,
            onSurface: AppTokens.textPrimaryDark,
          ),
      cardTheme: CardThemeData(
        color: AppTokens.cardDark,
        elevation: 0,
        shadowColor: Colors.black.withOpacity(0.5),
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          side: const BorderSide(color: AppTokens.borderDark, width: 0.5),
        ),
      ),
      textTheme: textTheme,
      dividerTheme: const DividerThemeData(
        color: AppTokens.borderDark,
        thickness: 0.8,
        space: 1,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppTokens.bgDark,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: AppTokens.textPrimaryDark),
        titleTextStyle: textTheme.titleLarge,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppTokens.cardDark,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppTokens.space16,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          borderSide: const BorderSide(color: AppTokens.borderDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          borderSide: const BorderSide(color: AppTokens.borderDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          borderSide: const BorderSide(color: AppTokens.accentBlue, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          borderSide: const BorderSide(color: AppTokens.accentRed),
        ),
        hintStyle: const TextStyle(
          color: AppTokens.textMutedDark,
          fontSize: 14,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTokens.accentBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTokens.textPrimaryDark,
          side: const BorderSide(color: AppTokens.borderDark),
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
