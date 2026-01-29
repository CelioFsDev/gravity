import 'dart:async';

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
  Future<List<Category>> getCategories() async =>
      _categoriesBox.values.toList();

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
  Future<void> reassignCategory(
    String oldCategoryId,
    String newCategoryId,
  ) async {
    final products = _productsBox.values
        .where((p) => p.categoryId == oldCategoryId)
        .toList();
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

@Riverpod(keepAlive: true)
CategoriesRepositoryContract categoriesRepository(CategoriesRepositoryRef ref) {
  final categoriesBox = Hive.box<Category>('categories');
  final productsBox = Hive.box<Product>('products');

  return HiveCategoriesRepository(categoriesBox, productsBox);
}
