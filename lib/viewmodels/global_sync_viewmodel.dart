import 'package:catalogo_ja/models/product.dart';
import 'package:catalogo_ja/viewmodels/catalogs_viewmodel.dart';
import 'package:catalogo_ja/viewmodels/categories_viewmodel.dart';
import 'package:catalogo_ja/viewmodels/products_viewmodel.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import 'package:catalogo_ja/data/repositories/settings_repository.dart';
import 'package:catalogo_ja/data/repositories/products_repository.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter/foundation.dart';
part 'global_sync_viewmodel.g.dart';

@riverpod
class GlobalSyncViewModel extends _$GlobalSyncViewModel {
  @override
  void build() {}

  /// Sincronização automática em segundo plano (apenas se estiver no Wi-Fi)
  Future<void> performSilentWifiSync() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();

      // No connectivity_plus v6+, o resultado é uma lista
      final isWifi = connectivityResult.contains(ConnectivityResult.wifi);

      if (!isWifi) {
        debugPrint('📡 Auto-sync ignorado: Não está no Wi-Fi.');
        return;
      }

      debugPrint('🚀 Iniciando sincronização silenciosa no Wi-Fi...');

      final products = await ref.read(productsRepositoryProvider).getProducts();
      await _downloadImagesInParallel(products, onProgress: null);

      debugPrint('✅ Auto-sync Wi-Fi concluído.');
    } catch (e) {
      debugPrint('❌ Erro no auto-sync Wi-Fi: $e');
    }
  }

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
      await _downloadImagesInParallel(
        products,
        onProgress: (progress, message) =>
            onProgress(0.6 + (0.4 * progress), message),
      );

      await settingsRepo.saveSettings(
        settings.copyWith(isInitialSyncCompleted: true),
      );
      onProgress(1.0, 'Configuração offline finalizada!');
    }
  }

  /// Baixa imagens em paralelo para acelerar a sincronização
  Future<void> _downloadImagesInParallel(
    List<Product> products, {
    required Function(double, String)? onProgress,
  }) async {
    final urlsToDownload = <String>{};

    for (final p in products) {
      for (final img in p.images) {
        if (img.uri.startsWith('http')) urlsToDownload.add(img.uri);
      }
      for (final photo in p.photos) {
        if (photo.path.startsWith('http')) urlsToDownload.add(photo.path);
      }
    }

    if (urlsToDownload.isEmpty) return;

    final total = urlsToDownload.length;
    int completed = 0;
    const int maxConcurrent = 5; // Download de 5 fotos por vez

    final List<String> urlList = urlsToDownload.toList();

    for (int i = 0; i < urlList.length; i += maxConcurrent) {
      final chunk = urlList.skip(i).take(maxConcurrent);

      await Future.wait(
        chunk.map((url) async {
          try {
            // Apenas baixa se não estiver em cache
            final fileInfo = await DefaultCacheManager().getFileFromCache(url);
            if (fileInfo == null) {
              await DefaultCacheManager()
                  .downloadFile(url)
                  .timeout(const Duration(seconds: 20));
            }
          } catch (e) {
            debugPrint('⚠️ Erro ao baixar imagem $url: $e');
          } finally {
            completed++;
            if (onProgress != null) {
              onProgress(
                completed / total,
                'Salvando foto offline ($completed de $total)...',
              );
            }
          }
        }),
      );
    }
  }
}
