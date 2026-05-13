import 'dart:convert';

import 'package:catalogo_ja/data/repositories/contracts/categories_repository_contract.dart';
import 'package:catalogo_ja/data/repositories/contracts/products_repository_contract.dart';
import 'package:catalogo_ja/data/repositories/categories_repository.dart';
import 'package:catalogo_ja/data/repositories/firestore_products_repository.dart';
import 'package:catalogo_ja/data/repositories/settings_repository.dart';
import 'package:catalogo_ja/models/catalog.dart';
import 'package:catalogo_ja/models/category.dart';
import 'package:catalogo_ja/models/product.dart';
import 'package:catalogo_ja/models/product_image.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PublicCatalogSnapshotService {
  static const int schemaVersion = 1;

  final ProductsRepositoryContract _productsRepo;
  final CategoriesRepositoryContract _categoriesRepo;
  final SettingsRepository _settingsRepo;
  final FirebaseStorage _storage;

  PublicCatalogSnapshotService(
    this._productsRepo,
    this._categoriesRepo,
    this._settingsRepo,
    this._storage,
  );

  Future<Product> _resolveProductImages(Product product) async {
    final candidateImages = <ProductImage>[];
    final seenUris = <String>{};

    void addCandidate(ProductImage image) {
      final uri = image.uri.trim();
      if (uri.isEmpty || seenUris.contains(uri)) return;
      seenUris.add(uri);
      candidateImages.add(image.copyWith(uri: uri));
    }

    for (final image in product.images) {
      addCandidate(image);
    }
    for (final photo in product.photos) {
      addCandidate(photo.toProductImage());
    }
    for (final remoteImage in product.remoteImages) {
      final uri = remoteImage.trim();
      if (uri.isNotEmpty) addCandidate(ProductImage.network(url: uri));
    }

    final newImages = await Future.wait(candidateImages.map((image) async {
      final resolvedUri = await _resolvePublicImageUri(image.uri);
      if (_isRenderablePublicImageUri(resolvedUri)) {
        return image.copyWith(
          uri: resolvedUri,
          sourceType: ProductImageSource.networkUrl,
        );
      } else if (image.uri.startsWith('gs://')) {
        // Keep gs:// as a last resort; the public UI can still resolve it.
        return image;
      }
      return null;
    })).then((images) => images.whereType<ProductImage>().toList());

    final newPhotos = await Future.wait(product.photos.map((photo) async {
      final resolved = await Future.wait([
        _resolvePublicImageUri(photo.path),
        _resolvePublicImageUri(photo.url),
      ]);
      final path = resolved[0];
      final url = resolved[1];
      return photo.copyWith(
        path: _isRenderablePublicImageUri(path)
            ? path
            : (photo.path.startsWith('gs://') ? photo.path : ''),
        url: _isRenderablePublicImageUri(url)
            ? url
            : (photo.url.startsWith('gs://') ? photo.url : ''),
      );
    }));

    return product.copyWith(images: newImages, photos: newPhotos);
  }

  Future<void> _syncProductsBeforeSnapshot(List<Product> products) async {
    final productsToSync = products
        .where(
          (product) =>
              product.syncStatus == SyncStatus.pendingUpdate ||
              product.hasLocalOnlyPhotos,
        )
        .toList();

    for (final product in productsToSync) {
      try {
        await _productsRepo.syncProductToCloud(product);
      } catch (e) {
        debugPrint(
          'Error syncing product ${product.id} before public snapshot: $e',
        );
      }
    }
  }

  Future<String> _resolvePublicImageUri(String uri) async {
    final trimmed = uri.trim();
    if (trimmed.isEmpty ||
        trimmed.startsWith('http://') ||
        trimmed.startsWith('https://') ||
        trimmed.startsWith('data:') ||
        trimmed.startsWith('blob:')) {
      return trimmed;
    }

    final storagePath = _storagePathFromUri(trimmed);
    if (storagePath == null || storagePath.isEmpty) return trimmed;

    try {
      return await _storage.ref().child(storagePath).getDownloadURL();
    } catch (e) {
      debugPrint('Error resolving public image URI $uri: $e');
      return trimmed;
    }
  }

  bool _isRenderablePublicImageUri(String uri) {
    final trimmed = uri.trim();
    return trimmed.startsWith('http://') ||
        trimmed.startsWith('https://') ||
        trimmed.startsWith('gs://') ||
        trimmed.startsWith('data:') ||
        trimmed.startsWith('blob:');
  }

  String? _storagePathFromUri(String uri) {
    if (uri.startsWith('gs://')) {
      return uri.replaceFirst(RegExp(r'gs://[^/]+/'), '');
    }
    if (uri.startsWith('tenants/') || uri.startsWith('public_catalogs/')) {
      return uri;
    }
    return null;
  }

  Future<String?> publish(Catalog catalog) async {
    if (!catalog.isPublic || catalog.shareCode.trim().isEmpty) return null;

    var products = await _productsRepo.getProducts();
    final categories = await _categoriesRepo.getCategories();
    final selectedIds = catalog.productIds.toSet();

    var filteredProducts = products
        .where((p) => selectedIds.contains(p.id) && p.isActive)
        .toList();

    await _syncProductsBeforeSnapshot(filteredProducts);
    products = await _productsRepo.getProducts();
    filteredProducts = products
        .where((p) => selectedIds.contains(p.id) && p.isActive)
        .toList();

    // Resolve URLs in parallel so sharing does not wait one image at a time.
    final publicProducts = await Future.wait(
      filteredProducts.map(_resolveProductImages),
    );

    final usedCategoryIds = publicProducts.expand((p) => p.categoryIds).toSet();
    final publicCategories = categories
        .where(
          (c) =>
              usedCategoryIds.contains(c.id) &&
              c.type == CategoryType.productType,
        )
        .toList();

    final settings = _settingsRepo.getSettings();
    final payload = {
      'schemaVersion': schemaVersion,
      'publishedAt': DateTime.now().toIso8601String(),
      'store': {
        'whatsappNumber': settings.whatsappNumber,
        'publicBaseUrl': settings.publicBaseUrl,
      },
      'catalog': catalog.toMap(),
      'products': publicProducts.map((p) => p.toMap()).toList(),
      'categories': publicCategories.map((c) => c.toMap()).toList(),
    };

    final jsonBytes = Uint8List.fromList(utf8.encode(jsonEncode(payload)));
    final ref = _storage.ref().child(_snapshotPath(catalog.shareCode));
    await ref.putData(
      jsonBytes,
      SettableMetadata(
        contentType: 'application/json; charset=utf-8',
        cacheControl: 'public, max-age=60',
        customMetadata: {
          'shareCode': catalog.shareCode.toLowerCase(),
          if ((catalog.tenantId ?? '').isNotEmpty)
            'tenantId': catalog.tenantId!,
        },
      ),
    );

    return ref.getDownloadURL();
  }

  static String snapshotPath(String shareCode) => _snapshotPath(shareCode);

  static String _snapshotPath(String shareCode) =>
      'public_catalogs/${shareCode.trim().toLowerCase()}/catalog.json';
}

final publicCatalogSnapshotServiceProvider =
    Provider<PublicCatalogSnapshotService>((ref) {
      return PublicCatalogSnapshotService(
        ref.watch(syncProductsRepositoryProvider),
        ref.watch(categoriesRepositoryProvider),
        ref.watch(settingsRepositoryProvider),
        FirebaseStorage.instanceFor(
          bucket: 'gs://catalogo-ja-89aae.firebasestorage.app',
        ),
      );
    });
