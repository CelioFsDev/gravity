import 'dart:async';

import 'package:catalogo_ja/models/product.dart';

abstract class ProductsRepositoryContract {
  Future<List<Product>> getProducts();
  Future<List<Product>> getProductsByCategory(String categoryId);
  Future<void> addProduct(Product product, {Function(double, String)? onProgress});
  Future<void> updateProduct(Product product, {Function(double, String)? onProgress});
  Future<void> updateProductsBulk(List<Product> products, {Function(double, String)? onProgress});
  Future<void> deleteProduct(String id);
  Future<void> clearAll();
  Future<Product?> getByRef(String ref);

  Future<void> syncProductToCloud(Product product, {Function(double, String)? onProgress});

  Stream<List<Product>> watchProducts();
  Stream<List<Product>> watchProductsByCategory(String categoryId);
}
