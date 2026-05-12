import 'dart:convert';

import 'package:catalogo_ja/core/services/public_catalog_snapshot_service.dart';
import 'package:catalogo_ja/models/catalog.dart';
import 'package:catalogo_ja/models/category.dart';
import 'package:catalogo_ja/models/product.dart';
import 'package:catalogo_ja/models/product_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

class PublicCatalogDataResponse {
  final Catalog catalog;
  final List<Product> products;
  final List<Category> categories;
  final String? whatsappNumber;

  PublicCatalogDataResponse({
    required this.catalog,
    required this.products,
    required this.categories,
    this.whatsappNumber,
  });
}

class PublicCatalogParseException implements Exception {
  const PublicCatalogParseException(this.fieldPath, this.sourceError);

  final String fieldPath;
  final Object sourceError;

  @override
  String toString() =>
      'Invalid public catalog field "$fieldPath": $sourceError';
}

class FirestorePublicCatalogRepository {
  static const String _storageBucket = 'catalogo-ja-89aae.firebasestorage.app';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instanceFor(
    bucket: 'gs://$_storageBucket',
  );

  Future<PublicCatalogDataResponse?> getPublicCatalogData(
    String shareCode,
  ) async {
    try {
      final rawShareCode = shareCode.trim();
      if (rawShareCode.isEmpty) return null;
      final normalizedShareCode = rawShareCode.toLowerCase();

      final snapshotData = await _getPublicCatalogSnapshot(normalizedShareCode);
      if (snapshotData != null) {
        debugPrint(
          '✅ Public catalog loaded from snapshot ($normalizedShareCode)',
        );
        return snapshotData;
      }

      final catalog =
          await _findPublicCatalogByShareCode(normalizedShareCode) ??
          (normalizedShareCode == rawShareCode
              ? null
              : await _findPublicCatalogByShareCode(rawShareCode));
      if (catalog == null) return null;

      if (!catalog.active) {
        return PublicCatalogDataResponse(
          catalog: catalog,
          products: [],
          categories: [],
          whatsappNumber: null,
        );
      }

      final productIds = catalog.productIds;
      var products = <Product>[];

      if (productIds.isNotEmpty) {
        final tenantId = (catalog.tenantId ?? '').trim();
        if (tenantId.isNotEmpty) {
          products = await _fetchProductsFromCollection(
            _firestore
                .collection('tenants')
                .doc(tenantId)
                .collection('products'),
            productIds,
          );
        }

        if (products.isEmpty) {
          products = await _fetchProductsFromCollection(
            _firestore.collection('products'),
            productIds,
          );
        }
      }

      final usedCategoryIds = products
          .expand((p) => p.categoryIds)
          .toSet()
          .toList();
      var categories = <Category>[];

      if (usedCategoryIds.isNotEmpty) {
        final tenantId = (catalog.tenantId ?? '').trim();
        if (tenantId.isNotEmpty) {
          categories = await _fetchCategoriesFromCollection(
            _firestore
                .collection('tenants')
                .doc(tenantId)
                .collection('categories'),
            usedCategoryIds,
          );
        }

        if (categories.isEmpty) {
          categories = await _fetchCategoriesFromCollection(
            _firestore.collection('categories'),
            usedCategoryIds,
          );
        }
      }

      return PublicCatalogDataResponse(
        catalog: catalog,
        products: products,
        categories: categories,
        whatsappNumber: null,
      );
    } catch (e, s) {
      debugPrint('Error loading public catalog data for $shareCode: $e');
      debugPrint(s.toString());
      rethrow;
    }
  }

