import 'dart:async';

import 'package:catalogo_ja/models/catalog.dart';

abstract class CatalogsRepositoryContract {
  Future<List<Catalog>> getCatalogs();
  Future<void> addCatalog(Catalog catalog);
  Future<void> updateCatalog(Catalog catalog);
  Future<void> deleteCatalog(String id);
  Future<bool> isSlugTaken(String slug, {String? excludeId});
  Future<Catalog?> getBySlug(String slug);
  Future<Catalog?> getByShareCode(String shareCode);

  Stream<List<Catalog>> watchCatalogs();
}
