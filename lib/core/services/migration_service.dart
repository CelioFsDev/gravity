import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gravity/models/catalog.dart';
import 'package:gravity/models/category.dart';
import 'package:gravity/models/product.dart';
import 'package:hive_flutter/hive_flutter.dart';

class MigrationProgress {
  final String stage;
  final int completed;
  final int total;
  final String message;

  const MigrationProgress({
    required this.stage,
    required this.completed,
    required this.total,
    required this.message,
  });
}

class MigrationService {
  static Future<void> migrateAll({
    FirebaseFirestore? firestore,
    required void Function(MigrationProgress) onProgress,
  }) async {
    final db = firestore ?? FirebaseFirestore.instance;

    final categories = Hive.box<Category>('categories').values.toList();
    onProgress(
      MigrationProgress(
        stage: 'categories',
        completed: 0,
        total: categories.length,
        message: 'Migrando categorias...',
      ),
    );
    await _upsertCollection<Category>(
      db.collection('categories'),
      categories,
      (c) => c.id,
      (c) => c.toFirestoreMap(),
      onProgress: (done) => onProgress(
        MigrationProgress(
          stage: 'categories',
          completed: done,
          total: categories.length,
          message: 'Migrando categorias...',
        ),
      ),
    );

    final products = Hive.box<Product>('products').values.toList();
    onProgress(
      MigrationProgress(
        stage: 'products',
        completed: 0,
        total: products.length,
        message: 'Migrando produtos...',
      ),
    );
    await _upsertCollection<Product>(
      db.collection('products'),
      products,
      (p) => p.id,
      (p) => p.toFirestoreMap(),
      onProgress: (done) => onProgress(
        MigrationProgress(
          stage: 'products',
          completed: done,
          total: products.length,
          message: 'Migrando produtos...',
        ),
      ),
    );

    final catalogs = Hive.box<Catalog>('catalogs').values.toList();
    onProgress(
      MigrationProgress(
        stage: 'catalogs',
        completed: 0,
        total: catalogs.length,
        message: 'Migrando catálogos...',
      ),
    );
    for (var i = 0; i < catalogs.length; i++) {
      final catalog = catalogs[i];
      await db
          .collection('catalogs')
          .doc(catalog.id)
          .set(catalog.toFirestoreMap(), SetOptions(merge: true));
      await _syncCatalogItems(db, catalog);
      onProgress(
        MigrationProgress(
          stage: 'catalogs',
          completed: i + 1,
          total: catalogs.length,
          message: 'Migrando catálogos...',
        ),
      );
    }
  }

  static Future<void> _upsertCollection<T>(
    CollectionReference<Map<String, dynamic>> collection,
    List<T> items,
    String Function(T) idFor,
    Map<String, dynamic> Function(T) mapper, {
    required void Function(int done) onProgress,
  }) async {
    var processed = 0;
    for (final item in items) {
      await collection.doc(idFor(item)).set(mapper(item), SetOptions(merge: true));
      processed += 1;
      onProgress(processed);
    }
  }

  static Future<void> _syncCatalogItems(
    FirebaseFirestore db,
    Catalog catalog,
  ) async {
    final itemsCol = db
        .collection('catalogs')
        .doc(catalog.id)
        .collection('items');
    final snapshot = await itemsCol.get();
    final existingIds = snapshot.docs.map((doc) => doc.id).toSet();
    final newIds = catalog.productIds.toSet();
    final batch = db.batch();
    var hasChanges = false;

    for (final docId in existingIds.difference(newIds)) {
      batch.delete(itemsCol.doc(docId));
      hasChanges = true;
    }

    for (var i = 0; i < catalog.productIds.length; i++) {
      final productId = catalog.productIds[i];
      final docRef = itemsCol.doc(productId);
      batch.set(
        docRef,
        {'productId': productId, 'order': i},
        SetOptions(merge: true),
      );
      hasChanges = true;
    }

    if (hasChanges) {
      await batch.commit();
    }
  }
}
