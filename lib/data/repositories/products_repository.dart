import 'package:gravity/models/category.dart';
import 'package:gravity/models/product.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'products_repository.g.dart';

abstract class ProductsRepository {
  Future<List<Product>> getProducts();
  Future<void> addProduct(Product product);
  Future<void> updateProduct(Product product);
  Future<void> deleteProduct(String id);
  
  Future<List<Product>> getProductsByCategory(String categoryId);

  // Categories
  Future<List<Category>> getCategories();
  Future<void> addCategory(Category category);
  Future<void> updateCategory(Category category);
  Future<void> deleteCategory(String id);
  Future<void> reassignCategory(String oldCategoryId, String newCategoryId);
  Future<void> clearAll();
}

class HiveProductsRepository implements ProductsRepository {
  final Box<Product> _productsBox;
  final Box<Category> _categoriesBox;

  HiveProductsRepository(this._productsBox, this._categoriesBox);

  @override
  Future<List<Product>> getProducts() async {
    return _productsBox.values.toList();
  }
  
  @override
  Future<List<Product>> getProductsByCategory(String categoryId) async {
    return _productsBox.values.where((p) => p.categoryId == categoryId).toList();
  }

  @override
  Future<void> addProduct(Product product) async {
    await _productsBox.put(product.id, product);
  }

  @override
  Future<void> updateProduct(Product product) async {
    await _productsBox.put(product.id, product);
  }

  @override
  Future<void> deleteProduct(String id) async {
    await _productsBox.delete(id);
  }
  
  @override
  Future<List<Category>> getCategories() async {
    return _categoriesBox.values.toList();
  }
  
  @override
  Future<void> addCategory(Category category) async {
    await _categoriesBox.put(category.id, category);
  }
  
  @override
  Future<void> updateCategory(Category category) async {
    await _categoriesBox.put(category.id, category);
  }
  
  @override
  Future<void> deleteCategory(String id) async {
    await _categoriesBox.delete(id);
  }
  
  @override
  Future<void> reassignCategory(String oldCategoryId, String newCategoryId) async {
    final products = _productsBox.values.where((p) => p.categoryId == oldCategoryId).toList();
    for (var product in products) {
      final updated = product.copyWith(categoryId: newCategoryId);
      await _productsBox.put(product.id, updated);
    }
  }

  @override
  Future<void> clearAll() async {
    await _productsBox.clear();
    await _categoriesBox.clear();
  }
}

@Riverpod(keepAlive: true)
ProductsRepository productsRepository(ProductsRepositoryRef ref) {
  return HiveProductsRepository(
    Hive.box<Product>('products'),
    Hive.box<Category>('categories'),
  );
}
