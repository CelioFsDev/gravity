import 'dart:convert';
import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:catalogo_ja/core/services/dto/catalogo_ja_export_dtos.dart';
import 'package:catalogo_ja/core/services/export_import_service.dart';
import 'package:catalogo_ja/models/product.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

typedef ProgressCallback = void Function(double progress, String message);

class CatalogoJaPackageService {
  final ExportImportService _exportImportService;

  CatalogoJaPackageService(this._exportImportService);

  Future<File> exportPackage({ProgressCallback? onProgress}) async {
    final tempDir = await getTemporaryDirectory();
    final packageDir = Directory(
      p.join(
        tempDir.path,
        'CatalogoJa_export_${DateTime.now().millisecondsSinceEpoch}',
      ),
    );
    await packageDir.create(recursive: true);

    // 1. Get base payload
    onProgress?.call(0.05, 'Analisando banco de dados...');
    final jsonFile = await _exportImportService.exportToJsonFile();
    onProgress?.call(0.10, 'Lendo dados do cat\u00e1logo...');
    final payload = await _exportImportService.parsePayload(jsonFile);
    await Future.delayed(const Duration(milliseconds: 10));

    // 2. Process images and update payload
    final imagesDir = Directory(p.join(packageDir.path, 'images'));
    if (!await imagesDir.exists()) {
      await imagesDir.create();
    }

    final updatedProducts = <ProductDTO>[];
    int imageCount = 0;

    final appDocDir = await getApplicationDocumentsDirectory();
    final totalProducts = payload.products.length;
    int currentProduct = 0;

    for (final product in payload.products) {
      currentProduct++;
      onProgress?.call(
        0.10 + (0.55 * (currentProduct / totalProducts)),
        'Processando produto $currentProduct de $totalProducts...',
      );
      if (currentProduct % 10 == 0) {
        await Future.delayed(const Duration(milliseconds: 5));
      }
      final newImages = <String>[];
      final newPhotos = <ProductPhotoDTO>[];

      // Create product subdir for images
      final productImagesDir = Directory(p.join(imagesDir.path, product.id));

      // Map paths from photos list (which is richer than images list)
      for (int i = 0; i < product.photos.length; i++) {
        final photo = product.photos[i];
        final imagePath = photo.path;

        // Try absolute path first, then relative to app doc dir
        File file = File(imagePath);
        if (!file.existsSync()) {
          file = File(p.join(appDocDir.path, p.basename(imagePath)));
        }

        // Final fallback: try to find if it's already in product_images subdir
        if (!file.existsSync()) {
          file = File(
            p.join(appDocDir.path, 'product_images', p.basename(imagePath)),
          );
        }

        if (file.existsSync()) {
          if (!await productImagesDir.exists()) {
            await productImagesDir.create();
          }

          final ext = p.extension(imagePath);
          final relativeName = '${i.toString().padLeft(2, '0')}$ext';
          final targetPath = p.join(productImagesDir.path, relativeName);

          await file.copy(targetPath);

          final relativePackagePath = 'images/${product.id}/$relativeName';
          newImages.add(relativePackagePath);
          newPhotos.add(
            ProductPhotoDTO(
              path: relativePackagePath,
              colorKey: photo.colorKey,
              isPrimary: photo.isPrimary,
            ),
          );
          imageCount++;
        }
      }

      // Reconstruct product with relative paths
      updatedProducts.add(
        ProductDTO(
          id: product.id,
          name: product.name,
          ref: product.ref,
          sku: product.sku,
          priceRetail: product.priceRetail,
          priceWholesale: product.priceWholesale,
          isActive: product.isActive,
          isOutOfStock: product.isOutOfStock,
          promoEnabled: product.promoEnabled,
          promoPercent: product.promoPercent,
          images: newImages,
          photos: newPhotos,
          remoteImages: product.remoteImages,
          mainImageIndex: product.mainImageIndex,
          categoryIds: product.categoryIds,
          sizes: product.sizes,
          colors: product.colors,
          createdAt: product.createdAt,
          updatedAt: product.updatedAt,
        ),
      );
    }

    // 2.2 Process Collection Cover Images
    final updatedCollections = <CategoryDTO>[];
    final totalCollections = payload.collections.length;
    int currentCol = 0;

    for (final collection in payload.collections) {
      currentCol++;
      onProgress?.call(
        0.65 + (0.15 * (currentCol / totalCollections)),
        'Processando cole\u00e7\u00e3o $currentCol de $totalCollections...',
      );
      String? newMiniPath = collection.cover?.coverMiniPath;
      String? newPagePath = collection.cover?.coverPagePath;

      if (collection.cover != null) {
        final collectionImagesDir = Directory(
          p.join(imagesDir.path, 'collections', collection.id),
        );

        // Process Mini Cover
        if (collection.cover!.coverMiniPath != null) {
          final file = File(collection.cover!.coverMiniPath!);
          if (file.existsSync()) {
            if (!await collectionImagesDir.exists()) {
              await collectionImagesDir.create(recursive: true);
            }
            final ext = p.extension(file.path);
            final targetName = 'mini$ext';
            await file.copy(p.join(collectionImagesDir.path, targetName));
            newMiniPath = 'images/collections/${collection.id}/$targetName';
            imageCount++;
          }
        }

        // Process Page Cover
        if (collection.cover!.coverPagePath != null) {
          final file = File(collection.cover!.coverPagePath!);
          if (file.existsSync()) {
            if (!await collectionImagesDir.exists()) {
              await collectionImagesDir.create(recursive: true);
            }
            final ext = p.extension(file.path);
            final targetName = 'page$ext';
            await file.copy(p.join(collectionImagesDir.path, targetName));
            newPagePath = 'images/collections/${collection.id}/$targetName';
            imageCount++;
          }
        }
      }

      updatedCollections.add(
        CategoryDTO(
          id: collection.id,
          name: collection.name,
          slug: collection.slug,
          isActive: collection.isActive,
          order: collection.order,
          type: collection.type,
          cover: collection.cover != null
              ? CollectionCoverDTO(
                  title: collection.cover!.title,
                  mode: collection.cover!.mode,
                  coverImagePath: collection
                      .cover!
                      .coverImagePath, // preserve original or placeholder
                  coverMiniPath: newMiniPath,
                  coverPagePath: newPagePath,
                )
              : null,
          createdAt: collection.createdAt,
          updatedAt: collection.updatedAt,
        ),
      );
    }

    // 3. Create Update Payload
    final newPayload = CatalogoJaExportPayload(
      app: payload.app,
      version: payload.version,
      exportedAt: payload.exportedAt,
      store: payload.store,
      categories: payload.categories,
      collections: updatedCollections,
      products: updatedProducts,
    );

    // 4. Save products.json
    final productsJsonFile = File(p.join(packageDir.path, 'products.json'));
    await productsJsonFile.writeAsString(jsonEncode(newPayload.toJson()));

    // 5. Create Manifest
    final manifest = {
      "format": "CatalogoJa-package",
      "version": 1,
      "exportedAt": DateTime.now().toIso8601String(),
      "productsFile": "products.json",
      "imagesRoot": "images/",
      "counts": {"products": updatedProducts.length, "images": imageCount},
    };
    final manifestFile = File(p.join(packageDir.path, 'manifest.json'));
    await manifestFile.writeAsString(jsonEncode(manifest));

    // 6. Zip it (Add files manually to ensure relative paths)
    final zipFile = File(
      p.join(
        tempDir.path,
        'CatalogoJa_export_${DateTime.now().millisecondsSinceEpoch}.zip',
      ),
    );

    final archive = Archive();

    onProgress?.call(0.85, 'Criando arquivo compactado...');

    // Add products.json
    final productsBytes = await productsJsonFile.readAsBytes();
    archive.addFile(
      ArchiveFile('products.json', productsBytes.length, productsBytes),
    );

    // Add manifest.json
    final manifestBytes = await manifestFile.readAsBytes();
    archive.addFile(
      ArchiveFile('manifest.json', manifestBytes.length, manifestBytes),
    );

    // Add images recursively
    final entities = imagesDir.listSync(recursive: true);
    for (final entity in entities) {
      if (entity is File) {
        final relativePath = p.relative(entity.path, from: packageDir.path);
        final bytes = await entity.readAsBytes();
        archive.addFile(ArchiveFile(relativePath, bytes.length, bytes));
      }
    }

    onProgress?.call(0.95, 'Finalizando arquivo...');
    final zipBytes = ZipEncoder().encode(archive);
    await zipFile.writeAsBytes(zipBytes);

    // Cleanup temp dir
    // await packageDir.delete(recursive: true); // Optional, system cleans temp

    return zipFile;
  }

