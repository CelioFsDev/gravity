import 'package:flutter/material.dart';

/// Design tokens for Catálogo Já — premium SaaS identity
/// Paleta: Deep Navy + Electric Blue + Vibrant Cyan
class AppTokens {
  AppTokens._();

  // ─── Border Radius ───────────────────────────────────────────────────────
  static const double radiusXs = 8;
  static const double radiusSm = 12;
  static const double radiusMd = 16;
  static const double radiusLg = 20;
  static const double radiusXl = 28;
  static const double radiusFull = 999;

  // ─── Spacing ─────────────────────────────────────────────────────────────
  static const double space4 = 4;
  static const double space8 = 8;
  static const double space12 = 12;
  static const double space16 = 16;
  static const double space20 = 20;
  static const double space24 = 24;
  static const double space32 = 32;
  static const double space48 = 48;
  static const double space64 = 64;

  // ─── Brand Colors — Dark Palette ─────────────────────────────────────────
  static const Color deepNavy = Color(0xFF060C1C);
  static const Color surfaceDark = Color(0xFF0D1527);
  static const Color cardDark = Color(0xFF111827);
  static const Color elevatedDark = Color(0xFF1A2235);

  // ─── Brand Colors — Accent ───────────────────────────────────────────────
  static const Color electricBlue = Color(0xFF2E7DFF);
  static const Color vibrantCyan = Color(0xFF00D8F5);
  static const Color softPurple = Color(0xFF7C3AED);
  static const Color vibrantPink = Color(0xFFE91E8C);
  static const Color softOrange = Color(0xFFFF6B35);
  static const Color accentGold = Color(0xFFFBBC04);

  // ─── Semantic Colors ─────────────────────────────────────────────────────
  static const Color accentBlue = Color(0xFF2E7DFF);
  static const Color accentGreen = Color(0xFF10B981);
  static const Color accentRed = Color(0xFFEF4444);
  static const Color accentOrange = Color(0xFFF97316);
  static const Color accentPurple = Color(0xFF7C3AED);

  // ─── Text — Dark mode ────────────────────────────────────────────────────
  static const Color textPrimaryDark = Color(0xFFF1F5F9);
  static const Color textSecondaryDark = Color(0xFF94A3B8);
  static const Color textMutedDark = Color(0xFF475569);

  // ─── Text — Light mode ───────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF475569);
  static const Color textMuted = Color(0xFF94A3B8);

  // ─── Borders ─────────────────────────────────────────────────────────────
  static const Color borderDark = Color(0xFF1E293B);
  static const Color borderLight = Color(0xFFE2E8F0);
  static const Color borderLight2 = Color(0xFFF1F5F9);

  // ─── Backgrounds — Light mode ────────────────────────────────────────────
  static const Color bg = Color(0xFFF8FAFC);
  static const Color bgElevated = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFF1F5F9);
  static const Color card = Color(0xFFFFFFFF);

  // ─── Legacy aliases ──────────────────────────────────────────────────────
  static const Color bgDark = deepNavy;
  static const Color cardDark2 = cardDark;
  static const Color border = borderLight;

  // ─── Gradients ───────────────────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [electricBlue, vibrantCyan],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [softPurple, vibrantPink],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient warmGradient = LinearGradient(
    colors: [vibrantPink, softOrange],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient goldGradient = LinearGradient(
    colors: [Color(0xFFFBBC04), Color(0xFFFF8C00)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkBg = LinearGradient(
    colors: [deepNavy, Color(0xFF0A1628), deepNavy],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient navyGlowGradient = LinearGradient(
    colors: [deepNavy, electricBlue.withOpacity(0.12), deepNavy],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ─── Shadows ─────────────────────────────────────────────────────────────
  static const BoxShadow shadowDeep = BoxShadow(
    color: Color(0x50000000),
    blurRadius: 24,
    offset: Offset(0, 12),
  );

  static const BoxShadow shadowMd = BoxShadow(
    color: Color(0x20000000),
    blurRadius: 16,
    offset: Offset(0, 6),
  );

  static const BoxShadow shadowSm = BoxShadow(
    color: Color(0x14000000),
    blurRadius: 8,
    offset: Offset(0, 3),
  );

  static BoxShadow glowBlue = BoxShadow(
    color: electricBlue.withOpacity(0.3),
    blurRadius: 24,
    offset: const Offset(0, 8),
  );

  static BoxShadow glowCyan = BoxShadow(
    color: vibrantCyan.withOpacity(0.25),
    blurRadius: 20,
    offset: const Offset(0, 6),
  );

  // ─── Icon color by context ───────────────────────────────────────────────
  static Color iconOnDark = Colors.white.withOpacity(0.85);
  static Color iconOnLight = textSecondary;
}
