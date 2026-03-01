import 'package:catalogo_ja/data/repositories/catalogs_repository.dart';
import 'package:catalogo_ja/models/catalog.dart';
import 'package:catalogo_ja/core/error/app_failure.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'catalogs_viewmodel.g.dart';

@riverpod
class CatalogsViewModel extends _$CatalogsViewModel {
  @override
  FutureOr<List<Catalog>> build() async {
    try {
      final repository = ref.watch(catalogsRepositoryProvider);
      return await repository.getCatalogs();
    } catch (e) {
      throw e.toAppFailure(action: 'build', entity: 'Catalogs');
    }
  }

  Future<void> deleteCatalog(String id) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      try {
        final repository = ref.read(catalogsRepositoryProvider);
        await repository.deleteCatalog(id);
        ref.invalidateSelf();
        return state.value ?? [];
      } catch (e) {
        throw e.toAppFailure(action: 'deleteCatalog', entity: 'Catalog');
      }
    });
  }
}
