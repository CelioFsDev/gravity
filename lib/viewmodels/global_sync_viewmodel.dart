import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:hive/hive.dart';
import 'package:catalogo_ja/models/category.dart';
import 'package:catalogo_ja/models/catalog.dart';
import 'package:catalogo_ja/models/product.dart';
import 'package:catalogo_ja/viewmodels/catalogs_viewmodel.dart';
import 'package:catalogo_ja/viewmodels/categories_viewmodel.dart';
import 'package:catalogo_ja/viewmodels/products_viewmodel.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import 'package:catalogo_ja/data/repositories/settings_repository.dart';
import 'package:catalogo_ja/data/repositories/products_repository.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter/foundation.dart' hide Category;
import 'package:catalogo_ja/viewmodels/tenant_viewmodel.dart';
import 'package:catalogo_ja/core/sync/providers/sync_providers.dart';
part 'global_sync_viewmodel.g.dart';

@riverpod
class GlobalSyncViewModel extends _$GlobalSyncViewModel {
  bool _isSyncingUp = false;

  @override
  void build() {
    ref.listen(currentTenantProvider, (previous, next) {
      final prevId = previous?.asData?.value?.id;
      final nextId = next.asData?.value?.id;
      if (prevId != null && nextId != null && prevId != nextId) {
        debugPrint('🏢 Troca de Tenant detectada ($prevId -> $nextId). Limpando fila de sincronização...');
        ref.read(syncQueueRepositoryProvider).clearAll();
      }
    });
  }

  /// Sincronização automática em segundo plano (apenas se estiver no Wi-Fi)
  Future<void> performSilentWifiSync() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();

      // No connectivity_plus v6+, o resultado é uma lista
      final isWifi = connectivityResult.contains(ConnectivityResult.wifi);

      if (!isWifi) {
        debugPrint('📡 Auto-sync ignorado: Não está no Wi-Fi.');
        return;
      }

      final settings = ref.read(settingsRepositoryProvider).getSettings();
      if (settings.localOnlyMode || settings.isInitialSyncCompleted) {
        debugPrint(
          'Auto-sync Wi-Fi ignorado para reduzir custo Firebase.',
        );
        return;
      }

      debugPrint('🚀 Iniciando sincronização silenciosa no Wi-Fi...');

      final products = await ref.read(productsRepositoryProvider).getProducts();
      await _downloadImagesInParallel(products, onProgress: null);

