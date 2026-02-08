import 'dart:convert';
import 'dart:io';

import 'package:gravity/core/services/dto/gravity_export_dtos.dart';
import 'package:gravity/data/repositories/contracts/categories_repository_contract.dart';
import 'package:gravity/data/repositories/contracts/products_repository_contract.dart';
import 'package:gravity/data/repositories/products_repository.dart';
import 'package:gravity/data/repositories/categories_repository.dart';
import 'package:gravity/data/repositories/settings_repository.dart';
import 'package:gravity/models/category.dart';
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
  final SettingsRepository _settingsRepo;

  ExportImportService(
    this._productsRepo,
    this._categoriesRepo,
    this._settingsRepo,
  );

  /// Generates the gravity_export.json file and returns it.
  Future<File> exportToJsonFile() async {
    final products = await _productsRepo.getProducts();
    final allCategories = await _categoriesRepo.getCategories();
    final settings = _settingsRepo.getSettings();

    // Split categories and collections
    final categories = allCategories
        .where((c) => c.type == CategoryType.productType)
        .map((c) => CategoryDTO.fromModel(c))
        .toList();

    final collections = allCategories
        .where((c) => c.type == CategoryType.collection)
        .map((c) => CategoryDTO.fromModel(c))
        .toList();

    final productDTOs = products.map((p) => ProductDTO.fromModel(p)).toList();

    final payload = GravityExportPayload(
      app: 'gravity',
      version: 1,
      exportedAt: DateTime.now().toIso8601String(),
      store: StoreInfoDTO(
        name: settings.storeName,
        phone: settings.whatsappNumber,
      ),
      categories: categories,
      collections: collections,
      products: productDTOs,
    );

    final jsonString = jsonEncode(payload.toJson());

    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/gravity_export.json');
    await file.writeAsString(jsonString);

    return file;
  }

  /// Parses the JSON content of a file into a payload.
  Future<GravityExportPayload> parsePayload(File file) async {
    try {
      final jsonString = await file.readAsString();
      final map = jsonDecode(jsonString) as Map<String, dynamic>;

      if (map['app'] != 'gravity') {
        throw Exception('Arquivo inválido ou de outro aplicativo.');
      }

      return GravityExportPayload.fromJson(map);
    } catch (e) {
      throw Exception('Erro ao ler arquivo de exportação: $e');
    }
  }

  /// Previews what will happen during import.
  Future<ImportPreview> previewImport(GravityExportPayload payload) async {
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
    GravityExportPayload payload,
    ImportMode mode,
  ) async {
    int success = 0;
    int skipped = 0;
    int errors = 0;
    List<String> errorList = [];

    // 1. REPLACE MODE: Wipe everything first
    if (mode == ImportMode.replaceAll) {
      await _productsRepo.clearAll();
      await _categoriesRepo.clearAll();
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
              dto.toModel().copyWith(id: existing.id), // Keep local ID
            );
            categoryIdMap[dto.id] = existing.id;
          }
        } else {
          // New Category
          // We can generate a new ID to avoid collisions or trust the imported ID if it's a UUID?
          // To be safe, let's keep the imported ID if valid UUID, or generate new if collision?
          // Simplest for P0: Use imported ID. If collision on ID in Hive, it overwrites.
          // Since we checked slug, we assume ID might be different.
          // Let's use `addCategory` which uses ID from model.
          await _categoriesRepo.addCategory(dto.toModel());
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
            final productToSave = pDTO.toModel().copyWith(
              id: existing.id, // KEEP LOCAL ID
              categoryIds: newCategoryIds,
            );

            await _productsRepo.updateProduct(productToSave);
            success++;
          }
        } else {
          // NEW PRODUCT
          final newCategoryIds =
              pDTO.categoryIds?.map((id) => categoryIdMap[id] ?? id).toList() ??
              [];

          // Generate new ID or use imported?
          // Use imported ID if not collision. But to be safe against ID collision on different REF (edge case),
          // maybe generate new ID?
          // Ideally, we keep ID if possible to maintain relations if we import orders later.
          // But for now, let's keep ID.
          final productToSave = pDTO.toModel().copyWith(
            categoryIds: newCategoryIds,
          );

          await _productsRepo.addProduct(productToSave);
          success++;
        }
      } catch (e) {
        errors++;
        errorList.add('Error importing product ${pDTO.name}: $e');
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
    ref.read(productsRepositoryProvider),
    ref.read(categoriesRepositoryProvider),
    ref.read(settingsRepositoryProvider),
  );
}
