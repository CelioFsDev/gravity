import 'package:catalogo_ja/data/repositories/catalogs_repository.dart';
import 'package:catalogo_ja/data/repositories/categories_repository.dart';
import 'package:catalogo_ja/data/repositories/products_repository.dart';
import 'package:catalogo_ja/models/catalog.dart';
import 'package:catalogo_ja/models/category.dart';
import 'package:catalogo_ja/models/product.dart';
import 'package:catalogo_ja/core/error/app_failure.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'catalog_public_viewmodel.g.dart';

class PublicCatalogData {
  final Catalog catalog;
  final List<Product> products;
  final List<Category> categories;

  PublicCatalogData({
    required this.catalog,
    required this.products,
    required this.categories,
  });
}

@riverpod
Future<PublicCatalogData?> catalogPublic(
  CatalogPublicRef ref,
  String shareCode,
) async {
  try {
    final catalogRepo = ref.watch(catalogsRepositoryProvider);
    final productRepo = ref.watch(productsRepositoryProvider);

    final categoriesRepo = ref.watch(categoriesRepositoryProvider);
    final catalog = await catalogRepo.getByShareCode(shareCode.toLowerCase());
    if (catalog == null) return null;

    final allProducts = await productRepo.getProducts();
    final allCategories = await categoriesRepo.getCategories();

    final catalogProducts = allProducts.where((p) {
      return catalog.productIds.contains(p.id) && p.isActive;
    }).toList();

    final usedCategoryIds = catalogProducts
        .expand((p) => p.categoryIds)
        .toSet();
    final usedCategories = allCategories
        .where(
          (c) =>
              c.type == CategoryType.productType &&
              usedCategoryIds.contains(c.id),
        )
        .toList();

    return PublicCatalogData(
      catalog: catalog,
      products: catalogProducts,
      categories: usedCategories,
    );
  } catch (e) {
    throw e.toAppFailure(action: 'fetch', entity: 'PublicCatalog');
  }
}
