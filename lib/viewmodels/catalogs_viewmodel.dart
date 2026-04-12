import 'dart:async';
import 'package:catalogo_ja/models/catalog.dart';
import 'package:catalogo_ja/data/repositories/catalogs_repository.dart';
import 'package:catalogo_ja/data/repositories/firestore_catalogs_repository.dart';
import 'package:catalogo_ja/viewmodels/products_viewmodel.dart';
import 'package:catalogo_ja/viewmodels/tenant_viewmodel.dart';
import 'package:catalogo_ja/viewmodels/auth_viewmodel.dart';
import 'package:catalogo_ja/core/error/app_failure.dart';
import 'package:catalogo_ja/core/services/saas_photo_storage_service.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:catalogo_ja/data/repositories/tenant_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:catalogo_ja/data/repositories/settings_repository.dart';

part 'catalogs_viewmodel.g.dart';

@riverpod
class CatalogsViewModel extends _$CatalogsViewModel {
  @override
  FutureOr<List<Catalog>> build() async {
    try {
      final authUser = ref.watch(authViewModelProvider).valueOrNull;
      if (authUser != null) {
        await ref.watch(currentTenantProvider.future);
      }
      
      final repository = ref.watch(syncCatalogsRepositoryProvider);
      return await repository.getCatalogs();
    } catch (e) {
      throw e.toAppFailure(action: 'build', entity: 'Catalogs');
    }
  }

  Future<void> deleteCatalog(String id) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      try {
        final repository = ref.read(syncCatalogsRepositoryProvider);
        await repository.deleteCatalog(id);
        ref.invalidateSelf();
        return state.value ?? [];
      } catch (e) {
        throw e.toAppFailure(action: 'deleteCatalog', entity: 'Catalog');
      }
    });
  }

  /// Sincroniza todos os catálogos locais para a nuvem
  Future<int> syncAllToCloud() async {
    final progressNotifier = ref.read(syncProgressProvider.notifier);
    try {
      progressNotifier.startSync('Iniciando sincronização de catálogos...');
      
      final localRepo = ref.read(catalogsRepositoryProvider) as HiveCatalogsRepository;
      final localCatalogs = await localRepo.getCatalogs();
      
      if (localCatalogs.isEmpty) {
        progressNotifier.stopSync();
        return 0;
      }

      final tenant = await ref.read(currentTenantProvider.future);
      String? tenantId = tenant?.id;
      if (tenantId == null) {
        final email = ref.read(authViewModelProvider).valueOrNull?.email;
        if (email != null) {
          tenantId = await ref.read(tenantRepositoryProvider).getCachedTenantId(email);
        }
      }

      if (tenantId == null) {
        progressNotifier.stopSync();
        throw Exception('Empresa não identificada.');
      }

      final storageService = ref.read(saasPhotoStorageProvider);
      final firestoreRepo = FirestoreCatalogsRepository(localRepo, storageService, tenantId);
      var syncedCount = 0;
      final total = localCatalogs.length;

      for (var i = 0; i < total; i++) {
        final cat = localCatalogs[i];
        try {
          progressNotifier.updateProgress(
            (i + 1) / total,
            'Sincronizando: ${i + 1}/$total - ${cat.name}',
          );
          await firestoreRepo.addCatalog(cat);
          syncedCount++;
        } catch (e) {
          print('❌ Erro ao sincronizar catálogo ${cat.name}: $e');
        }
      }

      progressNotifier.stopSync();
      ref.invalidateSelf();
      return syncedCount;
    } catch (e) {
      progressNotifier.stopSync();
      print('Erro ao sincronizar catálogos: $e');
      rethrow;
    }
  }

  /// Baixa todos os catálogos da nuvem para o celular
  Future<int> syncFromCloud() async {
    final progressNotifier = ref.read(syncProgressProvider.notifier);
    try {
      progressNotifier.startSync('Buscando catálogos na nuvem...');
      
      final tenant = await ref.read(currentTenantProvider.future);
      String? tenantId = tenant?.id;
      if (tenantId == null) {
        final email = ref.read(authViewModelProvider).valueOrNull?.email;
        if (email != null) {
          tenantId = await ref.read(tenantRepositoryProvider).getCachedTenantId(email);
        }
      }

      if (tenantId == null) {
        progressNotifier.stopSync();
        throw Exception('Empresa não identificada.');
      }

      final localRepo = ref.read(catalogsRepositoryProvider) as HiveCatalogsRepository;
      final storageService = ref.read(saasPhotoStorageProvider);
      final firestoreRepo = FirestoreCatalogsRepository(localRepo, storageService, tenantId);

      final currentLocalCatalogs = await localRepo.getCatalogs();
      
      // 🔑 Trava de Offline-First
      if (currentLocalCatalogs.isEmpty) {
        final settings = ref.read(settingsRepositoryProvider).getSettings();
        if (!settings.isInitialSyncCompleted) {
          progressNotifier.stopSync();
          return 0; // Abort download
        }
      }

      // 🔑 Usa fetchFromCloudOnly() para evitar double-merge com cache
      DateTime? mostRecentLocal;
      if (currentLocalCatalogs.isNotEmpty) {
        mostRecentLocal = currentLocalCatalogs
            .map((c) => c.updatedAt)
            .reduce((a, b) => a.isAfter(b) ? a : b);
      }
      final cloudCatalogs = await firestoreRepo.fetchFromCloudOnly(
        since: mostRecentLocal,
      );
      if (cloudCatalogs.isEmpty) {
        progressNotifier.stopSync();
        return 0;
      }

      var downloadedCount = 0;
      final localCatalogs = await localRepo.getCatalogs();
      final localMap = {for (var c in localCatalogs) c.id: c};
      final total = cloudCatalogs.length;

      for (var i = 0; i < total; i++) {
        final cat = cloudCatalogs[i];
        final progress = (i + 1) / total;

        // 🚀 Verificação de Diferença (Sincronização Incremental/Inteligente)
        final localCat = localMap[cat.id];
        if (localCat != null && !cat.updatedAt.isAfter(localCat.updatedAt)) {
          // Já estamos atualizados localmente, ignore
          continue; 
        }

        try {
          progressNotifier.updateProgress(
            progress,
            'Baixando novidades: ${i + 1}/$total - ${cat.name}',
          );
          await localRepo.addCatalog(cat);
          downloadedCount++;
        } catch (_) {}
      }

      final box = await Hive.openBox('sync_meta');
      await box.put('last_sync_catalogs', DateTime.now().millisecondsSinceEpoch);

      progressNotifier.stopSync();
      ref.invalidateSelf();
      return downloadedCount;
    } catch (e) {
      progressNotifier.stopSync();
      print('Erro ao baixar catálogos: $e');
      rethrow;
    }
  }
}
