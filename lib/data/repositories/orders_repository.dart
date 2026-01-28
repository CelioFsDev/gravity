import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:gravity/core/config/data_backend.dart';
import 'package:gravity/data/repositories/contracts/orders_repository_contract.dart';
import 'package:gravity/models/order.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'orders_repository.g.dart';

Stream<List<T>> _boxValuesStream<T>(Box<T> box) {
  return Stream<List<T>>.multi((controller) {
    controller.add(box.values.toList());
    final subscription = box.watch().listen((_) {
      controller.add(box.values.toList());
    });
    controller.onCancel = subscription.cancel;
  });
}

class HiveOrdersRepository implements OrdersRepositoryContract {
  final Box<Order> _box;

  HiveOrdersRepository(this._box);

  Box<Order> get box => _box;

  @override
  Future<List<Order>> getOrders() async => _box.values.toList();

  @override
  Future<void> addOrder(Order order) async {
    await _box.put(order.id, order);
  }

  @override
  Future<void> deleteOrder(String id) async {
    await _box.delete(id);
  }

  @override
  Future<void> clearOrders() async {
    await _box.clear();
  }

  @override
  Stream<List<Order>> watchOrders() => _boxValuesStream(_box);
}

class OrdersFirestoreRepository implements OrdersRepositoryContract {
  final FirebaseFirestore _firestore;
  final CollectionReference<Map<String, dynamic>> _collection;

  OrdersFirestoreRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _collection = (firestore ?? FirebaseFirestore.instance).collection('orders');

  Order _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    return Order.fromFirestore(doc.id, doc.data());
  }

  @override
  Future<List<Order>> getOrders() async {
    final snapshot = await _collection.get();
    return snapshot.docs.map(_fromDoc).toList();
  }

  @override
  Future<void> addOrder(Order order) async {
    await _collection.doc(order.id).set(order.toFirestoreMap());
  }

  @override
  Future<void> deleteOrder(String id) async {
    await _collection.doc(id).delete();
  }

  @override
  Future<void> clearOrders() async {
    final snapshot = await _collection.get();
    if (snapshot.docs.isEmpty) return;
    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  @override
  Stream<List<Order>> watchOrders() {
    return _collection.snapshots().map(
      (snapshot) => snapshot.docs.map(_fromDoc).toList(),
    );
  }
}

class HybridOrdersRepository implements OrdersRepositoryContract {
  final HiveOrdersRepository _hive;
  final OrdersFirestoreRepository _firestore;
  late final StreamSubscription<List<Order>> _subscription;

  HybridOrdersRepository({
    required OrdersFirestoreRepository firestore,
    required HiveOrdersRepository hive,
  })  : _firestore = firestore,
        _hive = hive {
    _subscription = _firestore.watchOrders().listen(_handleRemote);
  }

  void _handleRemote(List<Order> remote) {
    _syncRemote(remote);
  }

  Future<void> _syncRemote(List<Order> remote) async {
    if (!_hive.box.isOpen) return;
    final remoteMap = {for (var order in remote) order.id: order};
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
  Future<List<Order>> getOrders() => _hive.getOrders();

  @override
  Future<void> addOrder(Order order) async {
    await _firestore.addOrder(order);
    await _hive.addOrder(order);
  }

  @override
  Future<void> deleteOrder(String id) async {
    await _firestore.deleteOrder(id);
    await _hive.deleteOrder(id);
  }

  @override
  Future<void> clearOrders() async {
    await _firestore.clearOrders();
    await _hive.clearOrders();
  }

  @override
  Stream<List<Order>> watchOrders() => _hive.watchOrders();
}

@Riverpod(keepAlive: true)
OrdersRepositoryContract ordersRepository(OrdersRepositoryRef ref) {
  final backend = ref.watch(dataBackendProvider);
  final ordersBox = Hive.box<Order>('orders');

  final hiveRepo = HiveOrdersRepository(ordersBox);
  final firestoreRepo = OrdersFirestoreRepository();

  switch (backend) {
    case DataBackend.hive:
      return hiveRepo;
    case DataBackend.firestore:
      return firestoreRepo;
    case DataBackend.hybrid:
      final hybrid = HybridOrdersRepository(
        firestore: firestoreRepo,
        hive: hiveRepo,
      );
      ref.onDispose(hybrid.dispose);
      return hybrid;
  }
}
