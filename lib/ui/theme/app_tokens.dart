import 'package:flutter/material.dart';

class AppTokens {
  // Border Radius
  static const double radiusSm = 12;
  static const double radiusMd = 16;
  static const double radiusLg = 20;
  static const double radiusFull = 999;

  // Spacing
  static const double space4 = 4;
  static const double space8 = 8;
  static const double space12 = 12;
  static const double space16 = 16;
  static const double space20 = 20;
  static const double space24 = 24;
  static const double space32 = 32;
  static const double space48 = 48;

  // --- NEW GRADIENT SOFT PALETTE ---
  static const Color deepNavy = Color(0xFF060C1C); // Fundo Base Premium
  static const Color surfaceDark = Color(0xFF111827); // Cor de Cards em modo escuro
  
  static const Color electricBlue = Color(0xFF2E7DFF);
  static const Color vibrantCyan = Color(0xFF00E5FF);
  static const Color softPurple = Color(0xFF8A2BE2);
  static const Color vibrantPink = Color(0xFFFF007F);
  static const Color softOrange = Color(0xFFFF8C00);

  // Gradients
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

  // Borders & Dividers
  static const Color borderDark = Color(0xFF1F2937);
  static const Color borderLight = Color(0xFFE5E7EB);

  // Text
  static const Color textPrimaryDark = Color(0xFFF9FAFB);
  static const Color textSecondaryDark = Color(0xFF9CA3AF);

  // Shadows (Soft depth for dark mode)
  static const BoxShadow shadowDeep = BoxShadow(
    color: Color(0x40000000),
    blurRadius: 20,
    offset: Offset(0, 10),
  );

  static const BoxShadow shadowSm = BoxShadow(
    color: Color(0x14000000),
    blurRadius: 10,
    offset: Offset(0, 4),
  );

  // Legacy (Keeping for compatibility during refactor, will clean up later)
  static const Color bg = Color(0xFFF6F7FB);
  static const Color card = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF1A1C1E);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textMuted = Color(0xFF9CA3AF);
  static const Color surface = Color(0xFFF9FAFB);
  static const Color border = Color(0xFFE5E7EB);
  static const Color accentBlue = Color(0xFF007AFF);
  static const Color accentGreen = Color(0xFF16A34A);
  static const Color accentRed = Color(0xFFDC2626);
  static const Color accentOrange = Color(0xFFF97316);
  static const Color accentPurple = Color(0xFF7C3AED);
  static const Color bgDark = deepNavy;
  static const Color cardDark = surfaceDark;
}
