import 'package:catalogo_ja/models/settings.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SettingsRepository {
  final Box<AppSettings> _box;

  SettingsRepository(this._box);

  AppSettings getSettings() {
    return _box.get('app_settings') ?? AppSettings.defaultSettings();
  }

  Future<void> saveSettings(AppSettings settings) async {
    await _box.put(
      'app_settings',
      settings.copyWith(updatedAt: DateTime.now()),
    );
  }

  Stream<AppSettings> watchSettings() {
    return _box.watch(key: 'app_settings').map((event) {
      return event.value as AppSettings? ?? AppSettings.defaultSettings();
    });
  }
}

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  final box = Hive.box<AppSettings>('settings');
  return SettingsRepository(box);
});
