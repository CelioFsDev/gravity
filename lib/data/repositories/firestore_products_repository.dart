import 'dart:async';
import 'dart:convert';

import 'package:catalogo_ja/core/sync/models/sync_queue_item.dart';
import 'package:catalogo_ja/core/sync/repositories/sync_queue_repository.dart';
import 'package:catalogo_ja/core/services/saas_photo_storage_service.dart';
import 'package:catalogo_ja/data/repositories/contracts/products_repository_contract.dart';
import 'package:catalogo_ja/data/repositories/products_repository.dart';
import 'package:catalogo_ja/models/product.dart';
import 'package:catalogo_ja/models/product_image.dart';
import 'package:catalogo_ja/viewmodels/tenant_viewmodel.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image_picker/image_picker.dart';

class FirestoreProductsRepository implements ProductsRepositoryContract {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final HiveProductsRepository _localRepo;
  final SaaSPhotoStorageService _storageService;
  final String _tenantId;
  final SyncQueueRepository _syncQueue;
  final Set<String> _autoSyncInFlight = <String>{};

  FirestoreProductsRepository(
    this._localRepo,
    this._storageService,
    this._tenantId,
    this._syncQueue,
  );

  // 🔑 Cache em memória: evita re-leituras do Firestore dentro da mesma sessão.
  // Cada getProducts() sem cache = 1 leitura full da collection (cara!).
  List<Product>? _memoryCache;
  DateTime? _cacheTimestamp;
  static const _cacheDuration = Duration(minutes: 5);

  bool get _isCacheValid =>
      _memoryCache != null &&
      _cacheTimestamp != null &&
      DateTime.now().difference(_cacheTimestamp!) < _cacheDuration;

  /// Invalida o cache. Chame após qualquer escrita local ou nuvem.
  void invalidateCache() {
    _memoryCache = null;
    _cacheTimestamp = null;
  }

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('tenants').doc(_tenantId).collection('products');

  bool _isCloudResolvableImageUri(String uri) {
    final trimmed = uri.trim();
    return trimmed.startsWith('http://') ||
        trimmed.startsWith('https://') ||
        trimmed.startsWith('gs://') ||
        trimmed.startsWith('tenants/') ||
        trimmed.startsWith('public_catalogs/');
  }

  @override
  Future<Product?> getProduct(String id) async =>
      await _localRepo.getProduct(id);

  @override
  Future<List<Product>> getProducts() async {
    // 🌟 Cache hit: retorna dados em memória sem tocar o Firestore
    if (_isCacheValid) return List.from(_memoryCache!);

    try {
      final localProducts = await _localRepo.getProducts();

      // Busca incremental: só documentos mais novos que o mais recente local.
      // Se não há nada local, busca tudo (primeira vez).
      DateTime? mostRecentLocal;
      if (localProducts.isNotEmpty) {
        mostRecentLocal = localProducts
            .map((p) => p.updatedAt)
            .reduce((a, b) => a.isAfter(b) ? a : b);
      }

      Query<Map<String, dynamic>> query = _collection;

      if (mostRecentLocal != null) {
        // 10 segundos de folga para clock skew entre dispositivos
        final since = mostRecentLocal.subtract(const Duration(seconds: 10));
        query = query.where(
          'updatedAt',
          isGreaterThan: since.toIso8601String(),
        );
      }

      final snapshot = await query.get().timeout(const Duration(seconds: 10));

      final newCloudProducts = snapshot.docs
          .map((doc) => Product.fromMap(doc.data()))
          .toList();

      // Merge: local como base, novidades da nuvem têm prioridade
      final merged = <String, Product>{for (final p in localProducts) p.id: p};

      for (final cloudProduct in newCloudProducts) {
        final localProduct = merged[cloudProduct.id];

        if (localProduct == null) {
          final pWithSync = cloudProduct.copyWith(
            syncStatus: SyncStatus.synced,
          );
          merged[cloudProduct.id] = pWithSync;
          await _localRepo.addProduct(pWithSync);
        } else if (cloudProduct.updatedAt.isAfter(localProduct.updatedAt) &&
            localProduct.syncStatus != SyncStatus.pendingUpdate) {
          // 🛡️ PRESERVAÇÃO DE CAMINHOS LOCAIS
          // Se o produto local já tem caminhos físicos (localPath), mantemos eles
          // para evitar que o app volte a mostrar o "carregando" da nuvem.
          final preservedImages = cloudProduct.images.map((cloudImg) {
            final localImg = localProduct.images.firstWhere(
              (l) => l.id == cloudImg.id || l.uri == cloudImg.uri,
              orElse: () => cloudImg,
            );
            if (localImg.sourceType == ProductImageSource.localPath) {
              return cloudImg.copyWith(
                sourceType: ProductImageSource.localPath,
                uri: localImg.uri,
              );
            }
            return cloudImg;
          }).toList();

          final pWithSync = cloudProduct.copyWith(
            images: preservedImages,
            syncStatus: SyncStatus.synced,
          );

          merged[cloudProduct.id] = pWithSync;
          await _localRepo.addProduct(pWithSync);
        }
      }

      final result = merged.values.toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

      // Guarda em cache
      _memoryCache = result;
      _cacheTimestamp = DateTime.now();
      return result;
    } catch (e) {
      debugPrint('Erro ao buscar produtos da nuvem (usando local): $e');
      return await _localRepo.getProducts();
    }
  }

