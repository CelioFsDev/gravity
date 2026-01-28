import 'dart:async';

import 'package:gravity/models/app_settings.dart';

abstract class SettingsRepositoryContract {
  Future<AppSettings> getSettings();
  Future<void> saveSettings(AppSettings settings);

  Stream<AppSettings> watchSettings();
}
