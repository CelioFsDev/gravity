import 'package:catalogo_ja/data/repositories/settings_repository.dart';
import 'package:catalogo_ja/models/settings.dart';
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
    String? remoteImageBaseUrl,
    String? linktreeUrl,
    String? instagramUrl,
  }) async {
    final repository = ref.read(settingsRepositoryProvider);
    final current = state;

    String? cleanedBaseUrl = publicBaseUrl;
    if (cleanedBaseUrl != null) {
      cleanedBaseUrl = cleanedBaseUrl.trim();
      if (cleanedBaseUrl.endsWith('/')) {
        cleanedBaseUrl = cleanedBaseUrl.substring(0, cleanedBaseUrl.length - 1);
      }
      // Ensure it starts with https://
      if (!cleanedBaseUrl.startsWith('http')) {
        cleanedBaseUrl = 'https://$cleanedBaseUrl';
      } else if (cleanedBaseUrl.startsWith('http://')) {
        cleanedBaseUrl = cleanedBaseUrl.replaceFirst('http://', 'https://');
      }
    }

    final updated = current.copyWith(
      storeName: storeName ?? current.storeName,
      whatsappNumber: whatsappNumber ?? current.whatsappNumber,
      publicBaseUrl: cleanedBaseUrl ?? current.publicBaseUrl,
      remoteImageBaseUrl: remoteImageBaseUrl ?? current.remoteImageBaseUrl,
      linktreeUrl: linktreeUrl ?? current.linktreeUrl,
      instagramUrl: instagramUrl ?? current.instagramUrl,
    );
    await repository.saveSettings(updated);
    state = updated;
  }
}

final settingsViewModelProvider =
    NotifierProvider<SettingsViewModel, AppSettings>(() {
      return SettingsViewModel();
    });
