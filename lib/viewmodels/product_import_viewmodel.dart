import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter/services.dart';
import 'package:gravity/core/auth/auth_controller.dart';
import 'package:gravity/core/auth/auth_guards.dart';
import 'package:gravity/data/repositories/contracts/categories_repository_contract.dart';
import 'package:gravity/data/repositories/categories_repository.dart';
import 'package:gravity/data/repositories/settings_repository.dart';
import 'package:gravity/data/repositories/products_repository.dart';
import 'package:gravity/core/services/image_optimizer_service.dart';
import 'package:gravity/models/category.dart';
import 'package:gravity/models/product.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:archive/archive.dart';
import 'package:gravity/core/services/gravity_package_service.dart';
import 'package:gravity/core/services/image_cache_service.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

part 'product_import_viewmodel.g.dart';

// State for Import Flow
class ProductImportState {
  final int currentStep;
  final List<List<dynamic>>? csvData; // Raw parsed CSV
  final List<Product> parsedProducts; // Products converted from CSV
  final List<String> matchedImages; // List of image paths found
  final int imagesMatchedCount;
  final int
  imagesTotalCount; // Total expected based on CSV SKU count or file upload count
  final double progress;
  final String? message;
  final bool isLoading;
  final String? errorMessage;
  final bool isDone;

  ProductImportState({
    this.currentStep = 0,
    this.csvData,
    this.parsedProducts = const [],
    this.matchedImages = const [],
    this.imagesMatchedCount = 0,
    this.imagesTotalCount = 0,
    this.progress = 0,
    this.message,
    this.isLoading = false,
    this.errorMessage,
    this.isDone = false,
  });

  ProductImportState copyWith({
    int? currentStep,
    List<List<dynamic>>? csvData,
    List<Product>? parsedProducts,
    List<String>? matchedImages,
    int? imagesMatchedCount,
    int? imagesTotalCount,
    double? progress,
    String? message,
    bool? isLoading,
    String? errorMessage,
    bool? isDone,
  }) {
    return ProductImportState(
      currentStep: currentStep ?? this.currentStep,
      csvData: csvData ?? this.csvData,
      parsedProducts: parsedProducts ?? this.parsedProducts,
      matchedImages: matchedImages ?? this.matchedImages,
      imagesMatchedCount: imagesMatchedCount ?? this.imagesMatchedCount,
      imagesTotalCount: imagesTotalCount ?? this.imagesTotalCount,
      progress: progress ?? this.progress,
      message: message ?? this.message,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
      isDone: isDone ?? this.isDone,
    );
  }
}

@riverpod
class ProductImportViewModel extends _$ProductImportViewModel {
  @override
  ProductImportState build() {
    return ProductImportState();
  }

  void nextStep() {
    state = state.copyWith(currentStep: state.currentStep + 1);
  }

  void prevStep() {
    state = state.copyWith(currentStep: state.currentStep - 1);
  }