  /// Extracts the ZIP package and returns the payload and the extraction directory.
  Future<(CatalogoJaExportPayload, Directory)> preparePackage(
    File zipFile,
  ) async {
    final tempDir = await getTemporaryDirectory();
    final extractDir = Directory(
      p.join(
        tempDir.path,
        'CatalogoJa_import_prepare_${DateTime.now().millisecondsSinceEpoch}',
      ),
    );
    await extractDir.create(recursive: true);

    // 1. Unzip
    final bytes = await zipFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    for (final file in archive) {
      final filename = file.name;
      if (file.isFile) {
        final data = file.content as List<int>;
        File(p.join(extractDir.path, filename))
          ..createSync(recursive: true)
          ..writeAsBytesSync(data);
      } else {
        Directory(
          p.join(extractDir.path, filename),
        ).createSync(recursive: true);
      }
    }

    // 2. Validate Manifest
    final manifestFile = File(p.join(extractDir.path, 'manifest.json'));
    if (!await manifestFile.exists()) {
      throw Exception('Invalid package: manifest.json missing');
    }

    // 3. Read Products
    final productsFile = File(p.join(extractDir.path, 'products.json'));
    if (!await productsFile.exists()) {
      throw Exception('Invalid package: products.json missing');
    }

    final payload = await _exportImportService.parsePayload(productsFile);
    return (payload, extractDir);
  }

