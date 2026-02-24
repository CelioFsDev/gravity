import 'package:file_picker/file_picker.dart';
import 'package:catalogo_ja/core/importer/nuvemshop_api_client.dart';
import 'package:catalogo_ja/core/importer/nuvemshop_csv_reader.dart';
import 'package:catalogo_ja/core/importer/nuvemshop_forward_fill.dart';
import 'package:catalogo_ja/core/importer/nuvemshop_category_mapper.dart';
import 'package:catalogo_ja/core/importer/parse_utils.dart';
import 'package:catalogo_ja/data/repositories/contracts/categories_repository_contract.dart';
import 'package:catalogo_ja/data/repositories/contracts/products_repository_contract.dart';
import 'package:catalogo_ja/models/category.dart';
import 'package:catalogo_ja/models/product.dart';
import 'package:catalogo_ja/models/product_variant.dart';
import 'package:flutter/foundation.dart' hide Category;
import 'package:catalogo_ja/core/services/image_cache_service.dart';
import 'package:catalogo_ja/core/utils/encoding_utils.dart';
import 'package:uuid/uuid.dart';

class ImportOptions {
  final bool updateExisting;
  final bool createNew;

  const ImportOptions({this.updateExisting = true, this.createNew = true});
}

class ImportReport {
  final int createdCount;
  final int updatedCount;
  final int variantsCount;
  final int createdCategoriesCount;
  final List<String> warnings;

  const ImportReport({
    required this.createdCount,
    required this.updatedCount,
    required this.variantsCount,
    required this.createdCategoriesCount,
    required this.warnings,
  });
}

class NuvemshopImportService {
  final ProductsRepositoryContract productsRepository;
  final CategoriesRepositoryContract categoriesRepository;
  final ImageCacheService? imageCacheService;
  final NuvemshopApiClient? nuvemshopApiClient;

  NuvemshopImportService({
    required this.productsRepository,
    required this.categoriesRepository,
    this.imageCacheService,
    this.nuvemshopApiClient,
  });