  // Step 1: Download Template (No state change really, UI handles)
  // Step 2: Upload CSV
  Future<void> pickAndParseCsv() async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'zip'],
        withData: kIsWeb,
      );

      if (result != null) {
        final file = result.files.single;
        final ext = p.extension(file.name).toLowerCase();
        final ParsedImport parsed;

        if (ext == '.zip') {
          // Check for Gravity Package (manifest.json)
          final isGravity = await _isGravityPackage(file);
          if (isGravity) {
            try {
              if (file.path == null) {
                throw Exception(
                  'File path is null for Gravity Package on this platform.',
                );
              }
              final report = await ref
                  .read(gravityPackageServiceProvider)
                  .importPackage(File(file.path!));
              state = state.copyWith(
                isLoading: false,
                isDone: true,
                parsedProducts: report.importedProducts ?? [],
              );
              return;
            } catch (e) {
              state = state.copyWith(
                isLoading: false,
                errorMessage: "Erro ao importar pacote: $e",
              );
              return;
            }
          }
          parsed = await _parseZipPackage(file);
        } else {
          parsed = await _parseCsvFile(file);
        }

        state = state.copyWith(
          csvData: parsed.csvData,
          parsedProducts: parsed.products,
          imagesMatchedCount: parsed.imagesMatchedCount,
          imagesTotalCount: parsed.imagesTotalCount,
          isLoading: false,
        );
      } else {
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: "Erro ao ler CSV: $e",
      );
    }
  }

  // Step 3: Upload Images
  // Step 3: Upload Images
  Future<void> pickAndMatchImages() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
        withData: !kIsWeb, // Important: need bytes for Drive files
      );

      if (result != null) {
        Map<String, List<String>> productImages = {};
        int matched = 0;

        for (var file in result.files) {
          final matchedProduct = _findProductByKey(
            file.name,
            state.parsedProducts,
          );
          if (matchedProduct == null) continue;
          final copiedPath = await _resolveImageForPlatform(file);
          if (copiedPath != null) {
            productImages
                .putIfAbsent(matchedProduct.id, () => [])
                .add(copiedPath);
            matched++;
          }
        }

        final updatedProducts = state.parsedProducts.map((p) {
          if (productImages.containsKey(p.id)) {
            return p.copyWith(images: productImages[p.id]!);
          }
          return p;
        }).toList();

        state = state.copyWith(
          parsedProducts: updatedProducts,
          imagesMatchedCount: matched,
          imagesTotalCount: result.files.length,
          isLoading: false,
        );
      } else {
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: "Erro ao processar imagens: $e",
      );
    }
  }

  void reset() {
    state = ProductImportState();
  }

  /// New method to match images against products already in the database
  Future<void> pickAndMatchImagesToExistingProducts() async {
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      progress: 0.01,
      message: 'Selecione as fotos...',
    );
    try {
      final productsRepo = ref.read(productsRepositoryProvider);
      final existingProducts = await productsRepo.getProducts();

      debugPrint(
        'Vincular: Iniciando busca com ${existingProducts.length} produtos no banco',
      );

      if (existingProducts.isEmpty) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: "Nenhum produto cadastrado no app para vincular fotos.",
        );
        return;
      }

      // Use FileType.any with NO extensions on Android to get the most
      // compatible native picker that shows Drive and the 'Select' button correctly.
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
        withData: !kIsWeb, // Important: need bytes for Drive files
      );

      if (result == null || result.files.isEmpty) {
        state = state.copyWith(isLoading: false);
        return;
      }

      state = state.copyWith(
        message: 'Analisando fotos selecionadas...',
        progress: 0.1,
      );

      int matchedCount = 0;
      final productsToUpdate = <String, List<String>>{};
      final totalFiles = result.files.length;

      for (int i = 0; i < totalFiles; i++) {
        try {
          final file = result.files[i];

          state = state.copyWith(
            progress: 0.1 + (0.8 * ((i + 1) / totalFiles)),
            message: 'Analisando ${file.name}...',
          );

          final product = _findProductByKey(file.name, existingProducts);

          if (product != null) {
            debugPrint(
              'Vincular: Match encontrado para ${file.name} -> Produto: ${product.ref}',
            );
            final savedPath = await _resolveImageForPlatform(file);
            if (savedPath != null) {
              productsToUpdate.putIfAbsent(product.id, () => []).add(savedPath);
              matchedCount++;
            }
          } else {
            debugPrint(
              'Vincular: Nenhum produto encontrado para o arquivo ${file.name}',
            );
          }

          // Let UI breathe more frequently
          await Future.delayed(const Duration(milliseconds: 10));
        } catch (e) {
          debugPrint('Vincular: Erro ao processar arquivo $i: $e');
        }
      }

      state = state.copyWith(
        message: 'Salvando vinculações...',
        progress: 0.95,
      );

      // Update database
      for (final entry in productsToUpdate.entries) {
        final productId = entry.key;
        final importData =
            entry.value; // It's a list of file paths for this product
        final product = existingProducts.firstWhere((p) => p.id == productId);

        List<String> currentImages = List<String>.from(product.images);
        int mainImageIndex = product.mainImageIndex;

        for (final filePath in importData) {
          // Check if this image (normalized path or content) is already there
          // Since we copy with UUID, we check if the product already has
          // a lot of images or if we've reached a limit if necessary.
          // To strictly avoid duplicates, normally we would hash content,
          // but here we'll check if the name contains 'principal' to set order.

          final fileNameLower = p.basename(filePath).toLowerCase();

          if (fileNameLower.contains('principal')) {
            // Add to the beginning if not already there (simple check)
            if (!currentImages.contains(filePath)) {
              currentImages.insert(0, filePath);
              mainImageIndex = 0; // Point to the new first image
            }
          } else {
            // Append to the end (detalhes e cores)
            if (!currentImages.contains(filePath)) {
              currentImages.add(filePath);
            }
          }
        }

        await productsRepo.updateProduct(
          product.copyWith(
            images: currentImages,
            mainImageIndex: mainImageIndex,
          ),
        );
      }

      state = state.copyWith(
        isLoading: false,
        isDone: true,
        progress: 1.0,
        message: 'Concluído!',
        imagesMatchedCount: matchedCount,
        imagesTotalCount: totalFiles,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: "Erro ao vincular fotos: $e",
      );
    }
  }

  /// Syncs images from a remote URL pattern based on product reference
  Future<void> syncRemoteImagesFromUrl() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final settings = ref.read(settingsRepositoryProvider).getSettings();
      final baseUrl = settings.remoteImageBaseUrl.trim();

      if (baseUrl.isEmpty) {
        state = state.copyWith(
          isLoading: false,
          errorMessage:
              "URL Base não configurada. Vá em Ajustes para configurar.",
        );
        return;
      }

      final productsRepo = ref.read(productsRepositoryProvider);
      final products = await productsRepo.getProducts();
      final imageCache = ref.read(imageCacheServiceProvider);

      int syncedCount = 0;
      int totalToTry = 0;

      // Filter products that need images (optional: or all)
      final targets = products.where((p) => p.ref.isNotEmpty).toList();
      totalToTry = targets.length;

      if (totalToTry == 0) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: "Nenhum produto com referência encontrado.",
        );
        return;
      }

      final extensions = ['.jpg', '.jpeg', '.png', '.webp'];

      for (final p in targets) {
        final separator = baseUrl.endsWith('/') ? '' : '/';
        final cleanRef = p.ref.trim();

        for (final ext in extensions) {
          final imageUrl = "$baseUrl$separator$cleanRef$ext";
          final localPath = await imageCache.downloadAndCacheImage(imageUrl);

          if (localPath != null) {
            // Add to existing images if not already there
            if (!p.images.contains(localPath)) {
              final updatedImages = List<String>.from(p.images)..add(localPath);
              await productsRepo.updateProduct(
                p.copyWith(images: updatedImages),
              );
              syncedCount++;
            }
            break; // Found one extension, skip others for this product
          }
        }
      }

      state = state.copyWith(
        isLoading: false,
        isDone: true,
        imagesMatchedCount: syncedCount,
        imagesTotalCount: totalToTry,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: "Erro na sincronização remota: $e",
      );
    }
  }

  Future<ParsedImport> _parseCsvFile(PlatformFile file) async {
    final input = await _readCsvContent(file);
    return _parseCsvContent(input);
  }

  Future<bool> _isGravityPackage(PlatformFile file) async {
    try {
      final bytes = await _readFileBytes(file);
      final archive = ZipDecoder().decodeBytes(bytes);
      for (final entry in archive.files) {
        if (entry.name.toLowerCase() == 'manifest.json') {
          return true;
        }
      }
    } catch (e) {
      debugPrint('Error checking for manifest.json: $e');
    }
    return false;
  }

  Future<ParsedImport> _parseZipPackage(PlatformFile file) async {
    final bytes = await _readFileBytes(file);
    final archive = ZipDecoder().decodeBytes(bytes);

    ArchiveFile? csvEntry;
    for (final entry in archive.files) {
      if (!entry.isFile) continue;
      if (p.extension(entry.name).toLowerCase() == '.csv') {
        csvEntry = entry;
        if (p.basename(entry.name).toLowerCase() == 'products.csv') {
          break;
        }
      }
    }

    if (csvEntry == null) {
      throw Exception('Pacote ZIP sem arquivo CSV.');
    }

    final csvBytes = _archiveFileBytes(csvEntry);
    final input = utf8.decode(csvBytes);
    final rows = const CsvToListConverter().convert(input);
    if (rows.isEmpty) {
      throw Exception('Arquivo CSV vazio no pacote.');
    }

    final headerMap = _buildHeaderMap(rows.first);
    final skuIndex = _indexFor(headerMap, ['sku'], 0);
    final imageFilesIndex = _indexFor(headerMap, ['imagefiles'], -1);
    final skus = rows
        .skip(1)
        .map((row) => _cellValue(row, skuIndex).trim())
        .where((sku) => sku.isNotEmpty)
        .toList();

    final imageFilesBySku = <String, List<String>>{};
    if (imageFilesIndex >= 0) {
      for (final row in rows.skip(1)) {
        final sku = _normalizeSku(_cellValue(row, skuIndex));
        if (sku.isEmpty) continue;
        final listedFiles = _splitList(_cellValue(row, imageFilesIndex))
            .map((name) => p.basename(name).toLowerCase().trim())
            .where((name) => name.isNotEmpty)
            .toList();
        if (listedFiles.isNotEmpty) {
          imageFilesBySku[sku] = listedFiles;
        }
      }
    }

    final imagesBySku = await _extractImagesFromArchive(
      archive,
      skus,
      imageFilesBySku: imageFilesBySku,
    );
    final parsed = await _parseRowsToProducts(rows, imagesBySku: imagesBySku);
    return ParsedImport(
      csvData: rows,
      products: parsed.products,
      imagesMatchedCount: parsed.imagesMatchedCount,
      imagesTotalCount: parsed.imagesTotalCount,
    );
  }

  Future<ParsedImport> _parseCsvContent(String input) async {
    final rows = const CsvToListConverter().convert(input);
    if (rows.isEmpty) throw Exception("Arquivo vazio");
    return _parseRowsToProducts(rows);
  }

  Future<ParsedImport> _parseRowsToProducts(
    List<List<dynamic>> rows, {
    Map<String, List<String>>? imagesBySku,
  }) async {
    final headerMap = _buildHeaderMap(rows.first);
    final productsRepo = ref.read(productsRepositoryProvider);
    final categoriesRepo = ref.read(categoriesRepositoryProvider);
    final existingProducts = await productsRepo.getProducts();
    final existingBySku = {
      for (final p in existingProducts) _normalizeSku(p.sku): p,
    };

    final categories = (await categoriesRepo.getCategories())
        .where((c) => c.type == CategoryType.productType)
        .toList();
    final categoryById = {for (final c in categories) c.id: c.safeName};
    final categoryByName = {
      for (final c in categories) c.safeName.toLowerCase(): c.id,
    };

    final products = <Product>[];
    var imagesMatched = 0;

    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.isEmpty) continue;

      final name = _cellByKeys(row, headerMap, ['name', 'nome'], 1);
      final sku = _cellByKeys(row, headerMap, ['sku'], 0).trim();
      if (sku.isEmpty) continue;
      final skuKey = _normalizeSku(sku);
      final existing = existingBySku[skuKey];

      final categoryValue = _cellByKeys(row, headerMap, [
        'category',
        'categoryid',
        'categoria',
      ], 3).trim();
      final categoryId = await _resolveCategoryId(
        categoryValue,
        categoryById,
        categoryByName,
        categoriesRepo,
      );

      final reference = _cellByKeys(row, headerMap, ['ref', 'reference'], 2);
      final sizes = _splitList(_cellByKeys(row, headerMap, ['sizes'], 7));
      final colors = _splitList(_cellByKeys(row, headerMap, ['colors'], 8));

      final isActive = _parseBool(_cellByKeys(row, headerMap, ['isactive'], 9));
      final isOutOfStock = _parseBool(
        _cellByKeys(row, headerMap, ['isoutofstock'], 10),
      );

      final createdAt =
          _parseDateTime(_cellByKeys(row, headerMap, ['createdat'], 14)) ??
          existing?.createdAt ??
          DateTime.now();

      // Image URL Logic
      final remoteImagesRaw = _cellByKeys(row, headerMap, [
        'image urls',
        'image url',
        'url da imagem',
        'urls de imagem',
        'image',
        'images',
        'imagens',
      ], -1);

      final remoteImages = _splitList(
        remoteImagesRaw,
      ).where((u) => u.startsWith('http')).toList();
      var localImages = imagesBySku?[skuKey] ?? existing?.images ?? <String>[];

      // If we have remote images but no local images, try to download valid ones
      if (remoteImages.isNotEmpty && localImages.isEmpty) {
        final downloadedPaths = <String>[];
        final cacheService = ref.read(imageCacheServiceProvider);

        for (final url in remoteImages) {
          final path = await cacheService.downloadAndCacheImage(url);
          if (path != null) {
            downloadedPaths.add(path);
            imagesMatched++; // We count downloads as matches for progress
          }
        }
        if (downloadedPaths.isNotEmpty) {
          localImages = downloadedPaths;
        }
      }

      final mainImageIndexRaw =
          int.tryParse(_cellByKeys(row, headerMap, ['mainimageindex'], 13)) ??
          existing?.mainImageIndex ??
          0;
      final mainImageIndex = localImages.isEmpty
          ? 0
          : mainImageIndexRaw.clamp(0, localImages.length - 1);

      if (imagesBySku != null) {
        imagesMatched += localImages.length;
      }

      final priceRetail = _parsePrice(
        _cellByKeys(row, headerMap, ['retailprice', 'price', 'preco'], 4),
      );
      if (priceRetail <= 0) {
        continue;
      }

      final priceWholesale = _parsePrice(
        _cellByKeys(row, headerMap, ['wholesaleprice', 'priceatacado'], 5),
      );

      // Promotion logic unification
      double promoPercent = 0;
      bool promoEnabled = false;

      final promoPriceString = _cellByKeys(row, headerMap, [
        'promoprice',
        'promotionalprice',
        'saleprice',
        'precopromocional',
        'preco_promocional',
      ], -1);

      if (promoPriceString.isNotEmpty && promoPriceString != '-1') {
        final promoPrice = _parsePrice(promoPriceString);
        if (promoPrice > 0 && promoPrice < priceRetail) {
          promoPercent = (100 * (1 - (promoPrice / priceRetail)));
          promoPercent = promoPercent.clamp(0, 100);
          promoEnabled = promoPercent > 0;
        }
      } else {
        // Fallback to direct percent (exported format)
        promoEnabled = _parseBool(
          _cellByKeys(row, headerMap, ['isonsale', 'promoenabled'], 11),
        );
        promoPercent = _parsePrice(
          _cellByKeys(row, headerMap, [
            'salediscountpercent',
            'promopercent',
          ], 12),
        );
      }

      products.add(
        Product(
          id: existing?.id ?? const Uuid().v4(),
          name: name,
          ref: reference,
          sku: sku,
          categoryIds: categoryId.isNotEmpty ? [categoryId] : <String>[],
          priceRetail: priceRetail,
          priceWholesale: priceWholesale > 0 ? priceWholesale : priceRetail,
          minWholesaleQty:
              int.tryParse(_cellByKeys(row, headerMap, ['minqty'], 6)) ?? 1,
          sizes: sizes,
          colors: colors,
          images: localImages,
          remoteImages: remoteImages,
          mainImageIndex: mainImageIndex,
          isActive: isActive,
          isOutOfStock: isOutOfStock,
          promoEnabled: promoEnabled,
          createdAt: createdAt,
          promoPercent: promoPercent.toDouble(),
        ),
      );
    }

    return ParsedImport(
      csvData: rows,
      products: products,
      imagesMatchedCount: imagesMatched,
      imagesTotalCount: imagesBySku == null
          ? 0
          : imagesBySku.values.fold(0, (a, b) => a + b.length),
    );
  }

  Future<Map<String, List<String>>> _extractImagesFromArchive(
    Archive archive,
    List<String> skus, {
    Map<String, List<String>> imageFilesBySku = const {},
  }) async {
    final result = <String, List<String>>{};
    final normalizedSkus = skus
        .map(_normalizeSku)
        .where((sku) => sku.isNotEmpty)
        .toList();
    final archiveImagesByBaseName = <String, ArchiveFile>{};

    for (final entry in archive.files) {
      if (!entry.isFile) continue;
      final ext = p.extension(entry.name).toLowerCase();
      if (!['.jpg', '.jpeg', '.png', '.webp'].contains(ext)) continue;
      final baseName = p.basename(entry.name).toLowerCase();
      archiveImagesByBaseName[baseName] = entry;
    }

    for (final sku in normalizedSkus) {
      final declaredFiles = imageFilesBySku[sku] ?? const <String>[];
      for (final declared in declaredFiles) {
        final entry = archiveImagesByBaseName[declared];
        if (entry == null) continue;
        final bytes = _archiveFileBytes(entry);
        final savedPath = await _writeImageBytesToPersistentStorage(
          bytes,
          declared,
        );
        if (savedPath != null) {
          result.putIfAbsent(sku, () => []).add(savedPath);
          archiveImagesByBaseName.remove(declared);
        }
      }
    }

    for (final archiveEntry in archiveImagesByBaseName.entries) {
      final baseName = archiveEntry.key;
      final normalizedBaseName = _normalizeForImageMatch(
        p.basenameWithoutExtension(baseName),
      );
      for (final sku in normalizedSkus) {
        if (sku.isEmpty) continue;
        final skuForMatch = _normalizeForImageMatch(sku);
        if (skuForMatch.isEmpty) continue;
        if (!normalizedBaseName.startsWith(skuForMatch)) continue;
        final entry = archiveEntry.value;
        final bytes = _archiveFileBytes(entry);
        final savedPath = await _writeImageBytesToPersistentStorage(
          bytes,
          baseName,
        );
        if (savedPath != null) {
          result.putIfAbsent(sku, () => []).add(savedPath);
        }
        break;
      }
    }

    for (final sku in result.keys) {
      result[sku]!.sort();
    }
    return result;
  }

  Future<String?> _writeImageBytesToPersistentStorage(
    Uint8List bytes,
    String originalName,
  ) async {
    try {
      final baseDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory(p.join(baseDir.path, 'product_images'));
      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }
      final ext = p.extension(originalName).isNotEmpty
          ? p.extension(originalName).toLowerCase()
          : '.jpg';
      final fileName = '${const Uuid().v4()}$ext';
      final targetPath = p.join(imagesDir.path, fileName);
      final optimizer = ref.read(imageOptimizerServiceProvider.notifier);
      final optimized = await optimizer.compressBytes(bytes) ?? bytes;
      await File(targetPath).writeAsBytes(optimized);
      return targetPath;
    } on MissingPluginException {
      return null;
    }
  }

  Uint8List _archiveFileBytes(ArchiveFile entry) => entry.content;

  Future<Uint8List> _readFileBytes(PlatformFile file) async {
    if (kIsWeb) {
      final bytes = file.bytes;
      if (bytes == null) {
        throw Exception('Arquivo sem bytes (web)');
      }
      return bytes;
    }
    if (file.path != null) {
      return File(file.path!).readAsBytes();
    }
    final bytes = file.bytes;
    if (bytes == null) {
      throw Exception('Arquivo sem path/bytes');
    }
    return bytes;
  }

  Map<String, int> _buildHeaderMap(List<dynamic> headerRow) {
    final map = <String, int>{};
    for (var i = 0; i < headerRow.length; i++) {
      final key = headerRow[i].toString().trim().toLowerCase();
      if (key.isNotEmpty) {
        map[key] = i;
      }
    }
    return map;
  }

  int _indexFor(Map<String, int> headerMap, List<String> keys, int fallback) {
    for (final key in keys) {
      final idx = headerMap[key.toLowerCase()];
      if (idx != null) return idx;
    }
    return fallback;
  }

  String _cellValue(List<dynamic> row, int index) {
    if (index < 0 || index >= row.length) return '';
    return row[index].toString();
  }

  String _cellByKeys(
    List<dynamic> row,
    Map<String, int> headerMap,
    List<String> keys,
    int fallbackIndex,
  ) {
    final index = _indexFor(headerMap, keys, fallbackIndex);
    return _cellValue(row, index);
  }

  bool _parseBool(String value) {
    final v = value.trim().toLowerCase();
    return v == 'true' || v == '1' || v == 'sim' || v == 'yes' || v == 'y';
  }

  List<String> _splitList(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return [];
    final separator = trimmed.contains('|') ? '|' : ',';
    return trimmed
        .split(separator)
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  String _normalizeSku(String sku) {
    return sku.trim().toLowerCase();
  }

  String _normalizeForImageMatch(String value) {
    // Remove extension, leading/trailing spaces, and convert to lower
    String v = value.toLowerCase().trim();
    // Remove common separators to make it easier to match
    v = v.replaceAll(RegExp(r'[-_\s]'), '');
    return v;
  }

  String _normalizeReference(String ref) {
    // Normalize a reference by removing leading zeros for flexible matching
    // but keep a version with zeros as well.
    return ref.trim().toLowerCase().replaceAll(RegExp(r'[-_\s]'), '');
  }

  Product? _findProductByKey(String fileName, List<Product> products) {
    final fileNameNoExt = p
        .basenameWithoutExtension(fileName)
        .toLowerCase()
        .trim();
    final normalizedFileName = _normalizeForImageMatch(fileNameNoExt);

    for (final product in products) {
      // 1. Try Reference (Primary for this user)
      final ref = product.ref.trim().toLowerCase();
      if (ref.isNotEmpty) {
        final normalizedRef = _normalizeReference(ref);
        final normalizedRefNoZeros = normalizedRef.replaceFirst(
          RegExp(r'^0+'),
          '',
        );

        // Exact match of normalized names
        if (normalizedFileName == normalizedRef) return product;

        // Match if the filename is exactly the reference with or without leading zeros
        if (normalizedRefNoZeros.isNotEmpty) {
          final normalizedFileNoZeros = normalizedFileName.replaceFirst(
            RegExp(r'^0+'),
            '',
          );
          if (normalizedFileNoZeros == normalizedRefNoZeros) return product;
        }

        // Match if the filename STARTS with the reference (e.g., "00003_azul.jpg" matches "00003")
        if (normalizedFileName.startsWith(normalizedRef)) return product;
      }

      // 2. Try SKU (Fallback)
      final sku = product.sku.trim().toLowerCase();
      if (sku.isNotEmpty) {
        final normalizedSku = _normalizeReference(sku);
        if (normalizedFileName == normalizedSku ||
            normalizedFileName.startsWith(normalizedSku)) {
          return product;
        }
      }
    }
    return null;
  }

  DateTime? _parseDateTime(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    return DateTime.tryParse(trimmed);
  }

  Future<String> _resolveCategoryId(
    String categoryValue,
    Map<String, String> categoryById,
    Map<String, String> categoryByName,
    CategoriesRepositoryContract categoriesRepo,
  ) async {
    if (categoryValue.isEmpty) {
      if (categoryById.keys.isNotEmpty) return categoryById.keys.first;
      return _createCategory(
        'Sem categoria',
        categoryById,
        categoryByName,
        categoriesRepo,
      );
    }
    if (categoryById.containsKey(categoryValue)) {
      return categoryValue;
    }
    final key = categoryValue.toLowerCase();
    final existingId = categoryByName[key];
    if (existingId != null) return existingId;
    return _createCategory(
      categoryValue,
      categoryById,
      categoryByName,
      categoriesRepo,
    );
  }

  Future<String> _createCategory(
    String name,
    Map<String, String> categoryById,
    Map<String, String> categoryByName,
    CategoriesRepositoryContract categoriesRepo,
  ) async {
    final now = DateTime.now();
    final category = Category(
      id: const Uuid().v4(),
      name: name,
      order: categoryByName.length + 1,
      createdAt: now,
      updatedAt: now,
      type: CategoryType.productType,
      slug: Category.generateSlug(name),
    );
    await categoriesRepo.addCategory(category);
    categoryById[category.id] = category.safeName;
    categoryByName[category.safeName.toLowerCase()] = category.id;
    return category.id;
  }

  // Finalize
  Future<void> finalizeImport() async {
    final user = ref.read(currentUserProvider);
    if (!isAdmin(user)) {
      throw Exception('Sem permissão para importar produtos.');
    }
    state = state.copyWith(isLoading: true);
    try {
      final repository = ref.read(productsRepositoryProvider);

      for (var p in state.parsedProducts) {
        await repository.addProduct(p);
      }

      state = state.copyWith(isLoading: false, isDone: true);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: "Erro ao salvar: $e",
      );
    }
  }

  double _parsePrice(String text) {
    if (text.isEmpty) return 0.0;
    String cleaned = text
        .replaceAll(',', '.')
        .replaceAll(RegExp(r'[^0-9.]'), '');
    if (cleaned.split('.').length > 2) {
      final parts = cleaned.split('.');
      final decimal = parts.removeLast();
      cleaned = '${parts.join('')}.$decimal';
    }
    return double.tryParse(cleaned) ?? 0.0;
  }

  Future<String> _readCsvContent(PlatformFile file) async {
    if (kIsWeb) {
      final bytes = file.bytes;
      if (bytes == null) {
        throw Exception('Arquivo CSV sem bytes (web)');
      }
      return utf8.decode(bytes);
    }

    if (file.path != null) {
      final ioFile = File(file.path!);
      return ioFile.readAsString();
    }

    final bytes = file.bytes;
    if (bytes == null) {
      throw Exception('Arquivo CSV sem path/bytes');
    }
    return utf8.decode(bytes);
  }

  Future<String?> _resolveImageForPlatform(PlatformFile file) async {
    try {
      final baseDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory(p.join(baseDir.path, 'product_images'));
      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }
      final ext = p.extension(file.name).isNotEmpty
          ? p.extension(file.name).toLowerCase()
          : '.jpg';
      final fileName = '${const Uuid().v4()}$ext';
      final targetPath = p.join(imagesDir.path, fileName);
      final optimizer = ref.read(imageOptimizerServiceProvider.notifier);

      if (kIsWeb) {
        if (file.bytes == null) return null;
        final optimized =
            await optimizer.compressBytes(file.bytes!) ?? file.bytes!;
        await File(targetPath).writeAsBytes(optimized);
        return targetPath;
      } else {
        // 1. Try local path first (faster)
        if (file.path != null) {
          final sourceFile = File(file.path!);
          if (await sourceFile.exists()) {
            final optimizedFile = await optimizer.compressImage(sourceFile);
            if (optimizedFile != null) {
              await optimizedFile.copy(targetPath);
              return targetPath;
            } else {
              await sourceFile.copy(targetPath);
              return targetPath;
            }
          }
        }
        // 2. Fallback for cloud files (Drive)
        if (file.bytes != null) {
          final optimized =
              await optimizer.compressBytes(file.bytes!) ?? file.bytes!;
          await File(targetPath).writeAsBytes(optimized);
          return targetPath;
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error resolving image: $e');
      return null;
    }
  }
}

class ParsedImport {
  final List<List<dynamic>> csvData;
  final List<Product> products;
  final int imagesMatchedCount;
  final int imagesTotalCount;

  ParsedImport({
    required this.csvData,
    required this.products,
    required this.imagesMatchedCount,
    required this.imagesTotalCount,
  });
}