  /// Busca SOMENTE na nuvem, sem merge local.
  /// Usado pelo syncFromCloud() para evitar trabalho duplo.
  Future<List<Product>> fetchFromCloudOnly({DateTime? since}) async {
    Query<Map<String, dynamic>> query = _collection;
    if (since != null) {
      query = query.where(
        'updatedAt',
        isGreaterThan: since
            .subtract(const Duration(seconds: 10))
            .toIso8601String(),
      );
    }
    final snapshot = await query.get().timeout(const Duration(seconds: 15));
    return snapshot.docs.map((doc) => Product.fromMap(doc.data())).toList();
  }

  @override
  Future<void> addProduct(
    Product product, {
    Function(double, String)? onProgress,
  }) async {
    final productToSave = product.copyWith(
      syncStatus: SyncStatus.pendingUpdate,
    );
    // 🏠 Local-First: Salva no Hive instantaneamente
    await _localRepo.addProduct(productToSave);
    invalidateCache();
    _scheduleAutoSync(productToSave);
  }

  @override
  Future<void> updateProduct(
    Product product, {
    Function(double, String)? onProgress,
  }) async {
    final oldProduct = await _localRepo.getProduct(product.id);

    // Evitar salvar e dar update falso sem mudanças reais.
    if (oldProduct != null && !oldProduct.hasMeaningfulChanges(product)) {
      debugPrint('Skipping updateProduct, no meaningful changes detected.');
      return;
    }

    final productToSave = product.copyWith(
      syncStatus: SyncStatus.pendingUpdate,
      updatedAt: DateTime.now(),
    );

    await _localRepo.updateProduct(productToSave);
    invalidateCache();
    _scheduleAutoSync(productToSave);
  }

  @override
  Future<void> saveImportedProduct(
    Product product, {
    required bool shouldSync,
  }) async {
    final productToSave = product.copyWith(
      tenantId: _tenantId,
      syncStatus: shouldSync ? SyncStatus.pendingUpdate : SyncStatus.synced,
    );

    await _localRepo.updateProduct(productToSave);
    invalidateCache();
  }

  void _scheduleAutoSync(Product product) {
    if (_autoSyncInFlight.contains(product.id)) return;
    _autoSyncInFlight.add(product.id);

    unawaited(
      Future<void>(() async {
        try {
          await syncProductToCloud(product);
        } catch (e) {
          debugPrint('Erro no upload automatico do produto ${product.id}: $e');
          await _syncQueue.enqueue(
            SyncQueueItem(
              tenantId: _tenantId,
              entityType: 'product',
              entityId: product.id,
              operation: SyncOperation.update,
              payload: product.toMap(),
            ),
          );
        } finally {
          _autoSyncInFlight.remove(product.id);
        }
      }),
    );
  }

