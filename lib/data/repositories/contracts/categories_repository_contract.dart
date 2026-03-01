import 'dart:async';

import 'package:catalogo_ja/models/category.dart';

abstract class CategoriesRepositoryContract {
  Future<List<Category>> getCategories();
  Future<void> addCategory(Category category);
  Future<void> updateCategory(Category category);
  Future<void> deleteCategory(String id);
  Future<void> reassignCategory(String oldCategoryId, String newCategoryId);
  Future<Category?> getBySlug(String slug);
  Future<void> clearAll();

  Stream<List<Category>> watchCategories();
}
