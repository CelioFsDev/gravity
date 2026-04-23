import 'dart:async';

import 'package:catalogo_ja/viewmodels/tenant_viewmodel.dart';
import 'package:catalogo_ja/data/repositories/contracts/categories_repository_contract.dart';
import 'package:catalogo_ja/models/category.dart';
import 'package:catalogo_ja/models/product.dart';
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
  final String? Function() _getTenantId;

  HiveCategoriesRepository(this._categoriesBox, this._productsBox, this._getTenantId);

  Box<Category> get box => _categoriesBox;

  List<Category> _filter(Iterable<Category> items) {
    final tenantId = _getTenantId();
    if (tenantId == null) return [];
    return items.where((c) => c.tenantId == tenantId).toList();
  }

  Category _withTenant(Category category) {
    final tenantId = _getTenantId();
    if (tenantId == null || tenantId.isEmpty || category.tenantId == tenantId) {
      return category;
    }
    if ((category.tenantId ?? '').isEmpty) {
      return category.copyWith(tenantId: tenantId);
    }
    return category;
  }

  @override
  Future<List<Category>> getCategories() async =>
      _filter(_categoriesBox.values);

  @override
  Future<void> addCategory(Category category) async {
    final categoryToSave = _withTenant(category);
    await _categoriesBox.put(categoryToSave.id, categoryToSave);
  }

  @override
  Future<void> updateCategory(Category category) async {
    final categoryToSave = _withTenant(category);
    await _categoriesBox.put(categoryToSave.id, categoryToSave);
  }

  @override
  Future<void> updateCategoriesBulk(List<Category> categories) async {
    final Map<String, Category> updates = {
      for (var c in categories) _withTenant(c).id: _withTenant(c),
    };
    await _categoriesBox.putAll(updates);
  }

  @override
  Future<void> deleteCategory(String id) async {
    await _categoriesBox.delete(id);
  }

  @override
  Future<Category?> getBySlug(String slug) async {
    try {
      return _filter(_categoriesBox.values).firstWhere(
        (c) => (c.slug ?? '').toLowerCase().trim() == slug.toLowerCase().trim(),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> reassignCategory(
    String oldCategoryId,
    String newCategoryId,
  ) async {
    final products = _productsBox.values
        .where((p) => p.categoryIds.contains(oldCategoryId))
        .toList();
    for (var product in products) {
      final updatedCategories = List<String>.from(product.categoryIds);
      updatedCategories.remove(oldCategoryId);
      if (newCategoryId.isNotEmpty) {
        updatedCategories.add(newCategoryId);
      }
      await _productsBox.put(
        product.id,
        product.copyWith(categoryIds: updatedCategories),
      );
    }
  }

  @override
  Future<void> clearAll() async {
    await _categoriesBox.clear();
  }

  @override
  Stream<List<Category>> watchCategories() {
    return _boxValuesStream(_categoriesBox).map((items) => _filter(items));
  }
}

@Riverpod(keepAlive: true)
CategoriesRepositoryContract categoriesRepository(CategoriesRepositoryRef ref) {
  final categoriesBox = Hive.box<Category>('categories');
  final productsBox = Hive.box<Product>('products');

  return HiveCategoriesRepository(
    categoriesBox, 
    productsBox, 
    () => ref.read(currentTenantProvider).valueOrNull?.id,
  );
}