  /// Finalizes the import by restoring images and executing the database import.
  Future<ImportReport> importPackageFromDir({
    required CatalogoJaExportPayload payload,
    required Directory extractDir,
    required ImportMode mode,
  }) async {
    // 4. Restore Images
    final appDocDir = await getApplicationDocumentsDirectory();
    final appImagesDir = Directory(p.join(appDocDir.path, 'product_images'));
    if (!await appImagesDir.exists()) {
      await appImagesDir.create(recursive: true);
    }

    final restoredProducts = <ProductDTO>[];

    for (final product in payload.products) {
      final absoluteImages = <String>[];
      final restoredPhotos = <ProductPhotoDTO>[];

      for (final photo in product.photos) {
        final sourceFile = File(p.join(extractDir.path, photo.path));
        if (await sourceFile.exists()) {
          final newName = '${product.id}_${p.basename(sourceFile.path)}';
          final targetFile = File(p.join(appImagesDir.path, newName));

          await sourceFile.copy(targetFile.path);

          absoluteImages.add(targetFile.path);
          restoredPhotos.add(
            ProductPhotoDTO(
              path: targetFile.path,
              colorKey: photo.colorKey,
              isPrimary: photo.isPrimary,
            ),
          );
        }
      }

      restoredProducts.add(
        ProductDTO(
          id: product.id,
          name: product.name,
          ref: product.ref,
          sku: product.sku,
          priceRetail: product.priceRetail,
          priceWholesale: product.priceWholesale,
          isActive: product.isActive,
          isOutOfStock: product.isOutOfStock,
          promoEnabled: product.promoEnabled,
          promoPercent: product.promoPercent,
          images: absoluteImages,
          photos: restoredPhotos,
          remoteImages: product.remoteImages,
          mainImageIndex: product.mainImageIndex,
          categoryIds: product.categoryIds,
          sizes: product.sizes,
          colors: product.colors,
          createdAt: product.createdAt,
          updatedAt: product.updatedAt,
        ),
      );
    }

    // 4.2 Restore Collection Images
    final restoredCollections = <CategoryDTO>[];
    for (final collection in payload.collections) {
      String? absMiniPath = collection.cover?.coverMiniPath;
      String? absPagePath = collection.cover?.coverPagePath;

      if (collection.cover != null) {
        // Mini
        if (collection.cover!.coverMiniPath != null) {
          final sourceFile = File(
            p.join(extractDir.path, collection.cover!.coverMiniPath!),
          );
          if (await sourceFile.exists()) {
            final newName =
                'coll_${collection.id}_mini${p.extension(sourceFile.path)}';
            final targetFile = File(p.join(appImagesDir.path, newName));
            await sourceFile.copy(targetFile.path);
            absMiniPath = targetFile.path;
          }
        }
        // Page
        if (collection.cover!.coverPagePath != null) {
          final sourceFile = File(
            p.join(extractDir.path, collection.cover!.coverPagePath!),
          );
          if (await sourceFile.exists()) {
            final newName =
                'coll_${collection.id}_page${p.extension(sourceFile.path)}';
            final targetFile = File(p.join(appImagesDir.path, newName));
            await sourceFile.copy(targetFile.path);
            absPagePath = targetFile.path;
          }
        }
      }

      restoredCollections.add(
        CategoryDTO(
          id: collection.id,
          name: collection.name,
          slug: collection.slug,
          isActive: collection.isActive,
          order: collection.order,
          type: collection.type,
          cover: collection.cover != null
              ? CollectionCoverDTO(
                  title: collection.cover!.title,
                  mode: collection.cover!.mode,
                  coverImagePath: collection.cover!.coverImagePath,
                  coverMiniPath: absMiniPath,
                  coverPagePath: absPagePath,
                )
              : null,
          createdAt: collection.createdAt,
          updatedAt: collection.updatedAt,
        ),
      );
    }

    // 5. Execute Import
    final importPayload = CatalogoJaExportPayload(
      app: payload.app,
      version: payload.version,
      exportedAt: payload.exportedAt,
      store: payload.store,
      categories: payload.categories,
      collections: restoredCollections,
      products: restoredProducts,
    );

    final result = await _exportImportService.executeImport(
      importPayload,
      mode,
    );

    return ImportReport(
      createdCount: result.successCount,
      updatedCount: 0,
      variantsCount: 0,
      createdCategoriesCount: 0,
      warnings: result.errors,
      importedProducts: restoredProducts.map((e) => e.toModel()).toList(),
    );
  }

  @Deprecated('Use preparePackage and importPackageFromDir instead')
  Future<ImportReport> importPackage(File zipFile) async {
    final (payload, dir) = await preparePackage(zipFile);
    return importPackageFromDir(
      payload: payload,
      extractDir: dir,
      mode: ImportMode.merge,
    );
  }
}

class ImportReport {
  final int createdCount;
  final int updatedCount;
  final int variantsCount;
  final int createdCategoriesCount;
  final List<String> warnings;
  final List<Product>? importedProducts;

  ImportReport({
    required this.createdCount,
    required this.updatedCount,
    required this.variantsCount,
    required this.createdCategoriesCount,
    required this.warnings,
    this.importedProducts,
  });
}

final catalogoJaPackageServiceProvider = Provider<CatalogoJaPackageService>((
  ref,
) {
  return CatalogoJaPackageService(ref.read(exportImportServiceProvider));
});
