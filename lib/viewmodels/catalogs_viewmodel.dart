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
      throw Exception('Sem permissão para excluir catálogos.');
    }
    final catalogs = state.value ?? await repository.getCatalogs();
    final target = catalogs.firstWhere(
      (c) => c.id == id,
      orElse: () => throw Exception('Catálogo não encontrado.'),
    );
    if (user != null &&
        target.ownerUid.isNotEmpty &&
        target.ownerUid != user.uid) {
      throw Exception('Sem permissão para excluir este catálogo.');
    }
    await repository.deleteCatalog(id);
    ref.invalidateSelf();
  }
}

