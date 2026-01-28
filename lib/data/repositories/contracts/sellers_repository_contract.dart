import 'dart:async';

import 'package:gravity/models/seller.dart';

abstract class SellersRepositoryContract {
  Future<List<Seller>> getSellers();
  Future<void> saveSeller(Seller seller);
  Future<void> deleteSeller(String id);
  Future<Seller?> getSellerByWhatsapp(String whatsapp);

  Stream<List<Seller>> watchSellers();
}