  Future<ImportReport> importCsvFile(
    PlatformFile file, {
    ImportOptions options = const ImportOptions(),
    void Function(double progress)? onProgress,
    void Function(String status)? onStatus,
  }) async {
    debugPrint('Iniciando importa\u00e7\u00e3o Nuvemshop: ${file.name}');
    onStatus?.call('Lendo CSV...');
    final table = await NuvemshopCsvReader.readFromPlatformFile(file);
    debugPrint('Colunas encontradas no CSV: ${table.headers.join(', ')}');
    onStatus?.call('Organizando dados...');

    // First, normalize all row keys to standard keys for easier processing
    final normalizedRawRows = table.rows.map((r) => _normalizeRow(r)).toList();

    final rows = forwardFill(normalizedRawRows, _columnsToFill);

    final grouped = <String, List<Map<String, String>>>{};
    for (final row in rows) {
      final groupKey = _productGroupKey(row);
      if (groupKey.isEmpty) {
        continue;
      }
      grouped.putIfAbsent(groupKey, () => []).add(row);
    }

    debugPrint('Produtos agrupados: ${grouped.length}');
    if (grouped.isEmpty) {
      debugPrint(
        'Aviso: Nenhum produto encontrado para agrupamento (Slug ou SKU vazios).',
      );
      return const ImportReport(
        createdCount: 0,
        updatedCount: 0,
        variantsCount: 0,
        createdCategoriesCount: 0,
        warnings: [
          'Nenhum produto encontrado no CSV. Verifique se h\u00e1 ao menos Nome ou SKU preenchidos.',
        ],
      );
    }

    onStatus?.call('Carregando produtos e categorias locais...');
    final allProducts = await productsRepository.getProducts();
    final byRef = {for (final p in allProducts) p.reference.toLowerCase(): p};

    final allCategories = await categoriesRepository.getCategories();
    final categoryByKey = {
      for (final c in allCategories) _normalizeKey(c.safeName, c.type): c,
    };

    var created = 0;
    var updated = 0;
    var variantsCount = 0;
    var createdCategories = 0;
    final warnings = <String>[];

    final entries = grouped.entries.toList();
    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      debugPrint(
        'Processando produto ${i + 1}/${entries.length}: ${entry.key}',
      );
      onProgress?.call((i + 1) / entries.length);
      onStatus?.call('Processando ${i + 1}/${entries.length}: ${entry.key}');

      // Normalize all rows in this group to use standard keys
      final groupRows = entry.value.map((r) => _normalizeRow(r)).toList();
      final row = groupRows.first;

      final name = EncodingUtils.fixGarbledString(_value(row, 'nome'));
      final slugFromCsv = _value(row, 'identificador url');
      final slug = slugFromCsv.isNotEmpty ? slugFromCsv : _slugFromName(name);
      final description = EncodingUtils.fixGarbledString(
        _value(row, 'descricao'),
      );
      final tags = splitCsvList(
        EncodingUtils.fixGarbledString(_value(row, 'tags')),
      );
      final categoriesNames = parseCategoryNames(
        EncodingUtils.fixGarbledString(_value(row, 'categorias')),
      );
      final collectionName = EncodingUtils.fixGarbledString(
        detectCollectionName(tags) ?? '',
      );

      final priceRetail = parseMoney(_value(row, 'preco'));
      if (priceRetail <= 0) {
        warnings.add('Pre\u00e7o inv\u00e1lido para "$name". Linha ignorada.');
        continue;
      }

      final priceWholesaleInput = parseMoney(_value(row, 'preco atacado'));
      final priceWholesale = priceWholesaleInput > 0
          ? priceWholesaleInput
          : priceRetail;

      final promoPrice = parseMoney(_value(row, 'preco promocional'));
      var promoPercent = 0.0;
      var promoEnabled = false;
      if (promoPrice > 0 && promoPrice < priceRetail) {
        promoPercent = 100 * (1 - (promoPrice / priceRetail));
        promoPercent = promoPercent.clamp(0, 100);
        promoEnabled = promoPercent > 0;
      }

      final firstSku = _firstNonEmpty(groupRows, 'sku');
      final safeSku = firstSku.isNotEmpty ? firstSku : slug;
      final ref = _extractRef(safeSku).isNotEmpty ? _extractRef(safeSku) : slug;
      final existing = byRef[ref.toLowerCase()];
      final remoteImages = await _resolveRemoteImages(
        groupRows,
        sku: safeSku,
        productLabel: name.isNotEmpty ? name : slug,
        onStatus: onStatus,
      );

      final categoryIds = <String>[];
      if (collectionName.isNotEmpty) {
        final id = await _getOrCreateCategory(
          categoryByKey,
          collectionName,
          CategoryType.collection,
        );
        if (id.created) createdCategories++;
        categoryIds.add(id.id);
      }
      for (final catName in categoriesNames) {
        final id = await _getOrCreateCategory(
          categoryByKey,
          catName,
          CategoryType.productType,
        );
        if (id.created) createdCategories++;
        categoryIds.add(id.id);
      }

      final variantData = _buildVariants(groupRows);
      final variants = variantData.variants;
      final productColors = variantData.colors;
      final productSizes = variantData.sizes;

      variantsCount += variants.length;

      if (existing == null && options.createNew) {
        final product = Product(
          id: const Uuid().v4(),
          name: name,
          ref: ref,
          sku: safeSku,
          slug: slug,
          description: description.isEmpty ? null : description,
          tags: tags,
          remoteImages: remoteImages,
          categoryIds: categoryIds.toSet().toList(),
          priceRetail: priceRetail,
          priceWholesale: priceWholesale,
          minWholesaleQty: 1,
          sizes: productSizes,
          colors: productColors,
          images: await _downloadImagesIfNecessary(
            remoteImages,
            productLabel: name.isNotEmpty ? name : slug,
            onStatus: onStatus,
          ),
          mainImageIndex: 0,
          isActive: true,
          isOutOfStock: false,
          promoEnabled: promoEnabled,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          promoPercent: promoPercent,
          variants: variants,
        );
        await productsRepository.addProduct(product);
        created++;
      } else if (existing != null && options.updateExisting) {
        final updatedProduct = existing.copyWith(
          name: name,
          slug: slug,
          description: description.isEmpty ? null : description,
          tags: tags,
          remoteImages: remoteImages,
          categoryIds: categoryIds.toSet().toList(),
          priceRetail: priceRetail,
          priceWholesale: priceWholesaleInput > 0
              ? priceWholesaleInput
              : (existing.priceWholesale > 0
                    ? existing.priceWholesale
                    : priceRetail),
          sizes: productSizes.isNotEmpty ? productSizes : existing.sizes,
          colors: productColors.isNotEmpty ? productColors : existing.colors,
          images: (existing.images.isEmpty)
              ? await _downloadImagesIfNecessary(
                  remoteImages,
                  productLabel: name.isNotEmpty ? name : slug,
                  onStatus: onStatus,
                )
              : existing.images,
          promoEnabled: promoEnabled,
          promoPercent: promoPercent,
          variants: variants.isNotEmpty ? variants : existing.variants,
          updatedAt: DateTime.now(),
        );
        await productsRepository.updateProduct(updatedProduct);
        updated++;
      }
    }