      debugPrint('✅ Auto-sync Wi-Fi concluído.');
    } catch (e) {
      debugPrint('❌ Erro no auto-sync Wi-Fi: $e');
    }
  }

  /// Sobe todas as Categorias, Coleções, Produtos e Catálogos para a Nuvem
  Future<void> syncUpEverything() async {
    if (_isSyncingUp) {
      debugPrint('⏳ Sincronização já em andamento. Ignorando nova chamada.');
      return;
    }
    _isSyncingUp = true;
    final progressNotifier = ref.read(syncProgressProvider.notifier);
    progressNotifier.startSync('Iniciando upload...');
    String? finalMessage;

    try {
      // 1. Sincroniza Categorias e Coleções
      final categoriesCount = await ref
          .read(categoriesViewModelProvider.notifier)
          .syncAllToCloud(force: true);

      // 2. Sincroniza Produtos e Fotos (o processo mais pesado)
      final productsCount = await ref
          .read(productsViewModelProvider.notifier)
          .syncAllToCloud(force: true, syncCategories: false);

      // 3. Sincroniza Catálogos (PDF e configs)
      final catalogsCount = await ref
          .read(catalogsViewModelProvider.notifier)
          .syncAllToCloud(force: true);

      final total = categoriesCount + productsCount + catalogsCount;
      finalMessage = 'Upload concluído: $total itens enviados.';
    } catch (e) {
      finalMessage = 'Erro no upload: $e';
      rethrow;
    } finally {
      progressNotifier.stopSync(message: finalMessage);
      _isSyncingUp = false;
    }
  }

  Future<void> syncDownEverything() async {
    final tenantAsync = ref.read(currentTenantProvider);
    final tenantId = tenantAsync.asData?.value?.id;
    if (tenantId == null || tenantId.isEmpty) {
      debugPrint('Nenhuma empresa selecionada.');
      return;
    }
    await pullTenantFromCloud(tenantId: tenantId, forceRefresh: true);
  }

  bool _isPullingFromCloud = false;

  Future<void> pullTenantFromCloud({
    required String tenantId,
    bool forceRefresh = true,
  }) async {
    if (_isPullingFromCloud) {
      debugPrint('Pull already in progress');
      return;
    }
    _isPullingFromCloud = true;

    final progressNotifier = ref.read(syncProgressProvider.notifier);
    progressNotifier.startSync('Iniciando sincronização da nuvem...');
    
    int productsCount = 0;
    int photosResolved = 0;
    int noPhoto = 0;
    int categoriesCount = 0;
    int catalogsCount = 0;
    int errorsCount = 0;

    try {
      final settings = ref.read(settingsRepositoryProvider).getSettings();
      if (settings.localOnlyMode) {
        throw Exception('Modo somente local ativo. Download da nuvem bloqueado.');
      }

      progressNotifier.updateProgress(0.1, 'Buscando categorias e coleções...');
      final categoriesQuery = FirebaseFirestore.instance
          .collection('tenants')
          .doc(tenantId)
          .collection('categories');
      final categoriesDocs = await _fetchCollectionInPages(query: categoriesQuery);
      final fetchedCategories = categoriesDocs.map((doc) => Category.fromMap(doc.data())).toList();
      categoriesCount = fetchedCategories.length;

      progressNotifier.updateProgress(0.2, 'Buscando catálogos...');
      final catalogsQuery = FirebaseFirestore.instance
          .collection('tenants')
          .doc(tenantId)
          .collection('catalogs');
      final catalogsDocs = await _fetchCollectionInPages(query: catalogsQuery);
      final fetchedCatalogs = catalogsDocs.map((doc) => Catalog.fromMap(doc.data())).toList();
      catalogsCount = fetchedCatalogs.length;

      progressNotifier.updateProgress(0.3, 'Buscando produtos...');
      final productsQuery = FirebaseFirestore.instance
          .collection('tenants')
          .doc(tenantId)
          .collection('products');
      final productsDocs = await _fetchCollectionInPages(query: productsQuery);
      
      progressNotifier.updateProgress(0.5, 'Processando produtos...');
      final fetchedProducts = <Product>[];
      for (var doc in productsDocs) {
        try {
          final pMap = doc.data();
          pMap['id'] = doc.id;
          final product = Product.fromMap(pMap);
          
          if (product.displayImageUrl == null || product.displayImageUrl!.isEmpty) {
            noPhoto++;
          } else {
            photosResolved++; // Treat as resolved since AppProductImageView handles gs://
          }
          fetchedProducts.add(product);
        } catch (e) {
          debugPrint('Erro ao parsear produto ${doc.id}: $e');
          errorsCount++;
        }
      }
      productsCount = fetchedProducts.length;

      progressNotifier.updateProgress(0.8, 'Limpando cache antigo e salvando novos dados...');
      // Safely replace Hive cache for this tenant
      await _safeReplaceHiveForTenant<Category>('categories', tenantId, fetchedCategories);
      await _safeReplaceHiveForTenant<Catalog>('catalogs', tenantId, fetchedCatalogs);
      await _safeReplaceHiveForTenant<Product>('products', tenantId, fetchedProducts);

      progressNotifier.updateProgress(0.9, 'Atualizando providers...');
      ref.invalidate(categoriesViewModelProvider);
      ref.invalidate(catalogsViewModelProvider);
      ref.invalidate(productsViewModelProvider);

      debugPrint('''
BAIXAR NUVEM FINALIZADO
Tenant: $tenantId
Produtos: $productsCount
Fotos resolvidas: $photosResolved
Produtos sem foto: $noPhoto
Categorias/Coleções: $categoriesCount
Catálogos: $catalogsCount
Erros gerais: $errorsCount
''');

      progressNotifier.stopSync(message: 'Sincronização concluída com sucesso!');
    } catch (e) {
      debugPrint('Erro no pullTenantFromCloud: $e');
      progressNotifier.stopSync(message: 'Erro ao baixar da nuvem: $e');
    } finally {
      _isPullingFromCloud = false;
    }
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _fetchCollectionInPages({
    required Query<Map<String, dynamic>> query,
    int pageSize = 300,
  }) async {
    final List<QueryDocumentSnapshot<Map<String, dynamic>>> allDocs = [];
    DocumentSnapshot? lastDoc;
    
    while (true) {
      Query<Map<String, dynamic>> pagedQuery = query.limit(pageSize);
      if (lastDoc != null) {
        pagedQuery = pagedQuery.startAfterDocument(lastDoc);
      }
      final snapshot = await pagedQuery.get();
      allDocs.addAll(snapshot.docs);
      if (snapshot.docs.length < pageSize) {
        break; // fetched all
      }
      lastDoc = snapshot.docs.last;
    }
    return allDocs;
  }



  Future<void> _safeReplaceHiveForTenant<T>(String boxName, String tenantId, List<T> newItems) async {
    final box = Hive.box<T>(boxName);
    
    // Find keys to delete (only for this tenant)
    final keysToDelete = [];
    for (var key in box.keys) {
      final item = box.get(key);
      dynamic tenantIdGetter;
      
      try {
        if (item != null) {
          final dynamic dynItem = item;
          tenantIdGetter = dynItem.tenantId;
        }
      } catch (_) {}

      // If item belongs to this tenant, or has no tenantId (legacy), delete it.
      if (tenantIdGetter == null || tenantIdGetter == tenantId) {
        keysToDelete.add(key);
      }
    }
    
    // Delete old
    await box.deleteAll(keysToDelete);
    
    // Insert new
    final Map<dynamic, T> newMap = {};
    for (var item in newItems) {
      try {
        if (item != null) {
           final dynamic dynItem = item;
           newMap[dynItem.id] = item;
        }
      } catch (_) {}
    }
    await box.putAll(newMap);
  }

  Future<void> _downloadImagesInParallel(
    List<Product> products, {
    required Function(double, String)? onProgress,
  }) async {
    final urlsToDownload = <String>{};

    for (final p in products) {
      for (final img in p.images) {
        if (img.uri.startsWith('http')) urlsToDownload.add(img.uri);
      }
      for (final photo in p.photos) {
        if (photo.path.startsWith('http')) urlsToDownload.add(photo.path);
      }
    }

    if (urlsToDownload.isEmpty) return;

    final total = urlsToDownload.length;
    int completed = 0;
    const int maxConcurrent = 5; // Download de 5 fotos por vez

    final List<String> urlList = urlsToDownload.toList();

    for (int i = 0; i < urlList.length; i += maxConcurrent) {
      final chunk = urlList.skip(i).take(maxConcurrent);

      await Future.wait(
        chunk.map((url) async {
          try {
            // Apenas baixa se não estiver em cache
            final fileInfo = await DefaultCacheManager().getFileFromCache(url);
            if (fileInfo == null) {
              await DefaultCacheManager()
                  .downloadFile(url)
                  .timeout(const Duration(seconds: 20));
            }
          } catch (e) {
            debugPrint('⚠️ Erro ao baixar imagem $url: $e');
          } finally {
            completed++;
            if (onProgress != null) {
              onProgress(
                completed / total,
                'Salvando foto offline ($completed de $total)...',
              );
            }
          }
        }),
      );
    }
  }
}
