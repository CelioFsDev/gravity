import 'package:catalogo_ja/core/auth/auth_controller.dart';
import 'package:catalogo_ja/core/auth/auth_guards.dart';
import 'package:catalogo_ja/data/repositories/catalogs_repository.dart';
import 'package:catalogo_ja/models/catalog.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'catalogs_viewmodel.g.dart';

@riverpod
class CatalogsViewModel extends _$CatalogsViewModel {
  @override
  FutureOr<List<Catalog>> build() async {
    final repository = ref.watch(catalogsRepositoryProvider);
    return repository.getCatalogs();
  }

  Future<void> deleteCatalog(String id) async {
    final repository = ref.read(catalogsRepositoryProvider);
    final user = ref.read(currentUserProvider);
    if (!isLoggedIn(user)) {
      throw Exception('Sem permiss\u00e3o para excluir cat\u00e1logos.');
    }
    final catalogs = state.value ?? await repository.getCatalogs();
    final target = catalogs.firstWhere(
      (c) => c.id == id,
      orElse: () => throw Exception('Cat\u00e1logo n\u00e3o encontrado.'),
    );
    if (user != null &&
        target.ownerUid.isNotEmpty &&
        target.ownerUid != user.uid) {
      throw Exception('Sem permiss\u00e3o para excluir este cat\u00e1logo.');
    }
    await repository.deleteCatalog(id);
    ref.invalidateSelf();
  }
}

