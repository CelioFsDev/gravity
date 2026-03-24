import 'dart:convert';
import 'dart:io' as io;
import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart' hide Category;
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
          String baseName = '';
          if (imagePath.startsWith('data:')) {
            baseName = 'photo_${DateTime.now().millisecondsSinceEpoch}_$i';
          } else {
            baseName = p.basenameWithoutExtension(imagePath);
          }
          if (baseName.length > 50) baseName = baseName.substring(0, 50);
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
      String? newHeaderPath = collection.cover?.coverHeaderImagePath;
      String? newMainPath = collection.cover?.coverMainImagePath;
      String? newBannerPath = collection.cover?.bannerImagePath;
      String? newHeroPath = collection.cover?.heroImagePath;

      if (collection.cover != null) {
        // Helper to process collection image
        Future<String?> processCollectionImage(String? path, String suffix) async {
          if (path == null) return null;
          final bytes = await _readImageBytes(path);
          if (bytes != null) {
            final ext = p.extension(path).isEmpty ? '.jpg' : p.extension(path);
            final relPath = 'images/collections/${collection.id}/$suffix$ext';
            archive.addFile(ArchiveFile(relPath, bytes.length, bytes));
            imageCount++;
            return relPath;
          }
          return path;
        }

        newMiniPath = await processCollectionImage(collection.cover!.coverMiniPath, 'mini');
        newPagePath = await processCollectionImage(collection.cover!.coverPagePath, 'page');
        newHeaderPath = await processCollectionImage(collection.cover!.coverHeaderImagePath, 'header');
        newMainPath = await processCollectionImage(collection.cover!.coverMainImagePath, 'main');
        newBannerPath = await processCollectionImage(collection.cover!.bannerImagePath, 'banner');
        newHeroPath = await processCollectionImage(collection.cover!.heroImagePath, 'hero');
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
                  coverHeaderImagePath: newHeaderPath,
                  coverMainImagePath: newMainPath,
                  bannerImagePath: newBannerPath,
                  heroImagePath: newHeroPath,
                )
              : null,
          createdAt: collection.createdAt,
          updatedAt: collection.updatedAt,
        ),
      );
    }

    // 2.3 Process Catalog Banners
    final updatedCatalogs = <CatalogDTO>[];
    for (final catalog in payload.catalogs) {
      final updatedBanners = <CatalogBannerDTO>[];
      for (final banner in catalog.banners) {
        if (banner.imagePath.isNotEmpty) {
          final bytes = await _readImageBytes(banner.imagePath);
          if (bytes != null) {
            final ext = p.extension(banner.imagePath).isEmpty ? '.jpg' : p.extension(banner.imagePath);
            final relPath = 'images/catalogs/${catalog.id}/${banner.id}$ext';
            archive.addFile(ArchiveFile(relPath, bytes.length, bytes));
            imageCount++;
            updatedBanners.add(banner.copyWith(imagePath: relPath));
          } else {
            updatedBanners.add(banner);
          }
        } else {
          updatedBanners.add(banner);
        }
      }
      updatedCatalogs.add(
        catalog.copyWith(banners: updatedBanners),
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
      catalogs: updatedCatalogs,
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

    final tempDir = await getTemporaryDirectory();
    final extractDir = io.Directory(
      p.join(
        tempDir.path,
        'CatalogoJa_import_prepare_${DateTime.now().millisecondsSinceEpoch}',
      ),
    );
    await extractDir.create(recursive: true);

    // Run unzipping in background isolate for performance and memory safety
    await compute(_unzipTask, {
      'zipPath': zipFile.path,
      'extractPath': extractDir.path,
    });

    // Validate and Read Products
    final productsFile = io.File(p.join(extractDir.path, 'products.json'));
    if (!await productsFile.exists()) {
      throw Exception('Invalid package: products.json missing');
    }

    final payload = await _exportImportService.parsePayload(productsFile);
    return (payload, extractDir);
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
          final newName = _buildSafeImportedFileName(
            prefix: product.id,
            originalPath: photo.path,
          );
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
      String? absHeaderPath = collection.cover?.coverHeaderImagePath;
      String? absMainPath = collection.cover?.coverMainImagePath;
      String? absBannerPath = collection.cover?.bannerImagePath;
      String? absHeroPath = collection.cover?.heroImagePath;

      if (collection.cover != null) {
        Future<String?> restoreCollectionImage(String? relPath, String suffix) async {
          if (relPath == null) return null;
          final sourceFile = io.File(p.join(extractDir.path, relPath));
          if (await sourceFile.exists()) {
            final newName = _buildSafeImportedFileName(
              prefix: 'coll_${collection.id}_$suffix',
              originalPath: relPath,
              fallbackExtension: p.extension(sourceFile.path),
            );
            final targetFile = io.File(p.join(appImagesDir.path, newName));
            await sourceFile.copy(targetFile.path);
            return targetFile.path;
          }
          return relPath;
        }

        absMiniPath = await restoreCollectionImage(collection.cover!.coverMiniPath, 'mini');
        absPagePath = await restoreCollectionImage(collection.cover!.coverPagePath, 'page');
        absHeaderPath = await restoreCollectionImage(collection.cover!.coverHeaderImagePath, 'header');
        absMainPath = await restoreCollectionImage(collection.cover!.coverMainImagePath, 'main');
        absBannerPath = await restoreCollectionImage(collection.cover!.bannerImagePath, 'banner');
        absHeroPath = await restoreCollectionImage(collection.cover!.heroImagePath, 'hero');
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
                  coverHeaderImagePath: absHeaderPath,
                  coverMainImagePath: absMainPath,
                  bannerImagePath: absBannerPath,
                  heroImagePath: absHeroPath,
                )
              : null,
          createdAt: collection.createdAt,
          updatedAt: collection.updatedAt,
        ),
      );
    }

    // 4.3 Restore Catalog Banners
    final restoredCatalogs = <CatalogDTO>[];
    for (final catalog in payload.catalogs) {
      final restoredBanners = <CatalogBannerDTO>[];
      for (final banner in catalog.banners) {
        if (banner.imagePath.isNotEmpty) {
          final sourceFile = io.File(p.join(extractDir.path, banner.imagePath));
          if (await sourceFile.exists()) {
            final newName = _buildSafeImportedFileName(
              prefix: 'cat_${catalog.id}',
              originalPath: banner.imagePath,
            );
            final targetFile = io.File(p.join(appImagesDir.path, newName));
            await sourceFile.copy(targetFile.path);
            restoredBanners.add(banner.copyWith(imagePath: targetFile.path));
          } else {
            restoredBanners.add(banner);
          }
        } else {
          restoredBanners.add(banner);
        }
      }
      restoredCatalogs.add(catalog.copyWith(banners: restoredBanners));
    }

    final importPayload = CatalogoJaExportPayload(
      app: payload.app,
      version: payload.version,
      exportedAt: payload.exportedAt,
      store: payload.store,
      categories: payload.categories,
      collections: restoredCollections,
      products: restoredProducts,
      catalogs: restoredCatalogs,
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
      String? coverHeaderPath = collection.cover?.coverHeaderImagePath;
      String? coverMainPath = collection.cover?.coverMainImagePath;
      String? bannerPath = collection.cover?.bannerImagePath;
      String? heroPath = collection.cover?.heroImagePath;

      String? restoreFromArchive(String? relPath) {
        if (relPath == null) return null;
        final archived = archiveFiles[relPath];
        if (archived != null) {
          final bytes = Uint8List.fromList((archived.content as List).cast<int>());
          return _bytesToDataUrl(relPath, bytes);
        }
        return relPath;
      }

      coverMiniPath = restoreFromArchive(collection.cover?.coverMiniPath);
      coverPagePath = restoreFromArchive(collection.cover?.coverPagePath);
      coverHeaderPath = restoreFromArchive(collection.cover?.coverHeaderImagePath);
      coverMainPath = restoreFromArchive(collection.cover?.coverMainImagePath);
      bannerPath = restoreFromArchive(collection.cover?.bannerImagePath);
      heroPath = restoreFromArchive(collection.cover?.heroImagePath);

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
                  coverHeaderImagePath: coverHeaderPath,
                  coverMainImagePath: coverMainPath,
                  bannerImagePath: bannerPath,
                  heroImagePath: heroPath,
                )
              : null,
          createdAt: collection.createdAt,
          updatedAt: collection.updatedAt,
        ),
      );
    }

    final restoredCatalogs = <CatalogDTO>[];
    for (final catalog in payload.catalogs) {
      final restoredBanners = <CatalogBannerDTO>[];
      for (final banner in catalog.banners) {
        if (banner.imagePath.isNotEmpty) {
          final archived = archiveFiles[banner.imagePath];
          if (archived != null) {
            final bytes = Uint8List.fromList((archived.content as List).cast<int>());
            final dataUrl = _bytesToDataUrl(banner.imagePath, bytes);
            restoredBanners.add(banner.copyWith(imagePath: dataUrl));
          } else {
            restoredBanners.add(banner);
          }
        } else {
          restoredBanners.add(banner);
        }
      }
      restoredCatalogs.add(catalog.copyWith(banners: restoredBanners));
    }

    final importPayload = CatalogoJaExportPayload(
      app: payload.app,
      version: payload.version,
      exportedAt: payload.exportedAt,
      store: payload.store,
      categories: payload.categories,
      collections: restoredCollections,
      products: restoredProducts,
      catalogs: restoredCatalogs,
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

  String _buildSafeImportedFileName({
    required String prefix,
    required String originalPath,
    String? fallbackExtension,
  }) {
    final normalizedPath = originalPath.replaceAll('\\', '/');
    final baseName = p.posix.basename(normalizedPath);
    String extension = p.posix.extension(baseName).isNotEmpty
        ? p.posix.extension(baseName)
        : (fallbackExtension?.isNotEmpty == true ? fallbackExtension! : '.jpg');
        
    if (extension.length > 10) {
      extension = extension.substring(0, 10);
    }
    
    final baseWithoutExtension = p.posix.basenameWithoutExtension(baseName);
    String safeBase = _sanitizePathSegment(baseWithoutExtension);
    
    if (safeBase.length > 80) {
      safeBase = '${safeBase.substring(0, 80)}_${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
    }
    
    final safePrefix = _sanitizePathSegment(prefix);
    return '${safePrefix}_${safeBase.isEmpty ? 'image' : safeBase}$extension';
  }

  String _sanitizePathSegment(String value) {
    return value.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]+'), '_').trim();
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


/// Top-level function for background ZIP extraction via compute
Future<void> _unzipTask(Map<String, String> args) async {
  final zipPath = args['zipPath']!;
  final extractPath = args['extractPath']!;

  final bytes = io.File(zipPath).readAsBytesSync();
  final archive = ZipDecoder().decodeBytes(bytes);

  for (final file in archive) {
    final filename = file.name;
    final destPath = p.join(extractPath, filename);
    if (file.isFile) {
      final outputStream = OutputFileStream(destPath);
      file.writeContent(outputStream);
      outputStream.close();
    } else {
      io.Directory(destPath).createSync(recursive: true);
    }
  }
  
}
