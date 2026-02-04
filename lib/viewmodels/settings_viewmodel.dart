import 'package:gravity/data/repositories/settings_repository.dart';
import 'package:gravity/models/settings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SettingsViewModel extends Notifier<AppSettings> {
  @override
  AppSettings build() {
    final repository = ref.watch(settingsRepositoryProvider);
    return repository.getSettings();
  }

  Future<void> updateSettings({
    String? storeName,
    String? whatsappNumber,
    String? publicBaseUrl,
  }) async {
    final repository = ref.read(settingsRepositoryProvider);
    final current = state;
    final updated = current.copyWith(
      storeName: storeName ?? current.storeName,
      whatsappNumber: whatsappNumber ?? current.whatsappNumber,
      publicBaseUrl: publicBaseUrl ?? current.publicBaseUrl,
    );
    await repository.saveSettings(updated);
    state = updated;
  }
}

final settingsViewModelProvider =
    NotifierProvider<SettingsViewModel, AppSettings>(() {
      return SettingsViewModel();
    });