  Future<Catalog?> _findPublicCatalogByShareCode(String shareCode) async {
    final code = shareCode.trim();
    if (code.isEmpty) return null;
    final normalizedCode = code.toLowerCase();

    try {
      final catalogsSnapshot = await _firestore
          .collectionGroup('catalogs')
          .where('shareCode', isEqualTo: code)
          .where('isPublic', isEqualTo: true)
          .limit(1)
          .get();

      if (catalogsSnapshot.docs.isNotEmpty) {
        return Catalog.fromMap(catalogsSnapshot.docs.first.data());
      }
    } catch (e) {
      debugPrint('Public catalog collectionGroup lookup failed: $e');
    }

    try {
      final rootExactSnapshot = await _firestore
          .collection('catalogs')
          .where('shareCode', isEqualTo: code)
          .where('isPublic', isEqualTo: true)
          .limit(1)
          .get();

      if (rootExactSnapshot.docs.isNotEmpty) {
        return Catalog.fromMap(rootExactSnapshot.docs.first.data());
      }
    } catch (e) {
      debugPrint('Public catalog root exact lookup failed: $e');
    }

    try {
      final rootPublicSnapshot = await _firestore
          .collection('catalogs')
          .where('isPublic', isEqualTo: true)
          .limit(200)
          .get();

      for (final doc in rootPublicSnapshot.docs) {
        final data = doc.data();
        final docCode = (data['shareCode'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
        if (docCode == normalizedCode) {
          return Catalog.fromMap(data);
        }
      }
    } catch (e) {
      debugPrint('Public catalog root list lookup failed: $e');
    }

    return null;
  }

  Future<List<Product>> _fetchProductsFromCollection(
    CollectionReference<Map<String, dynamic>> collection,
    List<String> productIds,
  ) async {
    final productsById = <String, Product>{};

    for (var i = 0; i < productIds.length; i += 30) {
      final end = (i + 30 < productIds.length) ? i + 30 : productIds.length;
      final chunk = productIds.sublist(i, end);

      final byFieldSnapshot = await collection
          .where('id', whereIn: chunk)
          .get();

      for (final doc in byFieldSnapshot.docs) {
        try {
          final product = await _resolvePublicProductImages(
            _parseProduct(doc.data(), '${collection.path}/${doc.id}'),
          );
          if (product.isActive) {
            productsById[product.id.isNotEmpty ? product.id : doc.id] = product;
          }
        } catch (e) {
          debugPrint('⚠️ Error parsing product in public catalog: $e');
          continue;
        }
      }
    }

    final result = <Product>[];
    for (final id in productIds) {
      final p = productsById[id];
      if (p != null) result.add(p);
    }
    return result;
  }

  Future<List<Category>> _fetchCategoriesFromCollection(
    CollectionReference<Map<String, dynamic>> collection,
    List<String> categoryIds,
  ) async {
    final categoriesById = <String, Category>{};

    for (var i = 0; i < categoryIds.length; i += 30) {
      final end = (i + 30 < categoryIds.length) ? i + 30 : categoryIds.length;
      final chunk = categoryIds.sublist(i, end);

      final byFieldSnapshot = await collection
          .where('id', whereIn: chunk)
          .get();

      for (final doc in byFieldSnapshot.docs) {
        try {
          final category = _parseCategory(
            doc.data(),
            '${collection.path}/${doc.id}',
          );
          if (category.type == CategoryType.productType) {
            categoriesById[category.id.isNotEmpty ? category.id : doc.id] =
                category;
          }
        } catch (e) {
          debugPrint('⚠️ Error parsing category in public catalog: $e');
          continue;
        }
      }
    }

    final result = <Category>[];
    for (final id in categoryIds) {
      final c = categoriesById[id];
      if (c != null) result.add(c);
    }
    return result;
  }

  Future<PublicCatalogDataResponse?> _getPublicCatalogSnapshot(
    String shareCode,
  ) async {
    try {
      final snapshotPath = PublicCatalogSnapshotService.snapshotPath(shareCode);
      final response = await _fetchPublicSnapshot(snapshotPath);
      if (response.statusCode != 200) {
        debugPrint(
          '❌ Error: Snapshot fetch failed with status ${response.statusCode}',
        );
        return null;
      }
      final bytes = response.bodyBytes;
      if (bytes.isEmpty) return null;

      final jsonStr = utf8.decode(bytes);
      final json = _mapFromDynamic(jsonDecode(jsonStr), 'snapshot');
      if (json == null) return null;

      final catalogMap = _mapFromDynamic(json['catalog'], 'snapshot.catalog');
      if (catalogMap == null) {
        debugPrint('❌ Error: "catalog" field is missing in snapshot');
        return null;
      }

      final catalog = _parseCatalog(catalogMap, 'snapshot.catalog');
      final store =
          _mapFromDynamic(json['store'], 'snapshot.store') ??
          <String, dynamic>{};
      final products = <Product>[];
      final rawProducts = _listFromDynamic(
        json['products'],
        'snapshot.products',
      );
      for (var index = 0; index < rawProducts.length; index++) {
        final item = rawProducts[index];
        final productMap = _mapFromDynamic(item, 'snapshot.products[$index]');
        if (productMap == null) continue;
        try {
          final product = await _resolvePublicProductImages(
            _parseProduct(productMap, 'snapshot.products[$index]'),
          );
          if (product.isActive) products.add(product);
        } catch (e) {
          debugPrint(
            'Skipping invalid product at snapshot.products[$index]: $e',
          );
          continue;
        }
      }

      final categories = <Category>[];
      final rawCategories = _listFromDynamic(
        json['categories'],
        'snapshot.categories',
      );
      for (var index = 0; index < rawCategories.length; index++) {
        final item = rawCategories[index];
        final categoryMap = _mapFromDynamic(
          item,
          'snapshot.categories[$index]',
        );
        if (categoryMap == null) continue;
        try {
          final category = _parseCategory(
            categoryMap,
            'snapshot.categories[$index]',
          );
          if (category.type == CategoryType.productType) {
            categories.add(category);
          }
        } catch (e) {
          debugPrint(
            'Skipping invalid category at snapshot.categories[$index]: $e',
          );
          continue;
        }
      }

      return PublicCatalogDataResponse(
        catalog: catalog,
        products: products,
        categories: categories,
        whatsappNumber: store['whatsappNumber']?.toString(),
      );
    } catch (e, s) {
      debugPrint('⚠️ Error loading public catalog snapshot for $shareCode: $e');
      debugPrint(s.toString());
      return null;
    }
  }

  Future<http.Response> _fetchPublicSnapshot(String snapshotPath) async {
    final encodedPath = Uri.encodeComponent(snapshotPath);
    final directUri = Uri.parse(
      'https://firebasestorage.googleapis.com/v0/b/$_storageBucket/o/$encodedPath?alt=media',
    );

    try {
      final response = await http.get(directUri);
      if (response.statusCode == 200) return response;
      debugPrint(
        'Public snapshot direct fetch failed with status ${response.statusCode}',
      );
    } catch (e) {
      debugPrint('Public snapshot direct fetch failed: $e');
    }

    final url = await _storage.ref().child(snapshotPath).getDownloadURL();
    return http.get(Uri.parse(url));
  }

  Map<String, dynamic>? _mapFromDynamic(dynamic value, String fieldPath) {
    if (value == null) return null;
    if (value is! Map) {
      debugPrint(
        'Public catalog field $fieldPath expected Map, got ${value.runtimeType}',
      );
      return null;
    }

    final result = <String, dynamic>{};
    value.forEach((key, item) {
      result[key.toString()] = item;
    });
    return result;
  }

  List<dynamic> _listFromDynamic(dynamic value, String fieldPath) {
    if (value == null) return const [];
    if (value is List) return value;
    if (value is String && value.trim().isNotEmpty) return [value];

    debugPrint(
      'Public catalog field $fieldPath expected List, got ${value.runtimeType}',
    );
    return const [];
  }

  Catalog _parseCatalog(Map<String, dynamic> map, String fieldPath) {
    try {
      return Catalog.fromMap(map);
    } catch (e) {
      throw PublicCatalogParseException(fieldPath, e);
    }
  }

  Product _parseProduct(Map<String, dynamic> map, String fieldPath) {
    try {
      return Product.fromMap(map);
    } catch (e) {
      throw PublicCatalogParseException(fieldPath, e);
    }
  }

  Category _parseCategory(Map<String, dynamic> map, String fieldPath) {
    try {
      return Category.fromMap(map);
    } catch (e) {
      throw PublicCatalogParseException(fieldPath, e);
    }
  }

  Future<Product> _resolvePublicProductImages(Product product) async {
    var images = List<ProductImage>.from(product.images);

    // Fallback 1: build from legacy photos list
    if (images.isEmpty && product.photos.isNotEmpty) {
      images = product.photos
          .map((p) => p.toProductImage())
          .where((img) => img.uri.trim().isNotEmpty)
          .toList();
    }

    // Fallback 2: build from remoteImages strings
    if (images.isEmpty && product.remoteImages.isNotEmpty) {
      images = product.remoteImages
          .where((url) => url.trim().isNotEmpty)
          .map((url) => ProductImage.network(url: url.trim()))
          .toList();
    }

    final resolvedImages = <ProductImage>[];
    for (final image in images) {
      final uri = image.uri.trim();
      if (uri.isEmpty) continue;

      // Already a renderable HTTP(S) / data / blob URI — keep as-is
      if (_isRenderablePublicImageUri(uri) && !uri.startsWith('gs://')) {
        resolvedImages.add(image);
        continue;
      }

      // Try to resolve gs:// or relative storage paths to download URLs
      final resolvedUri = await _resolveStorageUri(uri);
      if (_isRenderablePublicImageUri(resolvedUri)) {
        resolvedImages.add(
          resolvedUri == uri
              ? image
              : image.copyWith(
                  uri: resolvedUri,
                  sourceType: ProductImageSource.networkUrl,
                ),
        );
      } else {
        // Resolution failed — keep the original gs:// URI so the card's
        // FutureBuilder can attempt resolution at render time.
        if (uri.startsWith('gs://')) {
          resolvedImages.add(image);
        }
        // Otherwise silently discard (local path, etc.)
      }
    }

    // Resolve legacy photos independently (used by mainImage fallback)
    final resolvedPhotos = <ProductPhoto>[];
    for (final photo in product.photos) {
      final rawUri =
          photo.url.trim().isNotEmpty ? photo.url.trim() : photo.path.trim();
      if (rawUri.isEmpty) continue;

      final resolvedPath = await _resolveStorageUri(photo.path);
      final resolvedUrl = await _resolveStorageUri(photo.url);

      resolvedPhotos.add(
        photo.copyWith(
          path: _isRenderablePublicImageUri(resolvedPath)
              ? resolvedPath
              : (photo.path.startsWith('gs://') ? photo.path : ''),
          url: _isRenderablePublicImageUri(resolvedUrl)
              ? resolvedUrl
              : (photo.url.startsWith('gs://') ? photo.url : ''),
        ),
      );
    }

    return product.copyWith(images: resolvedImages, photos: resolvedPhotos);
  }

  bool _isRenderablePublicImageUri(String uri) {
    final trimmed = uri.trim();
    return trimmed.startsWith('http://') ||
        trimmed.startsWith('https://') ||
        trimmed.startsWith('gs://') ||
        trimmed.startsWith('data:') ||
        trimmed.startsWith('blob:');
  }

  Future<String> _resolveStorageUri(String uri) async {
    final trimmed = uri.trim();
    if (trimmed.isEmpty ||
        trimmed.startsWith('http://') ||
        trimmed.startsWith('https://') ||
        trimmed.startsWith('data:') ||
        trimmed.startsWith('blob:')) {
      return uri;
    }

    final storagePath = _storagePathFromUri(trimmed);
    if (storagePath == null || storagePath.isEmpty) return uri;

    try {
      return await _storage.ref().child(storagePath).getDownloadURL();
    } catch (e) {
      debugPrint('⚠️ Error resolving storage URI for $uri: $e');
      return uri;
    }
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
}

final publicCatalogRepositoryProvider =
    Provider<FirestorePublicCatalogRepository>((ref) {
      return FirestorePublicCatalogRepository();
    });
