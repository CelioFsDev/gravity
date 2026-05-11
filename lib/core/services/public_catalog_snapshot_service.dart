import 'dart:convert';

import 'package:catalogo_ja/data/repositories/contracts/categories_repository_contract.dart';
import 'package:catalogo_ja/data/repositories/contracts/products_repository_contract.dart';
import 'package:catalogo_ja/data/repositories/categories_repository.dart';
import 'package:catalogo_ja/data/repositories/products_repository.dart';
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
    // 1. Resolve ProductImage list
    final newImages = <ProductImage>[];
    for (final img in product.images) {
      if (img.uri.startsWith('gs://')) {
        try {
          final relativePath = img.uri.replaceFirst(RegExp(r'gs://[^/]+/'), '');
          final url = await _storage.ref().child(relativePath).getDownloadURL();
          newImages.add(img.copyWith(uri: url));
        } catch (e) {
          debugPrint('Error resolving ProductImage ${img.uri}: $e');
          newImages.add(img);
        }
      } else {
        newImages.add(img);
      }
    }

    // 2. Resolve ProductPhoto list (Legacy)
    final newPhotos = <ProductPhoto>[];
    for (final photo in product.photos) {
      if (photo.path.startsWith('gs://')) {
        try {
          final relativePath = photo.path.replaceFirst(
            RegExp(r'gs://[^/]+/'),
            '',
          );
          final url = await _storage.ref().child(relativePath).getDownloadURL();
          newPhotos.add(photo.copyWith(path: url));
        } catch (e) {
          debugPrint('Error resolving ProductPhoto ${photo.path}: $e');
          newPhotos.add(photo);
        }
      } else {
        newPhotos.add(photo);
      }
    }

    return product.copyWith(images: newImages, photos: newPhotos);
  }

  Future<String?> publish(Catalog catalog) async {
    if (!catalog.isPublic || catalog.shareCode.trim().isEmpty) return null;

    final products = await _productsRepo.getProducts();
    final categories = await _categoriesRepo.getCategories();
    final selectedIds = catalog.productIds.toSet();

    final filteredProducts = products
        .where((p) => selectedIds.contains(p.id) && p.isActive)
        .toList();

    // Resolvendo as URLs de todas as imagens antes de salvar o snapshot
    final publicProducts = <Product>[];
    for (final p in filteredProducts) {
      publicProducts.add(await _resolveProductImages(p));
    }

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
        ref.watch(productsRepositoryProvider),
        ref.watch(categoriesRepositoryProvider),
        ref.watch(settingsRepositoryProvider),
        FirebaseStorage.instanceFor(
          bucket: 'gs://catalogo-ja-89aae.firebasestorage.app',
        ),
      );
    });
