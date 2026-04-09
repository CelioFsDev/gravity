import 'package:catalogo_ja/viewmodels/categories_viewmodel.dart';
import 'package:catalogo_ja/viewmodels/products_viewmodel.dart';
import 'package:catalogo_ja/viewmodels/catalogs_viewmodel.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:catalogo_ja/data/repositories/settings_repository.dart';
import 'package:catalogo_ja/data/repositories/products_repository.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter/foundation.dart';
part 'global_sync_viewmodel.g.dart';

@riverpod
class GlobalSyncViewModel extends _$GlobalSyncViewModel {
  @override
  void build() {}

  /// Sobe todas as Categorias, Coleções, Produtos e Catálogos para a Nuvem
  Future<void> syncUpEverything() async {
    final progressNotifier = ref.read(syncProgressProvider.notifier);
    progressNotifier.startSync('Iniciando upload...');
    
    try {
      // 1. Sincroniza Categorias e Coleções
      await ref.read(categoriesViewModelProvider.notifier).syncAllToCloud();
      
      // 2. Sincroniza Produtos e Fotos (o processo mais pesado)
      await ref.read(productsViewModelProvider.notifier).syncAllToCloud();
      
      // 3. Sincroniza Catálogos (PDF e configs)
      await ref.read(catalogsViewModelProvider.notifier).syncAllToCloud();
      
      progressNotifier.stopSync(message: 'Upload concluído!');
    } catch (e) {
      progressNotifier.stopSync(message: 'Erro no upload: $e');
      rethrow;
    }
  }

  /// Baixa todas as Categorias, Collections, Produtos e Catálogos da Nuvem para o Celular
  Future<void> syncDownEverything() async {
    final progressNotifier = ref.read(syncProgressProvider.notifier);
    progressNotifier.startSync('Buscando atualizações...');
    
    try {
      await _internalSyncDown((p, m) => progressNotifier.updateProgress(p, m));
      progressNotifier.stopSync(message: 'Sincronização concluída!');
    } catch (e) {
      progressNotifier.stopSync(message: 'Erro ao baixar: $e');
      rethrow;
    }
  }

  Future<void> _internalSyncDown(Function(double, String) onProgress) async {
    onProgress(0.1, 'Baixando Categorias...');
    // 1. Baixa Categorias
    await ref.read(categoriesViewModelProvider.notifier).syncFromCloud();
    
    // 2. Baixa Produtos e Fotos
    onProgress(0.3, 'Baixando Produtos...');
    await ref.read(productsViewModelProvider.notifier).syncFromCloud();
    
    // 3. Baixa Catálogos
    onProgress(0.5, 'Baixando Catálogos...');
    await ref.read(catalogsViewModelProvider.notifier).syncFromCloud();

    // 4. Verificação de Primeiro Acesso (Download Físico)
    final settingsRepo = ref.read(settingsRepositoryProvider);
    final settings = settingsRepo.getSettings();
    
    if (!settings.isInitialSyncCompleted) {
      onProgress(0.6, 'Preparando download de imagens offline...');
      
      final products = await ref.read(productsRepositoryProvider).getProducts();
      final urlsToDownload = <String>{};
      
      for (final p in products) {
        for (final img in p.images) {
          if (img.uri.startsWith('http')) {
            urlsToDownload.add(img.uri);
          }
        }
        for (final photo in p.photos) {
          if (photo.path.startsWith('http')) {
            urlsToDownload.add(photo.path);
          }
        }
      }

      final totalImages = urlsToDownload.length;
      int downloadedImages = 0;

      for (final url in urlsToDownload) {
        try {
          onProgress(
            0.6 + (0.4 * downloadedImages / (totalImages == 0 ? 1 : totalImages)), 
            'Salvando foto offline ($downloadedImages de $totalImages)...'
          );
          await DefaultCacheManager().downloadFile(url);
          downloadedImages++;
        } catch (e) {
          debugPrint('Erro ao baixar cache offline para $url: $e');
        }
      }

      await settingsRepo.saveSettings(settings.copyWith(isInitialSyncCompleted: true));
      onProgress(1.0, 'Configuração offline finalizada!');
    }
  }
}
