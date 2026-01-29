import 'dart:async';

import 'package:gravity/data/repositories/contracts/settings_repository_contract.dart';
import 'package:gravity/models/app_settings.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'settings_repository.g.dart';

const _settingsKey = 'current_settings';

Stream<AppSettings> _settingsStream(Box<AppSettings> box) {
  return Stream<AppSettings>.multi((controller) {
    controller.add(box.get(_settingsKey) ?? AppSettings());
    final subscription = box.watch(key: _settingsKey).listen((_) {
      controller.add(box.get(_settingsKey) ?? AppSettings());
    });
    controller.onCancel = subscription.cancel;
  });
}

class HiveSettingsRepository implements SettingsRepositoryContract {
  final Box<AppSettings> _box;

  HiveSettingsRepository(this._box);

  Box<AppSettings> get box => _box;

  @override
  Future<AppSettings> getSettings() async {
    return _box.get(_settingsKey) ?? AppSettings();
  }

  @override
  Future<void> saveSettings(AppSettings settings) async {
    await _box.put(_settingsKey, settings);
  }

  @override
  Stream<AppSettings> watchSettings() => _settingsStream(_box);
}

@Riverpod(keepAlive: true)
SettingsRepositoryContract settingsRepository(SettingsRepositoryRef ref) {
  final settingsBox = Hive.box<AppSettings>('settings');
  return HiveSettingsRepository(settingsBox);
}
