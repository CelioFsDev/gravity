import 'dart:async';
import 'package:catalogo_ja/data/repositories/catalogs_repository.dart';
import 'package:catalogo_ja/data/repositories/firestore_catalogs_repository.dart';
import 'package:catalogo_ja/models/catalog.dart';
import 'package:catalogo_ja/viewmodels/tenant_viewmodel.dart';
import 'package:catalogo_ja/viewmodels/auth_viewmodel.dart';
import 'package:catalogo_ja/viewmodels/products_viewmodel.dart'; // Import for SyncProgress
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:catalogo_ja/core/error/app_failure.dart';
import 'package:catalogo_ja/core/services/saas_photo_storage_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'catalogs_viewmodel.g.dart';

@riverpod
class CatalogsViewModel extends _$CatalogsViewModel {
  @override
  FutureOr<List<Catalog>> build() async {
    try {
      final repository = ref.watch(catalogsRepositoryProvider);
      return await repository.getCatalogs();
    } catch (e) {
      throw e.toAppFailure(action: 'build', entity: 'Catalogs');
    }
  }

  Future<void> deleteCatalog(String id) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      try {
        final repository = ref.read(catalogsRepositoryProvider);
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
        final authUser = ref.read(authViewModelProvider).value;
        if (authUser?.email != null) {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(authUser!.email!.toLowerCase().trim())
              .get();
          tenantId = userDoc.data()?['tenantId'] as String?;
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
        final authUser = ref.read(authViewModelProvider).value;
        if (authUser?.email != null) {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(authUser!.email!.toLowerCase().trim())
              .get();
          tenantId = userDoc.data()?['tenantId'] as String?;
        }
      }

      if (tenantId == null) {
        progressNotifier.stopSync();
        throw Exception('Empresa não identificada.');
      }

      final localRepo = ref.read(catalogsRepositoryProvider) as HiveCatalogsRepository;
      final storageService = ref.read(saasPhotoStorageProvider);
      final firestoreRepo = FirestoreCatalogsRepository(localRepo, storageService, tenantId);

      final cloudCatalogs = await firestoreRepo.getCatalogs();
      if (cloudCatalogs.isEmpty) {
        progressNotifier.stopSync();
        return 0;
      }

      var downloadedCount = 0;
      final total = cloudCatalogs.length;

      for (var i = 0; i < total; i++) {
        final cat = cloudCatalogs[i];
        try {
          progressNotifier.updateProgress(
            (i + 1) / total,
            'Baixando: ${i + 1}/$total - ${cat.name}',
          );
          await localRepo.addCatalog(cat);
          downloadedCount++;
        } catch (_) {}
      }

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
