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
    await repository.deleteCatalog(id);
    ref.invalidateSelf();
  }
}
