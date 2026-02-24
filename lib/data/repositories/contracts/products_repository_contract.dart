import 'dart:async';

import 'package:catalogo_ja/models/product.dart';

abstract class ProductsRepositoryContract {
  Future<List<Product>> getProducts();
  Future<List<Product>> getProductsByCategory(String categoryId);
  Future<void> addProduct(Product product);
  Future<void> updateProduct(Product product);
  Future<void> deleteProduct(String id);
  Future<void> clearAll();
  Future<Product?> getByRef(String ref);

  Stream<List<Product>> watchProducts();
  Stream<List<Product>> watchProductsByCategory(String categoryId);
}
