import 'dart:convert';
import 'dart:typed_data';

import 'package:catalogo_ja/core/services/saas_photo_storage_service.dart';
import 'package:catalogo_ja/data/repositories/contracts/products_repository_contract.dart';
import 'package:catalogo_ja/data/repositories/products_repository.dart';
import 'package:catalogo_ja/models/product.dart';
import 'package:catalogo_ja/models/product_image.dart';
import 'package:catalogo_ja/viewmodels/tenant_viewmodel.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

class FirestoreProductsRepository implements ProductsRepositoryContract {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final HiveProductsRepository _localRepo;
  final SaaSPhotoStorageService _storageService;
  final String _tenantId;

  FirestoreProductsRepository(
    this._localRepo,
    this._storageService,
    this._tenantId,
  );

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('products');

  @override
  Future<List<Product>> getProducts() async {
    try {
      final snapshot = await _collection
          .where('tenantId', isEqualTo: _tenantId)
          .get()
          .timeout(const Duration(seconds: 10));

      final cloudProducts = snapshot.docs
          .map((doc) => Product.fromMap(doc.data()))
          .toList();
      final localProducts = await _localRepo.getProducts();

      final merged = <String, Product>{
        for (final product in localProducts) product.id: product,
      };

      for (final cloudProduct in cloudProducts) {
        final localProduct = merged[cloudProduct.id];
        if (localProduct == null) {
          merged[cloudProduct.id] = cloudProduct;
          continue;
        }

        if (cloudProduct.updatedAt.isAfter(localProduct.updatedAt) &&
            !_hasLocalOnlyPhotos(localProduct)) {
          merged[cloudProduct.id] = cloudProduct;
        }
      }

      return merged.values.toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    } catch (e) {
      debugPrint('Erro ao buscar produtos da nuvem (usando local): $e');
      return await _localRepo.getProducts();
    }
  }

  bool _hasLocalOnlyPhotos(Product product) {
    final hasBase64Photos = product.photos.any((p) => p.path.startsWith('data:'));
    final hasBase64Images = product.images.any((i) => i.uri.startsWith('data:'));
    final hasLocalPathPhotos = product.photos.any(
      (p) =>
          !p.path.startsWith('http') &&
          !p.path.startsWith('data:') &&
          p.path.isNotEmpty,
    );
    final hasLocalPathImages = product.images.any(
      (i) =>
          !i.uri.startsWith('http') &&
          !i.uri.startsWith('gs://') &&
          !i.uri.startsWith('data:') &&
          i.uri.isNotEmpty,
    );
    return hasBase64Photos ||
        hasBase64Images ||
        hasLocalPathPhotos ||
        hasLocalPathImages;
  }

  @override
  Future<void> addProduct(
    Product product, {
    Function(double, String)? onProgress,
  }) async {
    await syncProductToCloud(product, onProgress: onProgress);
  }

  @override
  Future<void> syncProductToCloud(
    Product product, {
    Function(double, String)? onProgress,
  }) async {
    var imagesToSync = List<ProductImage>.from(product.images);

    if (imagesToSync.isEmpty && product.photos.isNotEmpty) {
      imagesToSync =
          product.photos.map((photo) => photo.toProductImage()).toList();
    }

    final totalImages = imagesToSync.length;
    final updatedImages = <ProductImage>[];

    for (var i = 0; i < totalImages; i++) {
      final image = imagesToSync[i];
      if (onProgress != null) {
        onProgress(i / totalImages, 'Enviando foto ${i + 1} de $totalImages...');
      }

      final isLocal =
          (!image.uri.startsWith('http') &&
              !image.uri.startsWith('gs://') &&
              image.sourceType != ProductImageSource.networkUrl) ||
          image.uri.startsWith('data:');

      if (!isLocal) {
        updatedImages.add(image);
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
        updatedImages.add(image);
      }
    }

    if (onProgress != null) {
      onProgress(0.9, 'Finalizando na nuvem...');
    }

    final updatedPhotos = updatedImages
        .map(
          (img) => ProductPhoto(
            path: img.uri,
            isPrimary: img.label?.toLowerCase() == 'p' ||
                img.label?.toLowerCase() == 'principal',
            photoType: img.label,
            colorKey: img.colorTag,
          ),
        )
        .toList();

    final productWithSaaS = product.copyWith(
      tenantId: _tenantId,
      images: updatedImages,
      photos: updatedPhotos,
      updatedAt: DateTime.now(),
    );

    await _collection.doc(product.id).set(productWithSaaS.toMap());
    await _localRepo.addProduct(productWithSaaS);

    if (onProgress != null) {
      onProgress(1.0, 'Nuvem atualizada!');
    }
  }

  @override
  Future<void> updateProduct(
    Product product, {
    Function(double, String)? onProgress,
  }) async =>
      addProduct(product, onProgress: onProgress);

  @override
  Future<void> deleteProduct(String id) async {
    await _collection.doc(id).delete();
    await _localRepo.deleteProduct(id);
  }

  @override
  Future<void> clearAll() async {
    await _localRepo.clearAll();
  }

  @override
  Future<Product?> getByRef(String ref) async {
    final snapshot = await _collection
        .where('tenantId', isEqualTo: _tenantId)
        .where('ref', isEqualTo: ref)
        .limit(1)
        .get();
    if (snapshot.docs.isNotEmpty) {
      return Product.fromMap(snapshot.docs.first.data());
    }
    return _localRepo.getByRef(ref);
  }

  @override
  Stream<List<Product>> watchProducts() {
    return _collection
        .where('tenantId', isEqualTo: _tenantId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Product.fromMap(doc.data())).toList();
    });
  }

  @override
  Future<List<Product>> getProductsByCategory(String categoryId) async {
    final snapshot = await _collection
        .where('tenantId', isEqualTo: _tenantId)
        .where('categoryIds', arrayContains: categoryId)
        .get();
    return snapshot.docs.map((doc) => Product.fromMap(doc.data())).toList();
  }

  @override
  Stream<List<Product>> watchProductsByCategory(String categoryId) {
    return _collection
        .where('tenantId', isEqualTo: _tenantId)
        .where('categoryIds', arrayContains: categoryId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Product.fromMap(doc.data())).toList();
    });
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
        );
      }
      return localRepo;
    },
    loading: () => localRepo,
    error: (_, _) => localRepo,
  );
});
