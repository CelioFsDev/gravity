import 'package:flutter/material.dart';

/// Centralized asset paths for Catálogo Já
/// All paths verified against assets in pubspec.yaml
class AppAssets {
  AppAssets._();

  // ─── Branding / Logo ──────────────────────────────────────────────────────
  static const String logoMaster =
      'assets/branding/logo/catalogoja_logo_master_2048x2048.png';
  static const String logoTransparent =
      'assets/branding/logo/catalogoja_logo_transparent_2048x2048.png';

  // ─── App Icons ────────────────────────────────────────────────────────────
  static const String appIconClean =
      'assets/branding/icons/catalogoja_app_icon_clean.png';
  static const String appIconGlass =
      'assets/branding/icons/catalogoja_icons_glass_1024x1024.png';
  static const String appIconForeground =
      'assets/branding/icons/catalogoja_icon_foreground.png';
  static const String wordmark =
      'assets/branding/icons/catalogoja_wordmark_clean.png';

  // ─── Splash ───────────────────────────────────────────────────────────────
  /// Premium AI-generated splash background
  static const String splashPremium =
      'assets/branding/splash/splash_background_premium_1777239536070.png';

  /// Original fallback splash
  static const String splashClean =
      'assets/branding/splash/catalogoja_splash_clean.png';

  static const String splashIos =
      'assets/branding/splash/catalogoja_splash_ios_1080x1920.png';

  // ─── Login ────────────────────────────────────────────────────────────────
  /// Premium AI-generated login background
  static const String loginBgPremium =
      'assets/branding/login/catalogoja_login_premium_1080x1920.png';

  // ─── Banners ─────────────────────────────────────────────────────────────
  /// AI-generated onboarding hero illustration (in splash folder)
  static const String onboardingHero =
      'assets/branding/splash/onboarding_visual_premium_1777239570483.png';

  /// AI-generated welcome banner (in splash folder)
  static const String welcomeHero =
      'assets/branding/splash/welcome_hero_banner_1777239583424.png';

  static const String dashboardBanner =
      'assets/branding/banners/catalogoja_banner_dashboard_1920x480.svg';

  // ─── Navigation icons (legacy, assets/icon/) ─────────────────────────────
  static const String _iconPath = 'assets/icon';
  static const String navDashboard = '$_iconPath/dashboard.png';
  static const String navProducts = '$_iconPath/products.png';
  static const String navCollections = '$_iconPath/collections.png';
  static const String navCategories = '$_iconPath/categories.png';
  static const String navSettings = '$_iconPath/settings_profile.png';
  static const String navLoginBg = '$_iconPath/login_bg.png';

  // ─── Images ───────────────────────────────────────────────────────────────
  static const String googleLogo = 'assets/images/google_logo.png';
}

/// Legacy class mantida para compatibilidade com código existente
class AppIcons {
  static const String _path = 'assets/icon';

  static Widget _asset(
    String name,
    IconData fallback, {
    double size = 24,
  }) {
    final cacheSize = (size * 3).round();
    return Image.asset(
      '$_path/$name.png',
      width: size,
      height: size,
      cacheWidth: cacheSize,
      cacheHeight: cacheSize,
      filterQuality: FilterQuality.high,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => Icon(fallback, size: size),
    );
  }

  static Widget dashboard({double size = 24}) =>
      _asset('dashboard', Icons.dashboard_outlined, size: size);

  static Widget products({double size = 24}) =>
      _asset('products', Icons.inventory_2_outlined, size: size);

  static Widget collections({double size = 24}) =>
      _asset('collections', Icons.collections_bookmark_outlined, size: size);

  static Widget categories({double size = 24}) =>
      _asset('categories', Icons.category_outlined, size: size);

  static Widget settings({double size = 24}) =>
      _asset('settings_profile', Icons.settings_outlined, size: size);

  static Widget profile({double size = 24}) =>
      _asset('settings_profile', Icons.person_outline, size: size);

  static const String loginBackground = AppAssets.navLoginBg;
}
