import 'package:flutter/material.dart';

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
      errorBuilder: (_, _, _) => Icon(fallback, size: size),
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

  static const String loginBackground = 'assets/icon/login_bg.png';
}
