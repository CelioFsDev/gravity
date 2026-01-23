import 'package:gravity/data/repositories/settings_repository.dart';
import 'package:gravity/models/app_settings.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'settings_viewmodel.g.dart';

@riverpod
class SettingsViewModel extends _$SettingsViewModel {
  @override
  FutureOr<AppSettings> build() async {
    final repository = ref.watch(settingsRepositoryProvider);
    return await repository.getSettings();
  }

  Future<void> updateSettings({
    String? storeName,
    String? defaultWhatsapp,
    String? defaultMessageTemplate,
    String? publicBaseUrl,
  }) async {
    final repository = ref.read(settingsRepositoryProvider);
    final current = state.value ?? AppSettings();
    
    final updated = current.copyWith(
      storeName: storeName,
      defaultWhatsapp: defaultWhatsapp,
      defaultMessageTemplate: defaultMessageTemplate,
      publicBaseUrl: publicBaseUrl,
    );

    await repository.saveSettings(updated);
    state = AsyncData(updated);
  }
}
