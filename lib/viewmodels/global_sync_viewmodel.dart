import 'package:catalogo_ja/viewmodels/categories_viewmodel.dart';
import 'package:catalogo_ja/viewmodels/products_viewmodel.dart';
import 'package:catalogo_ja/viewmodels/catalogs_viewmodel.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'global_sync_viewmodel.g.dart';

@riverpod
class GlobalSyncViewModel extends _$GlobalSyncViewModel {
  @override
  void build() {}

  /// Sobe todas as Categorias, Coleções, Produtos e Catálogos para a Nuvem
  Future<void> syncUpEverything() async {
    // 1. Sincroniza Categorias e Coleções
    await ref.read(categoriesViewModelProvider.notifier).syncAllToCloud();
    
    // 2. Sincroniza Produtos e Fotos (o processo mais pesado)
    await ref.read(productsViewModelProvider.notifier).syncAllToCloud();
    
    // 3. Sincroniza Catálogos (PDF e configs)
    await ref.read(catalogsViewModelProvider.notifier).syncAllToCloud();
  }

  /// Baixa todas as Categorias, Collections, Produtos e Catálogos da Nuvem para o Celular
  Future<void> syncDownEverything() async {
    // 1. Baixa Categorias
    await ref.read(categoriesViewModelProvider.notifier).syncFromCloud();
    
    // 2. Baixa Produtos e Fotos
    await ref.read(productsViewModelProvider.notifier).syncFromCloud();
    
    // 3. Baixa Catálogos
    await ref.read(catalogsViewModelProvider.notifier).syncFromCloud();
  }
}
