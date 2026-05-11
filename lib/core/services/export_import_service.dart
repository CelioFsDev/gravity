import 'dart:convert';
import 'dart:io' as io;

import 'package:catalogo_ja/models/product.dart';
import 'package:catalogo_ja/core/services/dto/catalogo_ja_export_dtos.dart';
import 'package:catalogo_ja/data/repositories/contracts/categories_repository_contract.dart';
import 'package:catalogo_ja/data/repositories/contracts/products_repository_contract.dart';
import 'package:catalogo_ja/data/repositories/contracts/catalogs_repository_contract.dart';
import 'package:catalogo_ja/data/repositories/firestore_products_repository.dart';
import 'package:catalogo_ja/data/repositories/firestore_categories_repository.dart';
import 'package:catalogo_ja/data/repositories/firestore_catalogs_repository.dart';
import 'package:catalogo_ja/data/repositories/settings_repository.dart';
import 'package:catalogo_ja/models/category.dart';
import 'package:catalogo_ja/models/catalog.dart';
import 'package:catalogo_ja/core/utils/encoding_utils.dart';
import 'package:flutter/foundation.dart' hide Category;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'export_import_service.g.dart';

enum ImportMode {
  merge, // Upsert based on REF
  onlyNew, // Insert only if REF not exists
  replaceAll, // Wipe all and insert
}

class ImportPreview {
  final int totalProductsInFile;
  final int totalCategoriesInFile;
  final int totalCollectionsInFile;

  final int newProductsCount;
  final int updatedProductsCount; // Conflict but will update (Merge mode)
  final int skippedProductsCount; // Conflict (OnlyNew mode)

  final List<String> warnings;

  ImportPreview({
    required this.totalProductsInFile,
    required this.totalCategoriesInFile,
    required this.totalCollectionsInFile,
    required this.newProductsCount,
    required this.updatedProductsCount,
    required this.skippedProductsCount,
    this.warnings = const [],
  });
}

class ImportResult {
  final int successCount;
  final int skipCount;
  final int errorCount;
  final List<String> errors;

  ImportResult({
    required this.successCount,
    required this.skipCount,
    required this.errorCount,
    this.errors = const [],
  });
}

class ExportImportService {
  final ProductsRepositoryContract _productsRepo;
  final CategoriesRepositoryContract _categoriesRepo;
  final CatalogsRepositoryContract _catalogsRepo;
  final SettingsRepository _settingsRepo;

  ExportImportService(
    this._productsRepo,
    this._categoriesRepo,
    this._catalogsRepo,
    this._settingsRepo,
  );

  /// Generates the payload object for export.
  Future<CatalogoJaExportPayload> generatePayload({
    List<Product>? products,
    List<Category>? categories,
    List<Catalog>? catalogs,
  }) async {
    final allProducts = products ?? await _productsRepo.getProducts();
    final allCategories = categories ?? await _categoriesRepo.getCategories();
    final allCatalogs = catalogs ?? await _catalogsRepo.getCatalogs();
    final settings = _settingsRepo.getSettings();

    // Split categories and collections
    final categoryDTOs = allCategories
        .where((c) => c.type == CategoryType.productType)
        .map((c) => CategoryDTO.fromModel(c))
        .toList();

    final collectionDTOs = allCategories
        .where((c) => c.type == CategoryType.collection)
        .map((c) => CategoryDTO.fromModel(c))
        .toList();

    final productDTOs = allProducts
        .map((p) => ProductDTO.fromModel(p))
        .toList();

    final catalogDTOs = allCatalogs
        .map((c) => CatalogDTO.fromModel(c))
        .toList();

    return CatalogoJaExportPayload(
      app: 'CatalogoJa',
      version: 1,
      backupVersion: 1, // Controle de formato de backup do ZIP
      schemaVersion: 1, // Versao do DTO / Modelos de banco de dados
      migrationStrategy: 'v1_direct', // Estratégia de fallback futura
      exportedAt: DateTime.now().toIso8601String(),
      store: StoreInfoDTO(
        name: settings.storeName,
        phone: settings.whatsappNumber,
      ),
      categories: categoryDTOs,
      collections: collectionDTOs,
      products: productDTOs,
      catalogs: catalogDTOs,
    );
  }

  /// Generates the CatalogoJa_export.json bytes.
  Future<Uint8List> exportToJsonBytes() async {
    final payload = await generatePayload();
    final jsonString = jsonEncode(payload.toJson());
    return Uint8List.fromList(utf8.encode(jsonString));
  }