  @override
  Future<void> syncProductToCloud(
    Product product, {
    Function(double, String)? onProgress,
  }) async {
    var imagesToSync = List<ProductImage>.from(product.images);

    if (imagesToSync.isEmpty && product.photos.isNotEmpty) {
      imagesToSync = product.photos
          .map((photo) => photo.toProductImage())
          .toList();
    }

    final totalImages = imagesToSync.length;
    final updatedImages = <ProductImage>[];

    for (var i = 0; i < totalImages; i++) {
      final image = imagesToSync[i];
      if (onProgress != null) {
        onProgress(
          i / totalImages,
          'Enviando foto ${i + 1} de $totalImages...',
        );
      }

      final isLocal =
          image.uri.startsWith('data:') ||
          image.uri.startsWith('blob:') ||
          (!_isCloudResolvableImageUri(image.uri) &&
              image.sourceType != ProductImageSource.networkUrl &&
              image.sourceType != ProductImageSource.storage);

      if (!isLocal) {
        // Corrige inconsistências de importação onde a URI é http mas o tipo ficou como local
        if (image.sourceType != ProductImageSource.networkUrl &&
            _isCloudResolvableImageUri(image.uri)) {
          updatedImages.add(
            image.copyWith(sourceType: ProductImageSource.networkUrl),
          );
        } else {
          updatedImages.add(image);
        }
        continue;
      }

      try {
        Uint8List? webBytes;
        if (kIsWeb) {
          try {
            if (image.uri.startsWith('data:')) {
              final commaIndex = image.uri.indexOf(',');
              if (commaIndex != -1) {
                webBytes = base64Decode(image.uri.substring(commaIndex + 1));
              }
            } else if (image.uri.startsWith('blob:')) {
              final xFile = XFile(image.uri);
              webBytes = await xFile.readAsBytes();
            }
          } catch (e) {
            debugPrint('Erro ao ler bytes na Web: $e');
          }
        }

        final cloudUrl = await _storageService
            .uploadProductImage(
              localPath: image.uri,
              productId: product.id,
              tenantId: _tenantId,
              bytes: webBytes,
              label: image.label,
            )
            .timeout(const Duration(seconds: 90));

        if (cloudUrl.isNotEmpty) {
          updatedImages.add(
            image.copyWith(
              uri: cloudUrl,
              sourceType: ProductImageSource.networkUrl,
            ),
          );
        } else {
          updatedImages.add(image);
        }
      } catch (e) {
        debugPrint('Erro no upload: $e');
        final errorMsg = e.toString().toLowerCase();
        if (errorMsg.contains('não encontrado') ||
            errorMsg.contains('not found') ||
            errorMsg.contains('no such file')) {
          debugPrint(
            'Removendo referência de foto que não existe mais localmente para evitar loop de sync.',
          );
          // Não adiciona _image_ ao updatedImages, efetivamente quebrando o loop.
        } else {
          updatedImages.add(
            image,
          ); // Outro erro (Rede, etc), mantemos para tentar depois.
        }
      }
    }

    if (onProgress != null) {
      onProgress(0.9, 'Finalizando na nuvem...');
    }

    final updatedPhotos = updatedImages
        .map(
          (img) => ProductPhoto(
            path: img.uri,
            isPrimary:
                img.label?.toLowerCase() == 'p' ||
                img.label?.toLowerCase() == 'principal',
            photoType: img.label,
            colorKey: img.colorTag,
            id: null,
            url: '',
          ),
        )
        .toList();

    final productWithSaaS = product.copyWith(
      tenantId: _tenantId,
      images: updatedImages,
      photos: updatedPhotos,
      updatedAt: DateTime.now(),
      syncStatus: SyncStatus.synced,
    );

    await _collection.doc(product.id).set(productWithSaaS.toMap());
    await _localRepo.addProduct(productWithSaaS);
    invalidateCache(); // 🔑 Invalida cache após escrita

    if (onProgress != null) {
      onProgress(1.0, 'Nuvem atualizada!');
    }
  }

  /// 🔄 Sincroniza todos os produtos que possuem mudanças locais pendentes.
  /// Retorna o total de produtos sincronizados.
  Future<int> syncAllPending({Function(double, String)? onProgress}) async {
    final localProducts = await _localRepo.getProducts();
    final toSync = localProducts
        .where((p) => p.syncStatus == SyncStatus.pendingUpdate)
        .toList();

    if (toSync.isEmpty) {
      if (onProgress != null) onProgress(1.0, 'Tudo sincronizado!');
      return 0;
    }

    final total = toSync.length;
    var syncedCount = 0;
    for (var i = 0; i < total; i++) {
      final p = toSync[i];
      final currentProgress = i / total;
      if (onProgress != null) {
        onProgress(
          currentProgress,
          'Sincronizando ${p.name} ($i de $total)...',
        );
      }

      try {
        await syncProductToCloud(
          p,
          onProgress: (subProgress, msg) {
            if (onProgress != null) {
              final overall = currentProgress + (subProgress / total);
              onProgress(overall, msg);
            }
          },
        );
        syncedCount++;
      } catch (e) {
        debugPrint('Erro ao sincronizar ${p.id}: $e');
      }
    }

    if (onProgress != null) onProgress(1.0, 'Sincronização concluída!');
    return syncedCount;
  }

