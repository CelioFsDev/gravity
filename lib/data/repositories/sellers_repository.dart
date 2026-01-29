import 'dart:async';

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

@Riverpod(keepAlive: true)
SellersRepositoryContract sellersRepository(SellersRepositoryRef ref) {
  final sellersBox = Hive.box<Seller>('sellers');
  return HiveSellersRepository(sellersBox);
}
