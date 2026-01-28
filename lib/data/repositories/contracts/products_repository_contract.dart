import 'dart:async';

import 'package:gravity/models/product.dart';

abstract class ProductsRepositoryContract {
  Future<List<Product>> getProducts();
  Future<List<Product>> getProductsByCategory(String categoryId);
  Future<void> addProduct(Product product);
  Future<void> updateProduct(Product product);
  Future<void> deleteProduct(String id);

  Stream<List<Product>> watchProducts();
  Stream<List<Product>> watchProductsByCategory(String categoryId);
}
