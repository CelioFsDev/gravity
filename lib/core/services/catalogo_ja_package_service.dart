import 'dart:convert';
import 'dart:io' as io;
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter/foundation.dart' show Uint8List;
import 'package:catalogo_ja/core/services/dto/catalogo_ja_export_dtos.dart';
import 'package:catalogo_ja/core/services/export_import_service.dart';
import 'package:catalogo_ja/models/product.dart';
import 'package:catalogo_ja/models/category.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

typedef ProgressCallback = void Function(double progress, String message);

class CatalogoJaPackageService {
  final ExportImportService _exportImportService;

  CatalogoJaPackageService(this._exportImportService);

  Future<Uint8List> exportPackage({ProgressCallback? onProgress}) async {
    return _exportPackageBase(onProgress: onProgress);
  }

  Future<Uint8List> exportPackageForCatalog({
    required List<Product> products,
    required List<Category> collections,
    ProgressCallback? onProgress,
  }) async {
    return _exportPackageBase(
      products: products,
      collections: collections,
      onProgress: onProgress,
    );
  }

  Future<Uint8List> _exportPackageBase({
    List<Product>? products,
    List<Category>? collections,
    ProgressCallback? onProgress,
  }) async {
    // 1. Get base payload
    onProgress?.call(0.05, 'Analisando banco de dados...');
    final payload = await _exportImportService.generatePayload(
      products: products,
      categories: collections,
    );
    onProgress?.call(0.10, 'Lendo dados do cat\u00e1logo...');
    await Future.delayed(const Duration(milliseconds: 10));

    final archive = Archive();
    final updatedProducts = <ProductDTO>[];
    int imageCount = 0;

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
      final newPhotos = <ProductPhotoDTO>[];

      // Map paths from photos list
      for (int i = 0; i < product.photos.length; i++) {
        final photo = product.photos[i];
        final imagePath = photo.path;
        Uint8List? fileBytes;

        if (imagePath.startsWith('data:')) {
          try {
            final commaIndex = imagePath.indexOf(',');
            if (commaIndex != -1) {
              fileBytes = base64Decode(imagePath.substring(commaIndex + 1));
            }
          } catch (e) {
            debugPrint('Error decoding base64 image: $e');
          }
        } else if (!kIsWeb) {
          fileBytes = await _readLocalFile(imagePath);
        }

        if (fileBytes != null) {
          final ext = p.extension(imagePath).isEmpty
              ? '.jpg'
              : p.extension(imagePath);
          final baseName = p.basenameWithoutExtension(imagePath);
          final relativeName = '${i.toString().padLeft(2, '0')}__$baseName$ext';
          final relativePackagePath = 'images/${product.id}/$relativeName';

          archive.addFile(
            ArchiveFile(relativePackagePath, fileBytes.length, fileBytes),
          );

          newPhotos.add(
            ProductPhotoDTO(
              path: relativePackagePath,
              colorKey: photo.colorKey,
              isPrimary: photo.isPrimary,
              photoType: photo.photoType,
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
          images: newPhotos
              .map((p) => ProductImageDTO.fromModel(p.toProductImage()))
              .toList(),
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
        // Process Mini Cover
        if (collection.cover!.coverMiniPath != null) {
          final bytes = await _readImageBytes(collection.cover!.coverMiniPath!);
          if (bytes != null) {
            final ext = p.extension(collection.cover!.coverMiniPath!).isEmpty
                ? '.jpg'
                : p.extension(collection.cover!.coverMiniPath!);
            final targetName = 'mini$ext';
            final relPath = 'images/collections/${collection.id}/$targetName';
            archive.addFile(ArchiveFile(relPath, bytes.length, bytes));
            newMiniPath = relPath;
            imageCount++;
          }
        }

        // Process Page Cover
        if (collection.cover!.coverPagePath != null) {
          final bytes = await _readImageBytes(collection.cover!.coverPagePath!);
          if (bytes != null) {
            final ext = p.extension(collection.cover!.coverPagePath!).isEmpty
                ? '.jpg'
                : p.extension(collection.cover!.coverPagePath!);
            final targetName = 'page$ext';
            final relPath = 'images/collections/${collection.id}/$targetName';
            archive.addFile(ArchiveFile(relPath, bytes.length, bytes));
            newPagePath = relPath;
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
                  coverImagePath: collection.cover!.coverImagePath,
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

    // 4. Add products.json to archive
    final productsJson = jsonEncode(newPayload.toJson());
    final productsBytes = utf8.encode(productsJson);
    archive.addFile(
      ArchiveFile('products.json', productsBytes.length, productsBytes),
    );

    // 5. Add Manifest to archive
    final manifest = {
      "format": "CatalogoJa-package",
      "version": 1,
      "exportedAt": DateTime.now().toIso8601String(),
      "productsFile": "products.json",
      "imagesRoot": "images/",
      "counts": {"products": updatedProducts.length, "images": imageCount},
    };
    final manifestBytes = utf8.encode(jsonEncode(manifest));
    archive.addFile(
      ArchiveFile('manifest.json', manifestBytes.length, manifestBytes),
    );

    onProgress?.call(0.95, 'Finalizando arquivo...');
    final zipEnabledBits = ZipEncoder().encode(archive);
    return Uint8List.fromList(zipEnabledBits);
  }

  Future<Uint8List?> _readLocalFile(String path) async {
    if (kIsWeb) return null;
    try {
      final file = io.File(path);
      if (file.existsSync()) return await file.readAsBytes();

      final appDocDir = await getApplicationDocumentsDirectory();
      final file2 = io.File(p.join(appDocDir.path, p.basename(path)));
      if (file2.existsSync()) return await file2.readAsBytes();

      final file3 = io.File(
        p.join(appDocDir.path, 'product_images', p.basename(path)),
      );
      if (file3.existsSync()) return await file3.readAsBytes();
    } catch (e) {
      debugPrint('Error reading local file $path: $e');
    }
    return null;
  }

  Future<Uint8List?> _readImageBytes(String path) async {
    if (path.startsWith('data:')) {
      final commaIndex = path.indexOf(',');
      if (commaIndex != -1) {
        return base64Decode(path.substring(commaIndex + 1));
      }
      return null;
    }
    if (!kIsWeb) return _readLocalFile(path);
    return null;
  }

  /// Extracts the ZIP package and returns the payload and the extraction directory.
  Future<(CatalogoJaExportPayload, io.Directory)> preparePackage(
    io.File zipFile,
  ) async {
    if (kIsWeb) {
      throw UnsupportedError(
        'preparePackage(File) nao e suportado na web. Use preparePackageFromBytes.',
      );
    }

    final bytes = await zipFile.readAsBytes();
    return preparePackageFromBytes(bytes);
  }

  Future<(CatalogoJaExportPayload, io.Directory)> preparePackageFromBytes(
    Uint8List bytes,
  ) async {
    if (kIsWeb) {
      throw UnsupportedError(
        'preparePackageFromBytes usa diretorio temporario e nao e suportado na web.',
      );
    }

    final tempDir = await getTemporaryDirectory();
    final extractDir = io.Directory(
      p.join(
        tempDir.path,
        'CatalogoJa_import_prepare_${DateTime.now().millisecondsSinceEpoch}',
      ),
    );
    await extractDir.create(recursive: true);

    // 1. Unzip
    final archive = ZipDecoder().decodeBytes(bytes);

    for (final file in archive) {
      final filename = file.name;
      if (file.isFile) {
        final data = file.content as List<int>;
        io.File(p.join(extractDir.path, filename))
          ..createSync(recursive: true)
          ..writeAsBytesSync(data);
      } else {
        io.Directory(
          p.join(extractDir.path, filename),
        ).createSync(recursive: true);
      }
    }

    // 2. Validate Manifest
    final manifestFile = io.File(p.join(extractDir.path, 'manifest.json'));
    if (!await manifestFile.exists()) {
      throw Exception('Invalid package: manifest.json missing');
    }

    // 3. Read Products
    final productsFile = io.File(p.join(extractDir.path, 'products.json'));
    if (!await productsFile.exists()) {
      throw Exception('Invalid package: products.json missing');
    }

    final payload = await _exportImportService.parsePayload(productsFile);
    return (payload, extractDir);
  }

  /// Finalizes the import by restoring images and executing the database import.
  Future<ImportReport> importPackageFromDir({
    required CatalogoJaExportPayload payload,
    required io.Directory extractDir,
    required ImportMode mode,
  }) async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final appImagesDir = io.Directory(p.join(appDocDir.path, 'product_images'));
    if (!await appImagesDir.exists()) {
      await appImagesDir.create(recursive: true);
    }

    final restoredProducts = <ProductDTO>[];

    for (final product in payload.products) {
      final restoredPhotos = <ProductPhotoDTO>[];

      for (final photo in product.photos) {
        final sourceFile = io.File(p.join(extractDir.path, photo.path));
        if (await sourceFile.exists()) {
          final newName = '${product.id}_${p.basename(sourceFile.path)}';
          final targetFile = io.File(p.join(appImagesDir.path, newName));

          await sourceFile.copy(targetFile.path);

          restoredPhotos.add(
            ProductPhotoDTO(
              path: targetFile.path,
              colorKey: photo.colorKey,
              isPrimary: photo.isPrimary,
              photoType: photo.photoType,
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
          images: restoredPhotos
              .map((p) => ProductImageDTO.fromModel(p.toProductImage()))
              .toList(),
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
          final sourceFile = io.File(
            p.join(extractDir.path, collection.cover!.coverMiniPath!),
          );
          if (await sourceFile.exists()) {
            final newName =
                'coll_${collection.id}_mini${p.extension(sourceFile.path)}';
            final targetFile = io.File(p.join(appImagesDir.path, newName));
            await sourceFile.copy(targetFile.path);
            absMiniPath = targetFile.path;
          }
        }
        // Page
        if (collection.cover!.coverPagePath != null) {
          final sourceFile = io.File(
            p.join(extractDir.path, collection.cover!.coverPagePath!),
          );
          if (await sourceFile.exists()) {
            final newName =
                'coll_${collection.id}_page${p.extension(sourceFile.path)}';
            final targetFile = io.File(p.join(appImagesDir.path, newName));
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
  Future<ImportReport> importPackage(io.File zipFile) async {
    final (payload, dir) = await preparePackage(zipFile);
    return importPackageFromDir(
      payload: payload,
      extractDir: dir,
      mode: ImportMode.merge,
    );
  }

  Future<ImportReport> importPackageFromBytes({
    required Uint8List zipBytes,
    required ImportMode mode,
  }) async {
    final archive = ZipDecoder().decodeBytes(zipBytes);

    ArchiveFile? manifestFile;
    ArchiveFile? productsFile;
    for (final file in archive) {
      if (!file.isFile) continue;
      final name = file.name.toLowerCase();
      if (name == 'manifest.json') manifestFile = file;
      if (name == 'products.json') productsFile = file;
    }

    if (manifestFile == null) {
      throw Exception('Invalid package: manifest.json missing');
    }
    if (productsFile == null) {
      throw Exception('Invalid package: products.json missing');
    }

    final payload = await _exportImportService.parsePayloadFromBytes(
      Uint8List.fromList((productsFile.content as List).cast<int>()),
    );

    final archiveFiles = <String, ArchiveFile>{};
    for (final file in archive) {
      if (file.isFile) {
        archiveFiles[file.name] = file;
      }
    }

    final restoredProducts = <ProductDTO>[];
    for (final product in payload.products) {
      final restoredPhotos = <ProductPhotoDTO>[];

      for (final photo in product.photos) {
        final archived = archiveFiles[photo.path];
        if (archived == null) continue;

        final bytes = Uint8List.fromList((archived.content as List).cast<int>());
        final dataUrl = _bytesToDataUrl(photo.path, bytes);
        restoredPhotos.add(
          ProductPhotoDTO(
            path: dataUrl,
            colorKey: photo.colorKey,
            isPrimary: photo.isPrimary,
            photoType: photo.photoType,
          ),
        );
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
          images: restoredPhotos
              .map((p) => ProductImageDTO.fromModel(p.toProductImage()))
              .toList(),
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

    final restoredCollections = <CategoryDTO>[];
    for (final collection in payload.collections) {
      String? coverMiniPath = collection.cover?.coverMiniPath;
      String? coverPagePath = collection.cover?.coverPagePath;

      if (collection.cover?.coverMiniPath != null) {
        final archived = archiveFiles[collection.cover!.coverMiniPath!];
        if (archived != null) {
          final bytes = Uint8List.fromList((archived.content as List).cast<int>());
          coverMiniPath = _bytesToDataUrl(collection.cover!.coverMiniPath!, bytes);
        }
      }

      if (collection.cover?.coverPagePath != null) {
        final archived = archiveFiles[collection.cover!.coverPagePath!];
        if (archived != null) {
          final bytes = Uint8List.fromList((archived.content as List).cast<int>());
          coverPagePath = _bytesToDataUrl(collection.cover!.coverPagePath!, bytes);
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
                  coverMiniPath: coverMiniPath,
                  coverPagePath: coverPagePath,
                )
              : null,
          createdAt: collection.createdAt,
          updatedAt: collection.updatedAt,
        ),
      );
    }

    final importPayload = CatalogoJaExportPayload(
      app: payload.app,
      version: payload.version,
      exportedAt: payload.exportedAt,
      store: payload.store,
      categories: payload.categories,
      collections: restoredCollections,
      products: restoredProducts,
    );

    final result = await _exportImportService.executeImport(importPayload, mode);
    return ImportReport(
      createdCount: result.successCount,
      updatedCount: 0,
      variantsCount: 0,
      createdCategoriesCount: 0,
      warnings: result.errors,
      importedProducts: restoredProducts.map((e) => e.toModel()).toList(),
    );
  }

  String _bytesToDataUrl(String filePath, Uint8List bytes) {
    final ext = p.extension(filePath).toLowerCase();
    final mime = switch (ext) {
      '.jpg' || '.jpeg' => 'image/jpeg',
      '.png' => 'image/png',
      '.webp' => 'image/webp',
      '.gif' => 'image/gif',
      '.bmp' => 'image/bmp',
      _ => 'application/octet-stream',
    };
    return 'data:$mime;base64,${base64Encode(bytes)}';
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
