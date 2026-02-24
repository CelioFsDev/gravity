import 'dart:async';

import 'package:catalogo_ja/data/repositories/contracts/products_repository_contract.dart';
import 'package:catalogo_ja/models/product.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'products_repository.g.dart';

Stream<List<T>> _boxValuesStream<T>(Box<T> box) {
  return Stream<List<T>>.multi((controller) {
    controller.add(box.values.toList());
    final subscription = box.watch().listen((_) {
      controller.add(box.values.toList());
    });
    controller.onCancel = subscription.cancel;
  });
}

class HiveProductsRepository implements ProductsRepositoryContract {
  final Box<Product> _productsBox;

  HiveProductsRepository(this._productsBox);

  Box<Product> get box => _productsBox;

  @override
  Future<List<Product>> getProducts() async => _productsBox.values.toList();

  @override
  Future<List<Product>> getProductsByCategory(String categoryId) async {
    return _productsBox.values
        .where((p) => p.categoryIds.contains(categoryId))
        .toList();
  }

  @override
  Future<void> addProduct(Product product) async {
    await _productsBox.put(product.id, product);
  }

  @override
  Future<void> updateProduct(Product product) async => addProduct(product);

  @override
  Future<void> deleteProduct(String id) async {
    await _productsBox.delete(id);
  }

  @override
  Future<void> clearAll() async {
    await _productsBox.clear();
  }

  @override
  Future<Product?> getByRef(String ref) async {
    try {
      return _productsBox.values.firstWhere(
        (p) => p.ref.toLowerCase().trim() == ref.toLowerCase().trim(),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<List<Product>> watchProducts() => _boxValuesStream(_productsBox);

  @override
  Stream<List<Product>> watchProductsByCategory(String categoryId) {
    return watchProducts().map((products) {
      return products.where((p) => p.categoryIds.contains(categoryId)).toList();
    });
  }
}

@Riverpod(keepAlive: true)
ProductsRepositoryContract productsRepository(ProductsRepositoryRef ref) {
  final productsBox = Hive.box<Product>('products');
  return HiveProductsRepository(productsBox);
}
