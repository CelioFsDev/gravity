import 'dart:async';

import 'package:catalogo_ja/viewmodels/tenant_viewmodel.dart';
import 'package:catalogo_ja/data/repositories/contracts/catalogs_repository_contract.dart';
import 'package:catalogo_ja/models/catalog.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'catalogs_repository.g.dart';

Stream<List<T>> _boxValuesStream<T>(Box<T> box) {
  return Stream<List<T>>.multi((controller) {
    controller.add(box.values.toList());
    final subscription = box.watch().listen((_) {
      controller.add(box.values.toList());
    });
    controller.onCancel = subscription.cancel;
  });
}

class HiveCatalogsRepository implements CatalogsRepositoryContract {
  final Box<Catalog> _catalogsBox;
  final String? _tenantId;

  HiveCatalogsRepository(this._catalogsBox, this._tenantId);

  Box<Catalog> get box => _catalogsBox;

  List<Catalog> _filter(Iterable<Catalog> items) {
    if (_tenantId == null) return [];
    return items.where((c) => c.tenantId == _tenantId).toList();
  }

  @override
  Future<List<Catalog>> getCatalogs() async => _filter(_catalogsBox.values);

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
    return _filter(_catalogsBox.values).any(
      (c) => c.slug == slug && (excludeId == null || c.id != excludeId),
    );
  }

  @override
  Future<Catalog?> getBySlug(String slug) async {
    try {
      return _filter(_catalogsBox.values).firstWhere((c) => c.slug == slug);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Catalog?> getByShareCode(String shareCode) async {
    try {
      return _filter(_catalogsBox.values).firstWhere(
        (c) => c.shareCode == shareCode && c.isPublic,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<List<Catalog>> watchCatalogs() {
    return _boxValuesStream(_catalogsBox).map((items) => _filter(items));
  }

  @override
  Future<void> clearAll() async => _catalogsBox.clear();
}

@Riverpod(keepAlive: true)
CatalogsRepositoryContract catalogsRepository(CatalogsRepositoryRef ref) {
  final catalogsBox = Hive.box<Catalog>('catalogs');
  final tenant = ref.watch(currentTenantProvider).valueOrNull;
  return HiveCatalogsRepository(catalogsBox, tenant?.id);
}