  /// Generates the CatalogoJa_export.json file and returns it.
  Future<io.File?> exportToJsonFile() async {
    if (kIsWeb) return null;
    final bytes = await exportToJsonBytes();

    final directory = await getApplicationDocumentsDirectory();
    final file = io.File('${directory.path}/CatalogoJa_export.json');
    await file.writeAsBytes(bytes);

    return file;
  }

  /// Parses the JSON content of a file into a payload.
  Future<CatalogoJaExportPayload> parsePayload(io.File file) async {
    if (!await file.exists()) {
      throw Exception('Arquivo n\u00e3o encontrado no caminho especificado.');
    }
    final bytes = await file.readAsBytes();
    return parsePayloadFromBytes(bytes);
  }

  /// Parses the JSON content from bytes into a payload.
  Future<CatalogoJaExportPayload> parsePayloadFromBytes(Uint8List bytes) async {
    try {
      String jsonString;
      try {
        jsonString = utf8.decode(bytes);
        if (jsonString.startsWith('\uFEFF')) {
          jsonString = jsonString.substring(1);
        }
      } catch (_) {
        // Fallback to Latin1 if UTF-8 fails
        jsonString = latin1.decode(bytes);
      }

      // Safety net: fix possible garbled characters if file was decoded with wrong charset
      jsonString = EncodingUtils.fixGarbledString(jsonString);

      final map = jsonDecode(jsonString) as Map<String, dynamic>;

      final appIdentifier = map['app']?.toString() ?? '';
      final validIdentifiers = {'catalogoja', 'gravity', 'catalogo_ja'};

      if (!validIdentifiers.contains(
        appIdentifier.toLowerCase().replaceAll(' ', '').replaceAll('_', ''),
      )) {
        debugPrint('App identifier mismatch: $appIdentifier');
        throw Exception(
          'Este arquivo não parece ser um backup válido do CatalogoJa ou Gravity (ID: $appIdentifier).',
        );
      }

      // 🛡️ SCHEMA & VERSIONING MIGRATION LOGIC
      final incomingSchemaVersion = map['schemaVersion'] as int? ?? 1;
      final currentAppSchemaVersion =
          1; // ⚠️ Aumente aqui quando o Hive/Modelos mudarem de forma destrutiva

      if (incomingSchemaVersion > currentAppSchemaVersion) {
        throw Exception(
          'Este backup foi gerado numa versão mais recente do aplicativo (v$incomingSchemaVersion). Por favor, atualize seu aplicativo na loja antes de importar.',
        );
      }

      final payload = CatalogoJaExportPayload.fromJson(map);

      // Aqui entra o switch de Migrações futuras.
      // if (payload.schemaVersion < currentAppSchemaVersion) {
      //    payload = _runMigrations(payload, currentAppSchemaVersion);
      // }

      return payload;
    } catch (e) {
      if (e is FormatException) {
        throw Exception(
          'O arquivo n\u00e3o parece ser um JSON v\u00e1lido ou est\u00e1 corrompido.',
        );
      }
      throw Exception('Erro ao ler dados de exporta\u00e7\u00e3o: $e');
    }
  }

  /// Previews what will happen during import.
  Future<ImportPreview> previewImport(CatalogoJaExportPayload payload) async {
    final existingProducts = await _productsRepo.getProducts();
    final existingRefs = existingProducts
        .map((p) => p.ref.toLowerCase().trim())
        .toSet();

    int newCount = 0;
    int updateCount = 0;

    for (final p in payload.products) {
      final ref = p.ref.trim().toLowerCase();
      if (ref.isEmpty) continue; // Skip invalid products without ref

      if (existingRefs.contains(ref)) {
        updateCount++;
      } else {
        newCount++;
      }
    }

    return ImportPreview(
      totalProductsInFile: payload.products.length,
      totalCategoriesInFile: payload.categories.length,
      totalCollectionsInFile: payload.collections.length,
      newProductsCount: newCount,
      updatedProductsCount: updateCount,
      skippedProductsCount: updateCount, // In "OnlyNew" mode, these are skipped
    );
  }

