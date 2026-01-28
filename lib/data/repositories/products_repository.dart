import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gravity/core/config/data_backend.dart';
import 'package:gravity/data/repositories/contracts/products_repository_contract.dart';
import 'package:gravity/models/product.dart';
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
    return _productsBox.values.where((p) => p.categoryId == categoryId).toList();
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
  Stream<List<Product>> watchProducts() => _boxValuesStream(_productsBox);

  @override
  Stream<List<Product>> watchProductsByCategory(String categoryId) {
    return watchProducts().map((products) {
      return products.where((p) => p.categoryId == categoryId).toList();
    });
  }
}

class ProductsFirestoreRepository implements ProductsRepositoryContract {
  final CollectionReference<Map<String, dynamic>> _collection;

  ProductsFirestoreRepository({FirebaseFirestore? firestore})
      : _collection = (firestore ?? FirebaseFirestore.instance)
            .collection('products');

  Product _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    return Product.fromFirestore(doc.id, doc.data());
  }

  Query<Map<String, dynamic>> _byCategory(String categoryId) {
    return _collection.where('categoryId', isEqualTo: categoryId);
  }

  @override
  Future<void> addProduct(Product product) async {
    await _collection.doc(product.id).set(product.toFirestoreMap());
  }

  @override
  Future<void> updateProduct(Product product) async {
    await _collection.doc(product.id).set(product.toFirestoreMap());
  }

  @override
  Future<void> deleteProduct(String id) async {
    await _collection.doc(id).delete();
  }

  @override
  Future<List<Product>> getProducts() async {
    final snapshot = await _collection.get();
    return snapshot.docs.map(_fromDoc).toList();
  }

  @override
  Future<List<Product>> getProductsByCategory(String categoryId) async {
    final snapshot = await _byCategory(categoryId).get();
    return snapshot.docs.map(_fromDoc).toList();
  }

  @override
  Stream<List<Product>> watchProducts() {
    return _collection.snapshots().map(
      (snapshot) => snapshot.docs.map(_fromDoc).toList(),
    );
  }

  @override
  Stream<List<Product>> watchProductsByCategory(String categoryId) {
    return _byCategory(categoryId).snapshots().map(
      (snapshot) => snapshot.docs.map(_fromDoc).toList(),
    );
  }
}

class HybridProductsRepository implements ProductsRepositoryContract {
  final HiveProductsRepository _hive;
  final ProductsFirestoreRepository _firestore;
  late final StreamSubscription<List<Product>> _subscription;

  HybridProductsRepository({
    required ProductsFirestoreRepository firestore,
    required HiveProductsRepository hive,
  })  : _firestore = firestore,
        _hive = hive {
    _subscription = _firestore.watchProducts().listen(_handleRemote);
  }

  void _handleRemote(List<Product> remote) {
    _syncRemote(remote);
  }

  Future<void> _syncRemote(List<Product> remote) async {
    if (!_hive.box.isOpen) return;
    final remoteMap = {for (var product in remote) product.id: product};
    final localIds = _hive.box.keys.cast<String>().toSet();
    final remoteIds = remoteMap.keys.toSet();
    await _hive.box.putAll(remoteMap);
    final toDelete = localIds.difference(remoteIds);
    if (toDelete.isNotEmpty) {
      await _hive.box.deleteAll(toDelete);
    }
  }

  void dispose() {
    _subscription.cancel();
  }

  @override
  Future<List<Product>> getProducts() => _hive.getProducts();

  @override
  Future<List<Product>> getProductsByCategory(String categoryId) =>
      _hive.getProductsByCategory(categoryId);

  @override
  Future<void> addProduct(Product product) async {
    await _firestore.addProduct(product);
    await _hive.addProduct(product);
  }

  @override
  Future<void> updateProduct(Product product) async {
    await _firestore.updateProduct(product);
    await _hive.updateProduct(product);
  }

  @override
  Future<void> deleteProduct(String id) async {
    await _firestore.deleteProduct(id);
    await _hive.deleteProduct(id);
  }

  @override
  Stream<List<Product>> watchProducts() => _hive.watchProducts();

  @override
  Stream<List<Product>> watchProductsByCategory(String categoryId) =>
      _hive.watchProductsByCategory(categoryId);
}

@Riverpod(keepAlive: true)
ProductsRepositoryContract productsRepository(ProductsRepositoryRef ref) {
  final backend = ref.watch(dataBackendProvider);
  final productsBox = Hive.box<Product>('products');

  final hiveRepo = HiveProductsRepository(productsBox);
  final firestoreRepo = ProductsFirestoreRepository();

  switch (backend) {
    case DataBackend.hive:
      return hiveRepo;
    case DataBackend.firestore:
      return firestoreRepo;
    case DataBackend.hybrid:
      final hybrid = HybridProductsRepository(
        firestore: firestoreRepo,
        hive: hiveRepo,
      );
      ref.onDispose(hybrid.dispose);
      return hybrid;
  }
}
