import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter/services.dart';
import 'package:gravity/core/auth/auth_controller.dart';
import 'package:gravity/core/auth/auth_guards.dart';
import 'package:gravity/data/repositories/contracts/categories_repository_contract.dart';
import 'package:gravity/data/repositories/categories_repository.dart';
import 'package:gravity/data/repositories/products_repository.dart';
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
  Future<void> pickAndMatchImages() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
        withData: kIsWeb,
      );

      if (result != null) {
        Map<String, List<String>> productImages = {};
        int matched = 0;

        for (var file in result.files) {
          if (!kIsWeb && file.path == null) continue;
          final matchedProduct = _findProductBySkuPrefix(
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
      await File(targetPath).writeAsBytes(bytes);
      return targetPath;
    } on MissingPluginException {
      return null;
    }
  }

  Uint8List _archiveFileBytes(ArchiveFile entry) {
    final content = entry.content;
    if (content is Uint8List) return content;
    if (content is List<int>) return Uint8List.fromList(content);
    return Uint8List.fromList(const []);
  }

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

  Product? _findProductBySkuPrefix(String fileName, List<Product> products) {
    final lower = fileName.toLowerCase();
    final normalizedFile = _normalizeForImageMatch(
      p.basenameWithoutExtension(lower),
    );
    for (final product in products) {
      final sku = product.sku.trim();
      if (sku.isEmpty) continue;
      final normalizedSku = _normalizeForImageMatch(sku);
      if (lower.startsWith(sku.toLowerCase()) ||
          (normalizedSku.isNotEmpty &&
              normalizedFile.startsWith(normalizedSku))) {
        return product;
      }
    }
    return null;
  }

  String _normalizeForImageMatch(String input) {
    return input.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
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

  String _inferMimeType(String fileName) {
    final ext = p.extension(fileName).toLowerCase();
    switch (ext) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.webp':
        return 'image/webp';
      default:
        return 'application/octet-stream';
    }
  }

  Future<String?> _resolveImageForPlatform(PlatformFile file) async {
    if (kIsWeb) {
      final bytes = file.bytes;
      if (bytes == null) return null;
      final mime = _inferMimeType(file.name);
      return 'data:$mime;base64,${base64Encode(bytes)}';
    }

    if (file.path == null) return null;
    return _copyImageToPersistentStorage(file.path!);
  }

  Future<String?> _copyImageToPersistentStorage(String sourcePath) async {
    try {
      final baseDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory(p.join(baseDir.path, 'product_images'));
      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }
      final fileName = '${const Uuid().v4()}${p.extension(sourcePath)}';
      final targetPath = p.join(imagesDir.path, fileName);
      final File targetFile = File(targetPath);

      final sourceFile = File(sourcePath);
      if (await sourceFile.exists()) {
        final bytes = await sourceFile.readAsBytes();
        await targetFile.writeAsBytes(bytes);
        return targetPath;
      }
      return null;
    } on MissingPluginException {
      if (kDebugMode) {
        print(
          'MissingPluginException: path_provider not implemented on this platform or stale build.',
        );
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Failed to copy import image: $e');
      }
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
