import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gravity/core/config/data_backend.dart';
import 'package:gravity/data/repositories/contracts/categories_repository_contract.dart';
import 'package:gravity/models/category.dart';
import 'package:gravity/models/product.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'categories_repository.g.dart';

Stream<List<T>> _boxValuesStream<T>(Box<T> box) {
  return Stream<List<T>>.multi((controller) {
    controller.add(box.values.toList());
    final subscription = box.watch().listen((_) {
      controller.add(box.values.toList());
    });
    controller.onCancel = subscription.cancel;
  });
}

class HiveCategoriesRepository implements CategoriesRepositoryContract {
  final Box<Category> _categoriesBox;
  final Box<Product> _productsBox;

  HiveCategoriesRepository(this._categoriesBox, this._productsBox);

  Box<Category> get box => _categoriesBox;

  @override
  Future<List<Category>> getCategories() async => _categoriesBox.values.toList();

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
      await _productsBox.put(
        product.id,
        product.copyWith(categoryId: newCategoryId),
      );
    }
  }

  @override
  Future<void> clearAll() async {
    await _categoriesBox.clear();
  }

  @override
  Stream<List<Category>> watchCategories() => _boxValuesStream(_categoriesBox);
}

class CategoriesFirestoreRepository implements CategoriesRepositoryContract {
  final FirebaseFirestore _firestore;
  final CollectionReference<Map<String, dynamic>> _collection;
  final CollectionReference<Map<String, dynamic>> _productsCollection;

  CategoriesFirestoreRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _collection = (firestore ?? FirebaseFirestore.instance).collection('categories'),
        _productsCollection = (firestore ?? FirebaseFirestore.instance).collection('products');

  Category _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    return Category.fromFirestore(doc.id, doc.data());
  }

  Query<Map<String, dynamic>> _byCategory(String categoryId) {
    return _productsCollection.where('categoryId', isEqualTo: categoryId);
  }

  @override
  Future<void> addCategory(Category category) async {
    await _collection.doc(category.id).set(category.toFirestoreMap());
  }

  @override
  Future<void> updateCategory(Category category) async {
    await _collection.doc(category.id).set(category.toFirestoreMap());
  }

  @override
  Future<void> deleteCategory(String id) async {
    await _collection.doc(id).delete();
  }

  @override
  Future<List<Category>> getCategories() async {
    final snapshot = await _collection.get();
    return snapshot.docs.map(_fromDoc).toList();
  }

  @override
  Future<void> reassignCategory(String oldCategoryId, String newCategoryId) async {
    final snapshot = await _byCategory(oldCategoryId).get();
    if (snapshot.docs.isEmpty) return;
    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {'categoryId': newCategoryId});
    }
    await batch.commit();
  }

  @override
  Future<void> clearAll() async {
    final snapshot = await _collection.get();
    if (snapshot.docs.isEmpty) return;
    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  @override
  Stream<List<Category>> watchCategories() {
    return _collection.snapshots().map(
          (snapshot) => snapshot.docs.map(_fromDoc).toList(),
        );
  }
}

class HybridCategoriesRepository implements CategoriesRepositoryContract {
  final HiveCategoriesRepository _hive;
  final CategoriesFirestoreRepository _firestore;
  late final StreamSubscription<List<Category>> _subscription;

  HybridCategoriesRepository({
    required CategoriesFirestoreRepository firestore,
    required HiveCategoriesRepository hive,
  })  : _firestore = firestore,
        _hive = hive {
    _subscription = _firestore.watchCategories().listen(_handleRemote);
  }

  void _handleRemote(List<Category> remote) {
    _syncRemote(remote);
  }

  Future<void> _syncRemote(List<Category> remote) async {
    if (!_hive.box.isOpen) return;
    final remoteMap = {for (var category in remote) category.id: category};
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
  Future<List<Category>> getCategories() => _hive.getCategories();

  @override
  Future<void> addCategory(Category category) async {
    await _firestore.addCategory(category);
    await _hive.addCategory(category);
  }

  @override
  Future<void> updateCategory(Category category) async {
    await _firestore.updateCategory(category);
    await _hive.updateCategory(category);
  }

  @override
  Future<void> deleteCategory(String id) async {
    await _firestore.deleteCategory(id);
    await _hive.deleteCategory(id);
  }

  @override
  Future<void> reassignCategory(String oldCategoryId, String newCategoryId) async {
    await _firestore.reassignCategory(oldCategoryId, newCategoryId);
    await _hive.reassignCategory(oldCategoryId, newCategoryId);
  }

  @override
  Future<void> clearAll() async {
    await _firestore.clearAll();
    await _hive.clearAll();
  }

  @override
  Stream<List<Category>> watchCategories() => _hive.watchCategories();
}

@Riverpod(keepAlive: true)
CategoriesRepositoryContract categoriesRepository(CategoriesRepositoryRef ref) {
  final backend = ref.watch(dataBackendProvider);
  final categoriesBox = Hive.box<Category>('categories');
  final productsBox = Hive.box<Product>('products');

  final hiveRepo = HiveCategoriesRepository(categoriesBox, productsBox);
  final firestoreRepo = CategoriesFirestoreRepository();

  switch (backend) {
    case DataBackend.hive:
      return hiveRepo;
    case DataBackend.firestore:
      return firestoreRepo;
    case DataBackend.hybrid:
      final hybrid = HybridCategoriesRepository(
        firestore: firestoreRepo,
        hive: hiveRepo,
      );
      ref.onDispose(hybrid.dispose);
      return hybrid;
  }
}
