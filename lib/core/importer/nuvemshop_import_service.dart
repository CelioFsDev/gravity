import 'package:file_picker/file_picker.dart';
import 'package:gravity/core/importer/nuvemshop_csv_reader.dart';
import 'package:gravity/core/importer/nuvemshop_forward_fill.dart';
import 'package:gravity/core/importer/nuvemshop_category_mapper.dart';
import 'package:gravity/core/importer/parse_utils.dart';
import 'package:gravity/data/repositories/contracts/categories_repository_contract.dart';
import 'package:gravity/data/repositories/contracts/products_repository_contract.dart';
import 'package:gravity/models/category.dart';
import 'package:gravity/models/product.dart';
import 'package:gravity/models/product_variant.dart';
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

  NuvemshopImportService({
    required this.productsRepository,
    required this.categoriesRepository,
  });

  Future<ImportReport> importCsvFile(
    PlatformFile file, {
    ImportOptions options = const ImportOptions(),
    void Function(double progress)? onProgress,
  }) async {
    final table = await NuvemshopCsvReader.readFromPlatformFile(file);
    final rows = forwardFill(table.rows, _columnsToFill);

    final grouped = <String, List<Map<String, String>>>{};
    for (final row in rows) {
      final slug = _value(row, 'Identificador URL');
      final sku = _value(row, 'SKU');
      if (slug.isEmpty || sku.isEmpty) {
        continue;
      }
      grouped.putIfAbsent(slug, () => []).add(row);
    }

    final allProducts = await productsRepository.getProducts();
    final byRef = {for (final p in allProducts) p.reference.toLowerCase(): p};

    final allCategories = await categoriesRepository.getCategories();
    final categoryByKey = {
      for (final c in allCategories) _normalizeKey(c.name, c.type): c,
    };

    var created = 0;
    var updated = 0;
    var variantsCount = 0;
    var createdCategories = 0;
    final warnings = <String>[];

    final entries = grouped.entries.toList();
    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      onProgress?.call((i + 1) / entries.length);

      final row = entry.value.first;
      final slug = _value(row, 'Identificador URL');
      final name = _value(row, 'Nome');
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

      final firstSku = _value(entry.value.first, 'SKU');
      final ref = _extractRef(firstSku);
      final existing = byRef[ref.toLowerCase()];

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
          sku: firstSku,
          slug: slug,
          description: description.isEmpty ? null : description,
          tags: tags,
          remoteImages: _extractRemoteImages(entry.value),
          categoryIds: categoryIds.toSet().toList(),
          priceRetail: priceRetail,
          priceWholesale: priceRetail,
          minWholesaleQty: 1,
          sizes: const [],
          colors: const [],
          images: const [],
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
          remoteImages: _extractRemoteImages(entry.value),
          categoryIds: categoryIds.toSet().toList(),
          priceRetail: priceRetail,
          priceWholesale: existing.priceWholesale,
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

  String _extractRef(String sku) {
    final parts = sku.split('.');
    final base = parts.isNotEmpty ? parts.first.trim() : sku.trim();
    return base.isEmpty ? sku.trim() : base;
  }

  String _normalizeKey(String name, CategoryType type) {
    return '${type.name}:${name.trim().toLowerCase()}';
  }

  String _value(Map<String, String> row, String key) {
    if (row.containsKey(key)) return (row[key] ?? '').trim();
    final lowerKey = key.toLowerCase();
    for (final entry in row.entries) {
      if (entry.key.toLowerCase() == lowerKey) {
        return entry.value.trim();
      }
    }
    return '';
  }

  static const _columnsToFill = [
    'Identificador URL',
    'Nome',
    'Categorias',
    'Preço',
    'Preço promocional',
    'Descrição',
    'Tags',
  ];
}

class _CategoryResult {
  final String id;
  final bool created;

  const _CategoryResult({required this.id, required this.created});
}
