import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gravity/core/config/data_backend.dart';
import 'package:gravity/data/repositories/contracts/sellers_repository_contract.dart';
import 'package:gravity/models/seller.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'sellers_repository.g.dart';

Stream<List<T>> _boxValuesStream<T>(Box<T> box) {
  return Stream<List<T>>.multi((controller) {
    controller.add(box.values.toList());
    final subscription = box.watch().listen((_) {
      controller.add(box.values.toList());
    });
    controller.onCancel = subscription.cancel;
  });
}

class HiveSellersRepository implements SellersRepositoryContract {
  final Box<Seller> _box;

  HiveSellersRepository(this._box);

  Box<Seller> get box => _box;

  @override
  Future<List<Seller>> getSellers() async => _box.values.toList();

  @override
  Future<void> saveSeller(Seller seller) async {
    await _box.put(seller.id, seller);
  }

  @override
  Future<void> deleteSeller(String id) async {
    await _box.delete(id);
  }

  @override
  Future<Seller?> getSellerByWhatsapp(String whatsapp) async {
    try {
      return _box.values.firstWhere((s) => s.whatsapp == whatsapp);
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<List<Seller>> watchSellers() => _boxValuesStream(_box);
}

class SellersFirestoreRepository implements SellersRepositoryContract {
  final CollectionReference<Map<String, dynamic>> _collection;
  final FirebaseFirestore _firestore;

  SellersFirestoreRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _collection = (firestore ?? FirebaseFirestore.instance).collection('sellers');

  Seller _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    return Seller.fromFirestore(doc.id, doc.data());
  }

  @override
  Future<List<Seller>> getSellers() async {
    final snapshot = await _collection.get();
    return snapshot.docs.map(_fromDoc).toList();
  }

  @override
  Future<void> saveSeller(Seller seller) async {
    await _collection.doc(seller.id).set(seller.toFirestoreMap());
  }

  @override
  Future<void> deleteSeller(String id) async {
    await _collection.doc(id).delete();
  }

  @override
  Future<Seller?> getSellerByWhatsapp(String whatsapp) async {
    final snapshot = await _collection.where('whatsapp', isEqualTo: whatsapp).limit(1).get();
    if (snapshot.docs.isEmpty) return null;
    return _fromDoc(snapshot.docs.first);
  }

  @override
  Stream<List<Seller>> watchSellers() {
    return _collection.snapshots().map(
      (snapshot) => snapshot.docs.map(_fromDoc).toList(),
    );
  }
}

class HybridSellersRepository implements SellersRepositoryContract {
  final HiveSellersRepository _hive;
  final SellersFirestoreRepository _firestore;
  late final StreamSubscription<List<Seller>> _subscription;

  HybridSellersRepository({
    required SellersFirestoreRepository firestore,
    required HiveSellersRepository hive,
  })  : _firestore = firestore,
        _hive = hive {
    _subscription = _firestore.watchSellers().listen(_handleRemote);
  }

  void _handleRemote(List<Seller> remote) {
    _syncRemote(remote);
  }

  Future<void> _syncRemote(List<Seller> remote) async {
    if (!_hive.box.isOpen) return;
    final remoteMap = {for (var seller in remote) seller.id: seller};
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
  Future<List<Seller>> getSellers() => _hive.getSellers();

  @override
  Future<void> saveSeller(Seller seller) async {
    await _firestore.saveSeller(seller);
    await _hive.saveSeller(seller);
  }

  @override
  Future<void> deleteSeller(String id) async {
    await _firestore.deleteSeller(id);
    await _hive.deleteSeller(id);
  }

  @override
  Future<Seller?> getSellerByWhatsapp(String whatsapp) =>
      _firestore.getSellerByWhatsapp(whatsapp);

  @override
  Stream<List<Seller>> watchSellers() => _hive.watchSellers();
}

@Riverpod(keepAlive: true)
SellersRepositoryContract sellersRepository(SellersRepositoryRef ref) {
  final backend = ref.watch(dataBackendProvider);
  final sellersBox = Hive.box<Seller>('sellers');

  final hiveRepo = HiveSellersRepository(sellersBox);
  final firestoreRepo = SellersFirestoreRepository();

  switch (backend) {
    case DataBackend.hive:
      return hiveRepo;
    case DataBackend.firestore:
      return firestoreRepo;
    case DataBackend.hybrid:
      final hybrid = HybridSellersRepository(
        firestore: firestoreRepo,
        hive: hiveRepo,
      );
      ref.onDispose(hybrid.dispose);
      return hybrid;
  }
}
