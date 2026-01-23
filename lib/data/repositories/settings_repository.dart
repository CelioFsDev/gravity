import 'package:gravity/models/app_settings.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'settings_repository.g.dart';

abstract class SettingsRepository {
  Future<AppSettings> getSettings();
  Future<void> saveSettings(AppSettings settings);
}

class HiveSettingsRepository implements SettingsRepository {
  final Box<AppSettings> _box;
  static const String _key = 'current_settings';

  HiveSettingsRepository(this._box);

  @override
  Future<AppSettings> getSettings() async {
    return _box.get(_key) ?? AppSettings();
  }

  @override
  Future<void> saveSettings(AppSettings settings) async {
    await _box.put(_key, settings);
  }
}

@Riverpod(keepAlive: true)
SettingsRepository settingsRepository(SettingsRepositoryRef ref) {
  return HiveSettingsRepository(Hive.box<AppSettings>('settings'));
}
