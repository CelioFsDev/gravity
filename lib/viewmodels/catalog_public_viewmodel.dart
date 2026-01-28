import 'package:gravity/data/repositories/catalogs_repository.dart';
import 'package:gravity/data/repositories/categories_repository.dart';
import 'package:gravity/data/repositories/products_repository.dart';
import 'package:gravity/models/catalog.dart';
import 'package:gravity/models/category.dart';
import 'package:gravity/models/product.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'catalog_public_viewmodel.g.dart';

class PublicCatalogData {
  final Catalog catalog;
  final List<Product> products;
  final List<Category> categories;

  PublicCatalogData({required this.catalog, required this.products, required this.categories});
}

@riverpod
Future<PublicCatalogData?> catalogPublic(CatalogPublicRef ref, String shareCode) async {
  final catalogRepo = ref.watch(catalogsRepositoryProvider);
  final productRepo = ref.watch(productsRepositoryProvider);

  final categoriesRepo = ref.watch(categoriesRepositoryProvider);
  final catalog = await catalogRepo.getByShareCode(shareCode.toLowerCase());
  if (catalog == null) return null;

  final allProducts = await productRepo.getProducts();
  final allCategories = await categoriesRepo.getCategories();

  // Filter products: must be in catalog.productIds AND active
  final catalogProducts = allProducts.where((p) {
    return catalog.productIds.contains(p.id) && p.isActive;
  }).toList();
  
  // Sort or maintain order? Usually existing order or manual sort.
  // Prompt doesn't specify sort order for public, but usually it follows product list order or add date.
  // Let's assume order of productIds? Or just retrieval order.
  
  // Also filter categories that are used by these products
  final usedCategoryIds = catalogProducts.map((p) => p.categoryId).toSet();
  final usedCategories = allCategories.where((c) => usedCategoryIds.contains(c.id)).toList();

  return PublicCatalogData(catalog: catalog, products: catalogProducts, categories: usedCategories);
}
