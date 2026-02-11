import 'package:file_picker/file_picker.dart';
import 'package:gravity/core/importer/nuvemshop_api_client.dart';
import 'package:gravity/core/importer/nuvemshop_csv_reader.dart';
import 'package:gravity/core/importer/nuvemshop_forward_fill.dart';
import 'package:gravity/core/importer/nuvemshop_category_mapper.dart';
import 'package:gravity/core/importer/parse_utils.dart';
import 'package:gravity/data/repositories/contracts/categories_repository_contract.dart';
import 'package:gravity/data/repositories/contracts/products_repository_contract.dart';
import 'package:gravity/models/category.dart';
import 'package:gravity/models/product.dart';
import 'package:gravity/models/product_variant.dart';
import 'package:flutter/foundation.dart' hide Category;
import 'package:gravity/core/services/image_cache_service.dart';
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
    debugPrint('Iniciando importação Nuvemshop: ${file.name}');
    onStatus?.call('Lendo CSV...');
    final table = await NuvemshopCsvReader.readFromPlatformFile(file);
    debugPrint('Colunas encontradas no CSV: ${table.headers.join(', ')}');
    onStatus?.call('Organizando dados...');
    final rows = forwardFill(table.rows, _columnsToFill);

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
          'Nenhum produto encontrado no CSV. Verifique se há ao menos Nome ou SKU preenchidos.',
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

      final row = entry.value.first;
      final name = _value(row, 'Nome');
      final slugFromCsv = _value(row, 'Identificador URL');
      final slug = slugFromCsv.isNotEmpty ? slugFromCsv : _slugFromName(name);
      final description = _value(row, 'Descrição');
      final tags = splitCsvList(_value(row, 'Tags'));
      final categoriesNames = parseCategoryNames(_value(row, 'Categorias'));
      final collectionName = detectCollectionName(tags);

      final priceRetail = parseMoney(_value(row, 'Preço'));
      if (priceRetail <= 0) {
        warnings.add('Preço inválido para "$name". Linha ignorada.');
        continue;
      }

      final promoPrice = parseMoney(_value(row, 'Preço promocional'));
      var promoPercent = 0.0;
      var promoEnabled = false;
      if (promoPrice > 0 && promoPrice < priceRetail) {
        promoPercent = 100 * (1 - (promoPrice / priceRetail));
        promoPercent = promoPercent.clamp(0, 100);
        promoEnabled = promoPercent > 0;
      }

      final firstSku = _firstNonEmpty(entry.value, 'SKU');
      final safeSku = firstSku.isNotEmpty ? firstSku : slug;
      final ref = _extractRef(safeSku).isNotEmpty ? _extractRef(safeSku) : slug;
      final existing = byRef[ref.toLowerCase()];
      final remoteImages = await _resolveRemoteImages(
        entry.value,
        sku: safeSku,
        productLabel: name.isNotEmpty ? name : slug,
        onStatus: onStatus,
      );

      final categoryIds = <String>[];
      if (collectionName != null && collectionName.isNotEmpty) {
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

      final variants = _buildVariants(entry.value);
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
          priceWholesale: priceRetail,
          minWholesaleQty: 1,
          sizes: const [],
          colors: const [],
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
          priceWholesale: existing.priceWholesale,
          images: (existing.images.isEmpty)
              ? await _downloadImagesIfNecessary(
                  remoteImages,
                  productLabel: name.isNotEmpty ? name : slug,
                  onStatus: onStatus,
                )
              : existing.images,
          promoEnabled: promoEnabled,
          promoPercent: promoPercent,
          variants: variants,
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

  List<ProductVariant> _buildVariants(List<Map<String, String>> rows) {
    return rows.map((row) {
      final sku = _value(row, 'SKU');
      final stock = parseIntSafe(_value(row, 'Estoque'));
      final attributes = <String, String>{};
      for (var i = 1; i <= 3; i++) {
        final key = _value(row, 'Nome da variação $i');
        final val = _value(row, 'Valor da variação $i');
        if (key.isNotEmpty && val.isNotEmpty) {
          attributes[key.toUpperCase()] = val.toUpperCase();
        }
      }
      return ProductVariant(sku: sku, stock: stock, attributes: attributes);
    }).toList();
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
    if (row.containsKey(key)) return (row[key] ?? '').trim();

    final normalizedKey = _normalizeHeaderKey(key);
    final normalizedAliases = _headerAliases[normalizedKey] ?? [normalizedKey];
    final normalizedRow = {
      for (final entry in row.entries)
        _normalizeHeaderKey(entry.key): entry.value.trim(),
    };

    for (final alias in normalizedAliases) {
      final value = normalizedRow[alias];
      if (value != null) return value;
    }
    for (final entry in normalizedRow.entries) {
      for (final alias in normalizedAliases) {
        if (entry.key.contains(alias) || alias.contains(entry.key)) {
          return entry.value;
        }
      }
    }

    final index = _standardColumnIndex[normalizedKey];
    if (index != null && index >= 0 && row.length > index) {
      return row.values.elementAt(index).trim();
    }
    return '';
  }

  String _normalizeHeaderKey(String value) {
    var normalized = value.toLowerCase().trim();
    const replacements = {
      'á': 'a',
      'à': 'a',
      'â': 'a',
      'ã': 'a',
      'ä': 'a',
      'é': 'e',
      'è': 'e',
      'ê': 'e',
      'ë': 'e',
      'í': 'i',
      'ì': 'i',
      'î': 'i',
      'ï': 'i',
      'ó': 'o',
      'ò': 'o',
      'ô': 'o',
      'õ': 'o',
      'ö': 'o',
      'ú': 'u',
      'ù': 'u',
      'û': 'u',
      'ü': 'u',
      'ç': 'c',
      'ñ': 'n',
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
    'sku': [
      'sku',
      'codigo',
      'codigo de barras',
      'ean',
      'referencia',
      'ref',
    ],
    'nome': ['nome', 'titulo', 'title', 'name'],
    'descricao': ['descricao', 'description', 'conteudo'],
    'preco': ['preco', 'price', 'valor'],
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
    'nome da variacao 1': ['nome da variacao 1', 'opcao1 nome'],
    'valor da variacao 1': ['valor da variacao 1', 'opcao1 valor'],
    'nome da variacao 2': ['nome da variacao 2', 'opcao2 nome'],
    'valor da variacao 2': ['valor da variacao 2', 'opcao2 valor'],
    'nome da variacao 3': ['nome da variacao 3', 'opcao3 nome'],
    'valor da variacao 3': ['valor da variacao 3', 'opcao3 valor'],
  };

  static const Map<String, int> _standardColumnIndex = {
    'identificador url': 0,
    'nome': 1,
    'categorias': 2,
    'nome da variacao 1': 3,
    'valor da variacao 1': 4,
    'nome da variacao 2': 5,
    'valor da variacao 2': 6,
    'nome da variacao 3': 7,
    'valor da variacao 3': 8,
    'preco': 9,
    'preco promocional': 10,
    'estoque': 15,
    'sku': 16,
    'descricao': 20,
    'tags': 21,
  };

  static const _columnsToFill = [
    'Nome',
    'Categorias',
    'Preço',
    'Preço promocional',
    'Descrição',
    'Tags',
  ];

  Future<List<String>> _downloadImagesIfNecessary(
    List<String> urls,
    {
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