    return ImportReport(
      createdCount: created,
      updatedCount: updated,
      variantsCount: variantsCount,
      createdCategoriesCount: createdCategories,
      warnings: warnings,
    );
  }

  Future<_CategoryResult> _getOrCreateCategory(
    Map<String, Category> cache,
    String name,
    CategoryType type,
  ) async {
    final key = _normalizeKey(name, type);
    final existing = cache[key];
    if (existing != null) {
      return _CategoryResult(id: existing.id, created: false);
    }

    final now = DateTime.now();
    final category = Category(
      id: const Uuid().v4(),
      name: name.trim(),
      order: cache.length + 1,
      createdAt: now,
      updatedAt: now,
      type: type,
      slug: Category.generateSlug(name),
    );
    await categoriesRepository.addCategory(category);
    cache[key] = category;
    return _CategoryResult(id: category.id, created: true);
  }

  ({List<ProductVariant> variants, List<String> colors, List<String> sizes})
  _buildVariants(List<Map<String, String>> rows) {
    final variants = <ProductVariant>[];
    final allColors = <String>{};
    final allSizes = <String>{};

    for (final row in rows) {
      final sku = _value(row, 'sku');
      final stock = parseIntSafe(_value(row, 'estoque'));
      final attributes = <String, String>{};

      for (var i = 1; i <= 3; i++) {
        final key = _value(row, 'nome da variacao $i');
        final val = _value(row, 'valor da variacao $i');

        if (key.isNotEmpty && val.isNotEmpty) {
          final normKey = key.toUpperCase();
          final normVal = val.trim();
          attributes[normKey] = normVal;

          // Detect if it is color or size
          final normalizedKeyVal = _normalizeHeaderKey(key);
          if (normalizedKeyVal.contains('cor') ||
              normalizedKeyVal.contains('color')) {
            allColors.add(normVal);
          } else if (normalizedKeyVal.contains('tamanho') ||
              normalizedKeyVal.contains('size') ||
              normalizedKeyVal.contains('tam')) {
            allSizes.add(normVal);
          }
        }
      }

      // Check for direct color/size columns if variation columns didn't catch them
      final directColor = _value(row, 'cor');
      if (directColor.isNotEmpty) {
        attributes['COR'] = directColor;
        allColors.add(directColor);
      }
      final directSize = _value(row, 'tamanho');
      if (directSize.isNotEmpty) {
        attributes['TAMANHO'] = directSize;
        allSizes.add(directSize);
      }

      if (attributes.isNotEmpty || sku.isNotEmpty) {
        variants.add(
          ProductVariant(sku: sku, stock: stock, attributes: attributes),
        );
      }
    }

    return (
      variants: variants,
      colors: allColors.toList(),
      sizes: allSizes.toList(),
    );
  }

  List<String> _extractRemoteImages(List<Map<String, String>> rows) {
    final urls = <String>[];
    for (final row in rows) {
      final url = _value(row, 'URL da imagem');
      if (url.isNotEmpty) urls.add(url);
    }
    return urls.toSet().toList();
  }

  Future<List<String>> _resolveRemoteImages(
    List<Map<String, String>> rows, {
    required String sku,
    required String productLabel,
    void Function(String status)? onStatus,
  }) async {
    final csvUrls = _extractRemoteImages(rows);
    if (csvUrls.isNotEmpty) return csvUrls;

    if (nuvemshopApiClient == null || sku.trim().isEmpty) {
      return const [];
    }

    onStatus?.call('Buscando imagens na API: $productLabel');
    return nuvemshopApiClient!.getProductImageUrlsBySku(sku);
  }

  String _firstNonEmpty(List<Map<String, String>> rows, String key) {
    for (final row in rows) {
      final value = _value(row, key);
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  String _extractRef(String sku) {
    if (sku.trim().isEmpty) return '';
    final parts = sku.split('.');
    final base = parts.isNotEmpty ? parts.first.trim() : sku.trim();
    return base.isEmpty ? sku.trim() : base;
  }

  String _productGroupKey(Map<String, String> row) {
    final slug = _value(row, 'Identificador URL');
    if (slug.isNotEmpty) return 'slug:$slug';

    final name = _value(row, 'Nome');
    final nameKey = _slugFromName(name);
    if (nameKey.isNotEmpty) return 'name:$nameKey';

    final sku = _value(row, 'SKU');
    final skuRef = _extractRef(sku);
    if (skuRef.isNotEmpty) return 'sku:$skuRef';

    return '';
  }

  String _slugFromName(String name) {
    var slug = _normalizeHeaderKey(name);
    slug = slug.replaceAll(' ', '-');
    slug = slug.replaceAll(RegExp(r'-+'), '-');
    return slug.trim().replaceAll(RegExp(r'^-|-$'), '');
  }

  String _normalizeKey(String name, CategoryType type) {
    return '${type.name}:${name.trim().toLowerCase()}';
  }

  String _value(Map<String, String> row, String key) {
    // We expect 'key' to be already a standard key from _headerAliases.keys
    if (row.containsKey(key)) return (row[key] ?? '').trim();

    // Fallback searching by normalized name in case normalization didn't catch it
    final normSearch = _normalizeHeaderKey(key);
    if (row.containsKey(normSearch)) return (row[normSearch] ?? '').trim();

    return '';
  }

  Map<String, String> _normalizeRow(Map<String, String> row) {
    final normalized = <String, String>{};

    // 1. Create a map of normalized original headers to their values
    final normalizedInput = {
      for (var entry in row.entries)
        _normalizeHeaderKey(entry.key): entry.value,
    };

    // 2. Map standard keys to values using aliases
    for (var standardKey in _headerAliases.keys) {
      final aliases = _headerAliases[standardKey]!;
      for (var alias in aliases) {
        if (normalizedInput.containsKey(alias)) {
          normalized[standardKey] = normalizedInput[alias]!;
          break;
        }
      }
    }

    // 3. Keep original values for any keys not recognized (safety)
    for (var entry in row.entries) {
      final normKey = _normalizeHeaderKey(entry.key);
      if (!normalized.containsKey(normKey)) {
        normalized[normKey] = entry.value;
      }
    }

    return normalized;
  }

  String _normalizeHeaderKey(String value) {
    var normalized = value.toLowerCase().trim();
    const replacements = {
      '\u00e1': 'a',
      '\u00e0': 'a',
      '\u00e2': 'a',
      '\u00e3': 'a',
      '\u00e4': 'a',
      '\u00e9': 'e',
      '\u00e8': 'e',
      '\u00ea': 'e',
      '\u00eb': 'e',
      '\u00ed': 'i',
      '\u00ec': 'i',
      '\u00ee': 'i',
      '\u00ef': 'i',
      '\u00f3': 'o',
      '\u00f2': 'o',
      '\u00f4': 'o',
      '\u00f5': 'o',
      '\u00f6': 'o',
      '\u00fa': 'u',
      '\u00f9': 'u',
      '\u00fb': 'u',
      '\u00fc': 'u',
      '\u00e7': 'c',
      '\u00f1': 'n',
    };
    replacements.forEach((from, to) {
      normalized = normalized.replaceAll(from, to);
    });
    normalized = normalized.replaceAll(RegExp(r'\s+'), ' ');
    normalized = normalized.replaceAll(RegExp(r'[^a-z0-9 ]'), '');
    return normalized.trim();
  }

  static const Map<String, List<String>> _headerAliases = {
    'identificador url': ['identificador url', 'url', 'handle', 'slug'],
    'sku': ['sku', 'codigo', 'codigo de barras', 'ean', 'referencia', 'ref'],
    'nome': ['nome', 'titulo', 'title', 'name'],
    'descricao': ['descricao', 'description', 'conteudo'],
    'preco': ['preco', 'price', 'valor'],
    'preco atacado': [
      'preco atacado',
      'valor atacado',
      'preco revenda',
      'wholesale price',
    ],
    'preco promocional': [
      'preco promocional',
      'valor promocional',
      'sale price',
      'compare at price',
    ],
    'categorias': ['categorias', 'category', 'categories', 'categoria'],
    'tags': ['tags', 'tag'],
    'estoque': ['estoque', 'stock', 'inventory'],
    'url da imagem': ['url da imagem', 'imagem', 'image', 'image url'],
    'nome da variacao 1': ['nome da variacao 1', 'opcao 1 nome', 'variacao 1'],
    'valor da variacao 1': ['valor da variacao 1', 'opcao 1 valor', 'valor 1'],
    'nome da variacao 2': ['nome da variacao 2', 'opcao 2 nome', 'variacao 2'],
    'valor da variacao 2': ['valor da variacao 2', 'opcao 2 valor', 'valor 2'],
    'nome da variacao 3': ['nome da variacao 3', 'opcao 3 nome', 'variacao 3'],
    'valor da variacao 3': ['valor da variacao 3', 'opcao 3 valor', 'valor 3'],
    'cor': ['cor', 'color', 'cores'],
    'tamanho': ['tamanho', 'size', 'tam', 'tamanhos'],
  };

  static const _columnsToFill = [
    'nome',
    'categorias',
    'preco',
    'preco promocional',
    'descricao',
    'tags',
    'nome da variacao 1',
    'valor da variacao 1',
    'nome da variacao 2',
    'valor da variacao 2',
    'nome da variacao 3',
    'valor da variacao 3',
    'cor',
    'tamanho',
  ];

  Future<List<String>> _downloadImagesIfNecessary(
    List<String> urls, {
    String? productLabel,
    void Function(String status)? onStatus,
  }) async {
    if (imageCacheService == null) return const [];
    if (urls.isEmpty) return const [];
    onStatus?.call(
      'Baixando ${urls.length} imagem(ns) de ${productLabel ?? 'produto'}...',
    );

    final localPaths = <String>[];

    // Download in parallel for each product to speed up
    final futures = urls.map(
      (url) => imageCacheService!.downloadAndCacheImage(url),
    );
    final results = await Future.wait(futures);

    for (final path in results) {
      if (path != null) localPaths.add(path);
    }

    return localPaths;
  }
}

class _CategoryResult {
  final String id;
  final bool created;

  const _CategoryResult({required this.id, required this.created});
}
