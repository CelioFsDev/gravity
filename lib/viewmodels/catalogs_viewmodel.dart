import 'package:gravity/core/auth/auth_controller.dart';
import 'package:gravity/core/auth/auth_guards.dart';
import 'package:gravity/data/repositories/catalogs_repository.dart';
import 'package:gravity/models/catalog.dart';
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
      throw Exception('Sem permissÃ£o para excluir catÃ¡logos.');
    }
    final catalogs = state.value ?? await repository.getCatalogs();
    final target = catalogs.firstWhere(
      (c) => c.id == id,
      orElse: () => throw Exception('CatÃ¡logo nÃ£o encontrado.'),
    );
    if (user != null &&
        target.ownerUid.isNotEmpty &&
        target.ownerUid != user.uid) {
      throw Exception('Sem permissÃ£o para excluir este catÃ¡logo.');
    }
    await repository.deleteCatalog(id);
    ref.invalidateSelf();
  }
}
