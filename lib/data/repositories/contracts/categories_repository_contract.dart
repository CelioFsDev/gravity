import 'dart:async';

import 'package:gravity/models/category.dart';

abstract class CategoriesRepositoryContract {
  Future<List<Category>> getCategories();
  Future<void> addCategory(Category category);
  Future<void> updateCategory(Category category);
  Future<void> deleteCategory(String id);
  Future<void> reassignCategory(String oldCategoryId, String newCategoryId);
  Future<void> clearAll();

  Stream<List<Category>> watchCategories();
}
