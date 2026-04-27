import 'package:catalogo_ja/models/catalog.dart';
import 'package:catalogo_ja/models/product.dart';
import 'package:catalogo_ja/models/category.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PublicCatalogDataResponse {
  final Catalog catalog;
  final List<Product> products;
  final List<Category> categories;

  PublicCatalogDataResponse({
    required this.catalog,
    required this.products,
    required this.categories,
  });
}

class FirestorePublicCatalogRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<PublicCatalogDataResponse?> getPublicCatalogData(String shareCode) async {
    // 1. Encontrar o catálogo pelo ShareCode
    final catalogsSnapshot = await _firestore
        .collectionGroup('catalogs')
        .where('shareCode', isEqualTo: shareCode)
        .where('isPublic', isEqualTo: true)
        .limit(1)
        .get();

    if (catalogsSnapshot.docs.isEmpty) {
      return null;
    }

    final catalogDoc = catalogsSnapshot.docs.first;
    final catalog = Catalog.fromMap(catalogDoc.data());

    if (!catalog.active) {
      // Retorna com produto vazio, mas será avaliado como inativo na tela
      return PublicCatalogDataResponse(
        catalog: catalog,
        products: [],
        categories: [],
      );
    }

    // 2. Fetch Products efficiently (in chunks of 30 due to Firestore LIMITs)
    final productIds = catalog.productIds;
    final List<Product> products = [];

    if (productIds.isNotEmpty) {
      for (var i = 0; i < productIds.length; i += 30) {
        final end = (i + 30 < productIds.length) ? i + 30 : productIds.length;
        final chunk = productIds.sublist(i, end);

        final pSnapshot = await _firestore
            .collection('tenants')
            .doc(catalog.tenantId)
            .collection('products')
            .where('id', whereIn: chunk)
            .get();

        products.addAll(
          pSnapshot.docs
              .map((doc) => Product.fromMap(doc.data()))
              .where((p) => p.isActive),
        );
      }
    }

    // 3. Extract unique Category IDs from active products
    final usedCategoryIds = products.expand((p) => p.categoryIds).toSet().toList();
    final List<Category> categories = [];

    if (usedCategoryIds.isNotEmpty) {
      for (var i = 0; i < usedCategoryIds.length; i += 30) {
        final end = (i + 30 < usedCategoryIds.length) ? i + 30 : usedCategoryIds.length;
        final chunk = usedCategoryIds.sublist(i, end);

        final cSnapshot = await _firestore
            .collection('tenants')
            .doc(catalog.tenantId)
            .collection('categories')
            .where('id', whereIn: chunk)
            .get();

        categories.addAll(
          cSnapshot.docs
              .map((doc) => Category.fromMap(doc.data()))
              .where((c) => c.type == CategoryType.productType),
        );
      }
    }

    return PublicCatalogDataResponse(
      catalog: catalog,
      products: products,
      categories: categories,
    );
  }
}

final publicCatalogRepositoryProvider = Provider<FirestorePublicCatalogRepository>((ref) {
  return FirestorePublicCatalogRepository();
});
