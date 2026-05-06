import 'dart:convert';

import 'package:catalogo_ja/core/services/public_catalog_snapshot_service.dart';
import 'package:catalogo_ja/models/catalog.dart';
import 'package:catalogo_ja/models/category.dart';
import 'package:catalogo_ja/models/product.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

class FirestorePublicCatalogRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instanceFor(
    bucket: 'gs://catalogo-ja-89aae.firebasestorage.app',
  );

  Future<PublicCatalogDataResponse?> getPublicCatalogData(
    String shareCode,
  ) async {
    final rawShareCode = shareCode.trim();
    if (rawShareCode.isEmpty) return null;
    final normalizedShareCode = rawShareCode.toLowerCase();

    final snapshotData = await _getPublicCatalogSnapshot(normalizedShareCode);
    if (snapshotData != null) return snapshotData;

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
          _firestore.collection('tenants').doc(tenantId).collection('products'),
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
  }

  Future<Catalog?> _findPublicCatalogByShareCode(String shareCode) async {
    final code = shareCode.trim();
    if (code.isEmpty) return null;
    final normalizedCode = code.toLowerCase();

    final catalogsSnapshot = await _firestore
        .collectionGroup('catalogs')
        .where('shareCode', isEqualTo: code)
        .where('isPublic', isEqualTo: true)
        .limit(1)
        .get();

    if (catalogsSnapshot.docs.isNotEmpty) {
      return Catalog.fromMap(catalogsSnapshot.docs.first.data());
    }

    final rootExactSnapshot = await _firestore
        .collection('catalogs')
        .where('shareCode', isEqualTo: code)
        .where('isPublic', isEqualTo: true)
        .limit(1)
        .get();

    if (rootExactSnapshot.docs.isNotEmpty) {
      return Catalog.fromMap(rootExactSnapshot.docs.first.data());
    }

    final rootPublicSnapshot = await _firestore
        .collection('catalogs')
        .where('isPublic', isEqualTo: true)
        .limit(200)
        .get();

    for (final doc in rootPublicSnapshot.docs) {
      final data = doc.data();
      final docCode = (data['shareCode'] ?? '').toString().trim().toLowerCase();
      if (docCode == normalizedCode) {
        return Catalog.fromMap(data);
      }
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
        final product = Product.fromMap(doc.data());
        if (product.isActive) {
          productsById[product.id.isNotEmpty ? product.id : doc.id] = product;
        }
      }
    }

    return productIds
        .map((id) => productsById[id])
        .whereType<Product>()
        .toList();
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
        final category = Category.fromMap(doc.data());
        if (category.type == CategoryType.productType) {
          categoriesById[category.id.isNotEmpty ? category.id : doc.id] =
              category;
        }
      }
    }

    return categoryIds
        .map((id) => categoriesById[id])
        .whereType<Category>()
        .toList();
  }

  Future<PublicCatalogDataResponse?> _getPublicCatalogSnapshot(
    String shareCode,
  ) async {
    try {
      final ref = _storage.ref().child(
        PublicCatalogSnapshotService.snapshotPath(shareCode),
      );
      final bytes = await ref.getData(20 * 1024 * 1024);
      if (bytes == null || bytes.isEmpty) return null;

      final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      final catalog = Catalog.fromMap(
        Map<String, dynamic>.from(json['catalog'] as Map),
      );
      final store = Map<String, dynamic>.from(json['store'] as Map? ?? {});
      final products = (json['products'] as List? ?? [])
          .where((item) => item is Map)
          .map((item) => Product.fromMap(Map<String, dynamic>.from(item as Map)))
          .where((p) => p.isActive)
          .toList();
      final categories = (json['categories'] as List? ?? [])
          .where((item) => item is Map)
          .map((item) => Category.fromMap(Map<String, dynamic>.from(item as Map)))
          .where((c) => c.type == CategoryType.productType)
          .toList();

      return PublicCatalogDataResponse(
        catalog: catalog,
        products: products,
        categories: categories,
        whatsappNumber: store['whatsappNumber']?.toString(),
      );
    } catch (_) {
      return null;
    }
  }
}

final publicCatalogRepositoryProvider =
    Provider<FirestorePublicCatalogRepository>((ref) {
      return FirestorePublicCatalogRepository();
    });
