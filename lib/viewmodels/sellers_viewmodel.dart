import 'package:gravity/data/repositories/sellers_repository.dart';
import 'package:gravity/models/seller.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

part 'sellers_viewmodel.g.dart';

@riverpod
class SellersViewModel extends _$SellersViewModel {
  @override
  FutureOr<List<Seller>> build() async {
    final repository = ref.watch(sellersRepositoryProvider);
    return await repository.getSellers();
  }

  Future<void> createSeller({
    required String name,
    required String whatsapp,
    bool isActive = true,
  }) async {
    final repository = ref.read(sellersRepositoryProvider);
    
    // Validate unique whatsapp
    final existing = repository.getSellerByWhatsapp(whatsapp);
    if (existing != null) {
      throw Exception('Já existe uma vendedora com este WhatsApp.');
    }

    final newSeller = Seller(
      id: const Uuid().v4(),
      name: name,
      whatsapp: whatsapp,
      isActive: isActive,
      createdAt: DateTime.now(),
    );

    await repository.saveSeller(newSeller);
    
    // Refresh list
    ref.invalidateSelf();
    await future;
  }

  Future<void> updateSeller({
    required String id,
    String? name,
    String? whatsapp,
    bool? isActive,
  }) async {
    final repository = ref.read(sellersRepositoryProvider);
    final sellers = await repository.getSellers();
    final index = sellers.indexWhere((s) => s.id == id);
    if (index == -1) throw Exception('Vendedora não encontrada.');

    final currentSeller = sellers[index];

    // Validate unique whatsapp if changing
    if (whatsapp != null && whatsapp != currentSeller.whatsapp) {
       final existing = repository.getSellerByWhatsapp(whatsapp);
       if (existing != null && existing.id != id) {
         throw Exception('Já existe uma vendedora com este WhatsApp.');
       }
    }

    final updatedSeller = currentSeller.copyWith(
      name: name,
      whatsapp: whatsapp,
      isActive: isActive,
    );

    await repository.saveSeller(updatedSeller);
    
    ref.invalidateSelf();
    await future;
  }

  Future<void> deleteSeller(String id) async {
    final repository = ref.read(sellersRepositoryProvider);
    await repository.deleteSeller(id);
    ref.invalidateSelf();
    await future;
  }

  Future<void> toggleActive(String id) async {
    final repository = ref.read(sellersRepositoryProvider);
    final sellers = await repository.getSellers();
    final seller = sellers.firstWhere((s) => s.id == id);
    
    final updatedSeller = seller.copyWith(isActive: !seller.isActive);
    await repository.saveSeller(updatedSeller);
    
    ref.invalidateSelf();
    await future;
  }
}