  /// Executes the import based on the selected mode.
  Future<ImportResult> executeImport(
    CatalogoJaExportPayload payload,
    ImportMode mode, {
    String? tenantId,
  }) async {
    int success = 0;
    int skipped = 0;
    int errors = 0;
    List<String> errorList = [];

    // 1. REPLACE MODE: Wipe everything first
    if (mode == ImportMode.replaceAll) {
      await _productsRepo.clearAll();
      await _categoriesRepo.clearAll();
      await _catalogsRepo.clearAll();
    }

    // 2. Import Categories & Collections
    // We try to match by SLUG. If exists -> Update (Upsert). If not -> Create.
    // In "OnlyNew" mode we could skip updates, but for categories/collections
    // it's usually better to ensure they exist for products.
    // P0 decision: Always Upsert Categories/Collections to ensure consistency unless ReplaceAll wiped them.

    final allCategoryDTOs = [...payload.categories, ...payload.collections];
    final categoryIdMap = <String, String>{}; // OldID -> NewID (or same ID)

    for (final dto in allCategoryDTOs) {
      try {
        final existing = await _categoriesRepo.getBySlug(dto.slug);

        if (existing != null) {
          // If ReplaceAll, we won't find existing because we wiped.
          // If Merge/OnlyNew, we might find.
          if (mode == ImportMode.replaceAll) {
            // Should not happen naturally unless duplicate slugs in same file
            await _categoriesRepo.addCategory(dto.toModel());
            categoryIdMap[dto.id] = dto.id;
          } else {
            // Update existing
            await _categoriesRepo.updateCategory(
              dto
                  .toModel(tenantId: tenantId)
                  .copyWith(id: existing.id), // Keep local ID
            );
            categoryIdMap[dto.id] = existing.id;
          }
        } else {
          // New Category
          await _categoriesRepo.addCategory(dto.toModel(tenantId: tenantId));
          categoryIdMap[dto.id] = dto.id;
        }
      } catch (e) {
        // Log warning
        print('Error importing category ${dto.name}: $e');
      }
    }

    // 3. Import Products
    for (final pDTO in payload.products) {
      try {
        final ref = pDTO.ref.trim();
        if (ref.isEmpty) {
          skipped++;
          continue;
        }

        final existing = await _productsRepo.getByRef(ref);

        if (existing != null) {
          // CONFLICT found
          if (mode == ImportMode.onlyNew) {
            skipped++;
            continue;
          }

          if (mode == ImportMode.merge || mode == ImportMode.replaceAll) {
            // Update logic
            // Map category IDs
            final newCategoryIds =
                pDTO.categoryIds
                    ?.map((id) => categoryIdMap[id] ?? id)
                    .toList() ??
                [];

            // Merge logic: Update fields, keep local ID, preserve local images if remote are empty?
            // P0: Overwrite with imported data (except ID).
            final productToSave = pDTO
                .toModel(tenantId: tenantId)
                .copyWith(
                  id: existing.id, // KEEP LOCAL ID
                  categoryIds: newCategoryIds,
                  syncStatus: SyncStatus.synced,
                );

            await _productsRepo.saveImportedProduct(
              productToSave,
              shouldSync: false,
            );
            success++;
          }
        } else {
          // NEW PRODUCT
          final newCategoryIds =
              pDTO.categoryIds?.map((id) => categoryIdMap[id] ?? id).toList() ??
              [];

          final productToSave = pDTO
              .toModel(tenantId: tenantId)
              .copyWith(
                categoryIds: newCategoryIds,
                syncStatus: SyncStatus.pendingUpdate,
              );

          await _productsRepo.saveImportedProduct(
            productToSave,
            shouldSync: true,
          );
          success++;
        }
      } catch (e) {
        errors++;
        errorList.add('Error importing product ${pDTO.name}: $e');
      }
    }

    // 4. Import Catalogs
    for (final cDTO in payload.catalogs) {
      try {
        final existing = await _catalogsRepo.getBySlug(cDTO.slug);

        if (existing != null) {
          if (mode == ImportMode.replaceAll) {
            await _catalogsRepo.addCatalog(cDTO.toModel(tenantId: tenantId));
          } else if (mode == ImportMode.merge) {
            // Update logic: map product IDs if they changed?
            // Assuming IDs are consistent for Catalogs link.
            await _catalogsRepo.updateCatalog(
              cDTO.toModel(tenantId: tenantId).copyWith(id: existing.id),
            );
          }
        } else {
          await _catalogsRepo.addCatalog(cDTO.toModel(tenantId: tenantId));
        }
      } catch (e) {
        errorList.add('Error importing catalog ${cDTO.name}: $e');
      }
    }

    return ImportResult(
      successCount: success,
      skipCount: skipped,
      errorCount: errors,
      errors: errorList,
    );
  }
}

@Riverpod(keepAlive: true)
ExportImportService exportImportService(ExportImportServiceRef ref) {
  return ExportImportService(
    ref.read(syncProductsRepositoryProvider),
    ref.read(syncCategoriesRepositoryProvider),
    ref.read(syncCatalogsRepositoryProvider),
    ref.read(settingsRepositoryProvider),
  );
}
