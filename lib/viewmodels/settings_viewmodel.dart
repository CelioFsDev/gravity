import 'package:catalogo_ja/core/config/public_catalog_config.dart';
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
    String? companyInstagramUrl,
    bool? isInitialSyncCompleted,
    bool? localOnlyMode,
    DateTime? lastFullBackupAt,
  }) async {
    final repository = ref.read(settingsRepositoryProvider);
    final current = state;

    String? cleanedBaseUrl = publicBaseUrl;
    if (cleanedBaseUrl != null) {
      cleanedBaseUrl = PublicCatalogConfig.normalizeBaseUrl(cleanedBaseUrl);
    }

    final updated = current.copyWith(
      storeName: storeName ?? current.storeName,
      whatsappNumber: whatsappNumber ?? current.whatsappNumber,
      publicBaseUrl: cleanedBaseUrl ?? current.publicBaseUrl,
      remoteImageBaseUrl: remoteImageBaseUrl ?? current.remoteImageBaseUrl,
      linktreeUrl: linktreeUrl ?? current.linktreeUrl,
      instagramUrl: instagramUrl ?? current.instagramUrl,
      companyInstagramUrl: companyInstagramUrl ?? current.companyInstagramUrl,
      isInitialSyncCompleted: isInitialSyncCompleted ?? current.isInitialSyncCompleted,
      localOnlyMode: localOnlyMode ?? current.localOnlyMode,
      lastFullBackupAt: lastFullBackupAt ?? current.lastFullBackupAt,
    );
    await repository.saveSettings(updated);
    state = updated;
  }
}

final settingsViewModelProvider =
    NotifierProvider<SettingsViewModel, AppSettings>(() {
      return SettingsViewModel();
    });
