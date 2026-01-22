import 'package:gravity/models/seller.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'sellers_repository.g.dart';

abstract class SellersRepository {
  Future<List<Seller>> getSellers();
  Future<void> saveSeller(Seller seller);
  Future<void> deleteSeller(String id);
  Seller? getSellerByWhatsapp(String whatsapp);
}

class HiveSellersRepository implements SellersRepository {
  final Box<Seller> _box;

  HiveSellersRepository(this._box);

  @override
  Future<List<Seller>> getSellers() async {
    return _box.values.toList();
  }

  @override
  Future<void> saveSeller(Seller seller) async {
    await _box.put(seller.id, seller);
  }

  @override
  Future<void> deleteSeller(String id) async {
    await _box.delete(id);
  }

  @override
  Seller? getSellerByWhatsapp(String whatsapp) {
    try {
      return _box.values.firstWhere((s) => s.whatsapp == whatsapp);
    } catch (e) {
      return null;
    }
  }
}

@Riverpod(keepAlive: true)
SellersRepository sellersRepository(SellersRepositoryRef ref) {
  return HiveSellersRepository(Hive.box<Seller>('sellers'));
}
