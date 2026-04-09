import 'dart:async';

import 'package:catalogo_ja/viewmodels/tenant_viewmodel.dart';
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
  final String? _tenantId;

  HiveProductsRepository(this._productsBox, this._tenantId);

  Box<Product> get box => _productsBox;

  List<Product> _filter(Iterable<Product> items) {
    if (_tenantId == null) return [];
    return items.where((p) => p.tenantId == _tenantId).toList();
  }

  @override
  Future<List<Product>> getProducts() async => _filter(_productsBox.values);

  @override
  Future<Product?> getProduct(String id) async {
    final p = _productsBox.get(id);
    if (p != null && p.tenantId == _tenantId) return p;
    return null;
  }

  @override
  Future<List<Product>> getProductsByCategory(String categoryId) async {
    return _filter(_productsBox.values)
        .where((p) => p.categoryIds.contains(categoryId))
        .toList();
  }

  @override
  Future<void> addProduct(Product product, {Function(double, String)? onProgress}) async {
    await _productsBox.put(product.id, product);
  }

  @override
  Future<void> updateProduct(Product product, {Function(double, String)? onProgress}) async => 
      addProduct(product, onProgress: onProgress);

  @override
  Future<void> updateProductsBulk(List<Product> products, {Function(double, String)? onProgress}) async {
    final Map<String, Product> updates = {for (var p in products) p.id: p};
    await _productsBox.putAll(updates);
    
    if (onProgress != null) {
      onProgress(1.0, 'Produtos locais atualizados!');
    }
  }

  @override
  Future<void> deleteProduct(String id) async {
    await _productsBox.delete(id);
  }

  @override
  Future<void> clearAll() async {
    await _productsBox.clear();
  }

  @override
  Future<void> syncProductToCloud(Product product, {Function(double, String)? onProgress}) async {
    await addProduct(product);
  }

  @override
  Future<Product?> getByRef(String ref) async {
    try {
      return _filter(_productsBox.values).firstWhere(
        (p) => p.ref.toLowerCase().trim() == ref.toLowerCase().trim(),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<List<Product>> watchProducts() {
    return _boxValuesStream(_productsBox).map((items) => _filter(items));
  }

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
  final tenant = ref.watch(currentTenantProvider).valueOrNull;
  return HiveProductsRepository(productsBox, tenant?.id);
}
