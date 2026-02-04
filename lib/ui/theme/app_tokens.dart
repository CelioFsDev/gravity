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
  static const double space24 = 24;
  static const double space32 = 32;
  static const double space48 = 48;

  // Colors
  static const Color bg = Color(0xFFF6F7FB);
  static const Color card = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF1A1C1E);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textMuted = Color(0xFF9CA3AF);
  static const Color surface = Color(0xFFF9FAFB);
  static const Color surfaceSecondary = Color(0xFFF3F4F6);

  static const Color border = Color(0xFFE5E7EB);
  static const Color borderLight = Color(0xFFF1F2F4);

  static const Color accentBlue = Color(0xFF007AFF); // iOS Blue
  static const Color accentGreen = Color(0xFF34C759); // iOS Green
  static const Color accentRed = Color(0xFFFF3B30); // iOS Red
  static const Color accentOrange = Color(0xFFFF9500); // iOS Orange
  static const Color accentPurple = Color(0xFF5856D6); // iOS Purple

  // Dark Mode Colors
  static const Color bgDark = Color(0xFF0F1113);
  static const Color cardDark = Color(0xFF1A1C1E);
  static const Color surfaceDark = Color(0xFF151719);
  static const Color textPrimaryDark = Color(0xFFF1F2F4);
  static const Color textSecondaryDark = Color(0xFF9CA3AF);
  static const Color textMutedDark = Color(0xFF6B7280);
  static const Color borderDark = Color(0xFF2D2F31);

  // Shadows (Very subtle for premium feel)
  static const BoxShadow shadowSm = BoxShadow(
    color: Color(0x05000000),
    blurRadius: 8,
    offset: Offset(0, 2),
  );

  static const BoxShadow shadowMd = BoxShadow(
    color: Color(0x0A000000),
    blurRadius: 16,
    offset: Offset(0, 4),
  );

  static const BoxShadow shadowLg = BoxShadow(
    color: Color(0x10000000),
    blurRadius: 24,
    offset: Offset(0, 8),
  );
}