  @override
  Future<void> updateProductsBulk(
    List<Product> products, {
    Function(double, String)? onProgress,
  }) async {
    final batch = _firestore.batch();
    final total = products.length;

    for (var i = 0; i < total; i++) {
      final p = products[i];
      // ✨ Segurança Adicional: Garante que o tenantId do lote seja o correto
      final pWithTenant = p.copyWith(
        tenantId: _tenantId,
        syncStatus: SyncStatus.synced,
      );
      final docRef = _collection.doc(p.id);
      batch.set(docRef, pWithTenant.toMap());
      await _localRepo.addProduct(pWithTenant);
    }

    try {
      await batch.commit();
    } catch (_) {
      for (final product in products) {
        final productToSync = product.copyWith(
          tenantId: _tenantId,
          syncStatus: SyncStatus.pendingUpdate,
        );
        await _syncQueue.enqueue(
          SyncQueueItem(
            tenantId: _tenantId,
            entityType: 'product',
            entityId: product.id,
            operation: SyncOperation.update,
            payload: productToSync.toMap(),
          ),
        );
      }
    }
    invalidateCache();

    if (onProgress != null) {
      onProgress(1.0, '$total produtos atualizados na nuvem!');
    }
  }

  @override
  Future<void> deleteProduct(String id) async {
    await _localRepo.deleteProduct(id);
    invalidateCache(); // 🔑 Invalida cache após deletão

    try {
      await _collection.doc(id).delete();
    } catch (_) {
      await _syncQueue.enqueue(
        SyncQueueItem(
          tenantId: _tenantId,
          entityType: 'product',
          entityId: id,
          operation: SyncOperation.delete,
        ),
      );
    }
  }

  @override
  Future<void> clearAll() async {
    await _localRepo.clearAll();
  }

  @override
  Future<Product?> getByRef(String ref) async {
    // 🔑 Local-First: Tenta primeiro no cache de memória ou repo local
    final localMatch = await _localRepo.getByRef(ref);
    if (localMatch != null) return localMatch;

    // Se não achar local, tenta na nuvem (pode ser um item novo recém criado por outro device)
    try {
      final snapshot = await _collection
          .where('ref', isEqualTo: ref)
          .limit(1)
          .get();
      if (snapshot.docs.isNotEmpty) {
        final cloudProduct = Product.fromMap(
          snapshot.docs.first.data(),
        ).copyWith(syncStatus: SyncStatus.synced);
        await _localRepo.addProduct(
          cloudProduct,
        ); // Salva local para a próxima vez
        return cloudProduct;
      }
    } catch (e) {
      debugPrint('Erro ao buscar produto por REF na nuvem (usando local): $e');
    }
    return null;
  }

  @override
  Stream<List<Product>> watchProducts() {
    // 🔑 Local-First: Observa o repositório local (Hive)
    // Isso garante que mudanças salvas localmente apareçam instantaneamente.
    return _localRepo.watchProducts();
  }

  @override
  Future<List<Product>> getProductsByCategory(String categoryId) async {
    return _localRepo.getProductsByCategory(categoryId);
  }

  @override
  Stream<List<Product>> watchProductsByCategory(String categoryId) {
    return _localRepo.watchProductsByCategory(categoryId);
  }
}

final syncProductsRepositoryProvider = Provider<ProductsRepositoryContract>((
  ref,
) {
  final tenantAsync = ref.watch(currentTenantProvider);
  final localRepo =
      ref.watch(productsRepositoryProvider) as HiveProductsRepository;
  final storageService = ref.watch(saasPhotoStorageProvider);

  return tenantAsync.when(
    data: (tenant) {
      if (tenant != null) {
        return FirestoreProductsRepository(
          localRepo,
          storageService,
          tenant.id,
          SyncQueueRepository(
            Hive.box<SyncQueueItem>(SyncQueueRepository.boxName),
          ),
        );
      }
      return localRepo;
    },
    loading: () => localRepo,
    error: (_, _) => localRepo,
  );
});
