import 'dart:io';
import 'package:catalogo_ja/core/services/catalogo_ja_package_service.dart';
import 'package:catalogo_ja/core/services/export_import_service.dart';
import 'package:catalogo_ja/data/repositories/settings_repository.dart';
import 'package:catalogo_ja/models/product.dart';
import 'package:catalogo_ja/data/repositories/contracts/products_repository_contract.dart';
import 'package:catalogo_ja/data/repositories/contracts/categories_repository_contract.dart';
import 'package:catalogo_ja/data/repositories/contracts/catalogs_repository_contract.dart';
import 'package:catalogo_ja/data/repositories/products_repository.dart';
import 'package:catalogo_ja/data/repositories/categories_repository.dart';
import 'package:catalogo_ja/data/repositories/catalogs_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'system_backup_service.g.dart';

@Riverpod(keepAlive: true)
SystemBackupService systemBackupService(SystemBackupServiceRef ref) {
  return SystemBackupService(
    ref.read(catalogoJaPackageServiceProvider),
    ref.read(exportImportServiceProvider),
    ref.read(settingsRepositoryProvider),
    ref.read(productsRepositoryProvider),
    ref.read(categoriesRepositoryProvider),
    ref.read(catalogsRepositoryProvider),
  );
}

class SystemBackupService {
  final CatalogoJaPackageService _packageService;
  final ExportImportService _exportImportService;
  final SettingsRepository _settingsRepo;
  final ProductsRepositoryContract _productsRepo;
  final CategoriesRepositoryContract _categoriesRepo;
  final CatalogsRepositoryContract _catalogsRepo;

  SystemBackupService(
    this._packageService,
    this._exportImportService,
    this._settingsRepo,
    this._productsRepo,
    this._categoriesRepo,
    this._catalogsRepo,
  );

  /// Realiza a restauração completa do sistema a partir de um arquivo ZIP.
  /// Isso apaga os dados locais atuais e substitui pelos do backup.
  Future<void> restoreFullBackup(
    File zipFile, {
    Function(double, String)? onProgress,
  }) async {
    try {
      onProgress?.call(0.1, 'Extraindo arquivos do backup...');
      final (payload, extractDir) = await _packageService.preparePackage(
        zipFile,
      );

      onProgress?.call(0.3, 'Limpando base local para restauração...');
      await _productsRepo.clearAll();
      await _categoriesRepo.clearAll();
      await _catalogsRepo.clearAll();

      onProgress?.call(0.4, 'Restaurando imagens e banco de dados...');
      final report = await _packageService.importPackageFromDir(
        payload: payload,
        extractDir: extractDir,
        mode: ImportMode.replaceAll,
      );

      // 🚀 PONTO CRÍTICO: Após restaurar o backup, marcamos tudo como 'synced'
      // para evitar que o celular novo tente subir o backup de volta para a nuvem.
      onProgress?.call(0.8, 'Finalizando estados de sincronização...');
      final products = await _productsRepo.getProducts();
      final syncedProducts = products
          .map((p) => p.copyWith(syncStatus: SyncStatus.synced))
          .toList();
      await _productsRepo.updateProductsBulk(syncedProducts);

      // Marca que a carga inicial foi concluída (via backup)
      final settings = _settingsRepo.getSettings();
      await _settingsRepo.saveSettings(
        settings.copyWith(isInitialSyncCompleted: true),
      );

      // Limpa pasta temporária
      if (await extractDir.exists()) {
        await extractDir.delete(recursive: true);
      }

      onProgress?.call(1.0, 'Restauração concluída com sucesso!');
    } catch (e) {
      debugPrint('Erro na restauração de backup: $e');
      rethrow;
    }
  }
}
