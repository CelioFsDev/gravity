import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gravity/core/config/data_backend.dart';
import 'package:gravity/data/repositories/contracts/catalogs_repository_contract.dart';
import 'package:gravity/models/catalog.dart';
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

  HiveCatalogsRepository(this._catalogsBox);

  Box<Catalog> get box => _catalogsBox;

  @override
  Future<List<Catalog>> getCatalogs() async => _catalogsBox.values.toList();

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
    return _catalogsBox.values
        .any((c) => c.slug == slug && (excludeId == null || c.id != excludeId));
  }

  @override
  Future<Catalog?> getBySlug(String slug) async {
    try {
      return _catalogsBox.values.firstWhere((c) => c.slug == slug);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Catalog?> getByShareCode(String shareCode) async {
    try {
      return _catalogsBox.values
          .firstWhere((c) => c.shareCode == shareCode && c.isPublic);
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<List<Catalog>> watchCatalogs() => _boxValuesStream(_catalogsBox);
}

class CatalogsFirestoreRepository implements CatalogsRepositoryContract {
  final FirebaseFirestore _firestore;
  final CollectionReference<Map<String, dynamic>> _collection;

  CatalogsFirestoreRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _collection = (firestore ?? FirebaseFirestore.instance).collection('catalogs');

  CollectionReference<Map<String, dynamic>> _itemsCollection(String catalogId) {
    return _collection.doc(catalogId).collection('items');
  }

  Future<void> _persistItems(String catalogId, List<String> productIds) async {
    final itemsCol = _itemsCollection(catalogId);
    final batch = _firestore.batch();
    final snapshot = await itemsCol.get();
    final existingIds = snapshot.docs.map((doc) => doc.id).toSet();
    final newIds = productIds.toSet();
    var hasChanges = false;

    for (final docId in existingIds.difference(newIds)) {
      batch.delete(itemsCol.doc(docId));
      hasChanges = true;
    }

    for (var i = 0; i < productIds.length; i++) {
      final productId = productIds[i];
      final docRef = itemsCol.doc(productId);
      batch.set(
        docRef,
        {'productId': productId, 'order': i},
        SetOptions(merge: true),
      );
      hasChanges = true;
    }

    if (!hasChanges) return;
    await batch.commit();
  }

  Future<void> _deleteItems(String catalogId) async {
    final itemsCol = _itemsCollection(catalogId);
    final snapshot = await itemsCol.get();
    if (snapshot.docs.isEmpty) return;
    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  Catalog _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    return Catalog.fromFirestore(doc.id, doc.data());
  }

  @override
  Future<void> addCatalog(Catalog catalog) async {
    final docRef = _collection.doc(catalog.id);
    await docRef.set(catalog.toFirestoreMap());
    await _persistItems(catalog.id, catalog.productIds);
  }

  @override
  Future<void> updateCatalog(Catalog catalog) async {
    final docRef = _collection.doc(catalog.id);
    await docRef.set(catalog.toFirestoreMap());
    await _persistItems(catalog.id, catalog.productIds);
  }

  @override
  Future<void> deleteCatalog(String id) async {
    await _deleteItems(id);
    await _collection.doc(id).delete();
  }

  @override
  Future<List<Catalog>> getCatalogs() async {
    final snapshot = await _collection.get();
    return snapshot.docs.map(_fromDoc).toList();
  }

  @override
  Future<bool> isSlugTaken(String slug, {String? excludeId}) async {
    final snapshot = await _collection.where('slug', isEqualTo: slug).get();
    return snapshot.docs.any((doc) => doc.id != excludeId);
  }

  @override
  Future<Catalog?> getBySlug(String slug) async {
    final snapshot = await _collection.where('slug', isEqualTo: slug).limit(1).get();
    if (snapshot.docs.isEmpty) return null;
    return _fromDoc(snapshot.docs.first);
  }

  @override
  Future<Catalog?> getByShareCode(String shareCode) async {
    final snapshot = await _collection
        .where('shareCode', isEqualTo: shareCode)
        .where('isPublic', isEqualTo: true)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    return _fromDoc(snapshot.docs.first);
  }

  @override
  Stream<List<Catalog>> watchCatalogs() {
    return _collection.snapshots().map(
      (snapshot) => snapshot.docs.map(_fromDoc).toList(),
    );
  }
}

class HybridCatalogsRepository implements CatalogsRepositoryContract {
  final HiveCatalogsRepository _hive;
  final CatalogsFirestoreRepository _firestore;
  late final StreamSubscription<List<Catalog>> _subscription;

  HybridCatalogsRepository({
    required CatalogsFirestoreRepository firestore,
    required HiveCatalogsRepository hive,
  })  : _firestore = firestore,
        _hive = hive {
    _subscription = _firestore.watchCatalogs().listen(_handleRemote);
  }

  void _handleRemote(List<Catalog> remote) {
    _syncRemote(remote);
  }

  Future<void> _syncRemote(List<Catalog> remote) async {
    if (!_hive.box.isOpen) return;
    final remoteMap = {for (var catalog in remote) catalog.id: catalog};
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
  Future<List<Catalog>> getCatalogs() => _hive.getCatalogs();

  @override
  Future<void> addCatalog(Catalog catalog) async {
    await _firestore.addCatalog(catalog);
    await _hive.addCatalog(catalog);
  }

  @override
  Future<void> updateCatalog(Catalog catalog) async {
    await _firestore.updateCatalog(catalog);
    await _hive.updateCatalog(catalog);
  }

  @override
  Future<void> deleteCatalog(String id) async {
    await _firestore.deleteCatalog(id);
    await _hive.deleteCatalog(id);
  }

  @override
  Future<bool> isSlugTaken(String slug, {String? excludeId}) async {
    return await _firestore.isSlugTaken(slug, excludeId: excludeId);
  }

  @override
  Future<Catalog?> getBySlug(String slug) async {
    return await _firestore.getBySlug(slug);
  }

  @override
  Future<Catalog?> getByShareCode(String shareCode) async {
    return await _firestore.getByShareCode(shareCode);
  }

  @override
  Stream<List<Catalog>> watchCatalogs() => _hive.watchCatalogs();
}

@Riverpod(keepAlive: true)
CatalogsRepositoryContract catalogsRepository(CatalogsRepositoryRef ref) {
  final backend = ref.watch(dataBackendProvider);
  final catalogsBox = Hive.box<Catalog>('catalogs');

  final hiveRepo = HiveCatalogsRepository(catalogsBox);
  final firestoreRepo = CatalogsFirestoreRepository();

  switch (backend) {
    case DataBackend.hive:
      return hiveRepo;
    case DataBackend.firestore:
      return firestoreRepo;
    case DataBackend.hybrid:
      final hybrid = HybridCatalogsRepository(
        firestore: firestoreRepo,
        hive: hiveRepo,
      );
      ref.onDispose(hybrid.dispose);
      return hybrid;
  }
}
