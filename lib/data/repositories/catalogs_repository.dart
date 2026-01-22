import 'package:gravity/models/catalog.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'catalogs_repository.g.dart';

abstract class CatalogsRepository {
  Future<List<Catalog>> getCatalogs();
  Future<void> addCatalog(Catalog catalog);
  Future<void> updateCatalog(Catalog catalog);
  Future<void> deleteCatalog(String id);
  Future<bool> isSlugTaken(String slug, {String? excludeId});
  Future<Catalog?> getBySlug(String slug);
}

class HiveCatalogsRepository implements CatalogsRepository {
  final Box<Catalog> _catalogsBox;

  HiveCatalogsRepository(this._catalogsBox);

  @override
  Future<List<Catalog>> getCatalogs() async {
    return _catalogsBox.values.toList();
  }

  @override
  Future<Catalog?> getBySlug(String slug) async {
    try {
      return _catalogsBox.values.firstWhere((c) => c.slug == slug);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> addCatalog(Catalog catalog) async {
    await _catalogsBox.put(catalog.id, catalog);
  }

  @override
  Future<void> updateCatalog(Catalog catalog) async {
    await _catalogsBox.put(catalog.id, catalog);
  }

  @override
  Future<void> deleteCatalog(String id) async {
    await _catalogsBox.delete(id);
  }

  @override
  Future<bool> isSlugTaken(String slug, {String? excludeId}) async {
    return _catalogsBox.values.any((c) => c.slug == slug && c.id != excludeId);
  }
}

@Riverpod(keepAlive: true)
CatalogsRepository catalogsRepository(CatalogsRepositoryRef ref) {
  return HiveCatalogsRepository(Hive.box<Catalog>('catalogs'));
}
