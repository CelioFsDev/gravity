import 'package:catalogo_ja/data/repositories/contracts/catalogs_repository_contract.dart';
import 'package:catalogo_ja/data/repositories/contracts/products_repository_contract.dart';
import 'package:catalogo_ja/models/catalog.dart';
import 'package:catalogo_ja/models/product.dart' hide SyncStatus;
import 'package:catalogo_ja/models/sync_status.dart';
import 'package:diacritic/diacritic.dart';
import 'package:uuid/uuid.dart';

class OrderCatalogMatchResult {
  final List<String> references;
  final List<Product> productsFound;
  final List<String> referencesNotFound;

  const OrderCatalogMatchResult({
    required this.references,
    required this.productsFound,
    required this.referencesNotFound,
  });
}

class OrderToCatalogService {
  final ProductsRepositoryContract productsRepository;
  final CatalogsRepositoryContract catalogsRepository;

  const OrderToCatalogService({
    required this.productsRepository,
    required this.catalogsRepository,
  });

  Future<OrderCatalogMatchResult> matchReferences(
    List<String> references,
  ) async {
    final uniqueReferences = references.toSet().toList()
      ..sort((a, b) {
        final numericCompare = int.parse(a).compareTo(int.parse(b));
        if (numericCompare != 0) return numericCompare;
        return a.compareTo(b);
      });

    final products = await productsRepository.getProducts();
    final productsByReference = <String, List<Product>>{};

    for (final product in products) {
      final reference = product.reference.trim();
      if (reference.isEmpty) continue;
      productsByReference.putIfAbsent(reference, () => []).add(product);
    }

    final productsFound = <Product>[];
    final referencesNotFound = <String>[];
    final addedProductIds = <String>{};

    for (final reference in uniqueReferences) {
      final matches = productsByReference[reference] ?? const <Product>[];
      if (matches.isEmpty) {
        referencesNotFound.add(reference);
        continue;
      }

      for (final product in matches) {
        if (addedProductIds.add(product.id)) {
          productsFound.add(product);
        }
      }
    }

    return OrderCatalogMatchResult(
      references: uniqueReferences,
      productsFound: productsFound,
      referencesNotFound: referencesNotFound,
    );
  }

  Future<Catalog> createCatalogFromReferences({
    required String catalogName,
    required List<String> references,
  }) async {
    final name = catalogName.trim();
    if (name.isEmpty) {
      throw ArgumentError('Informe o nome do catálogo.');
    }

    final match = await matchReferences(references);
    if (match.productsFound.isEmpty) {
      throw StateError('Nenhum produto encontrado no cadastro.');
    }

    final now = DateTime.now();
    final id = const Uuid().v4();
    final slug = await _availableSlug(name, id);
    final catalog = Catalog(
      id: id,
      name: name,
      slug: slug,
      active: true,
      productIds: match.productsFound.map((product) => product.id).toList(),
      requireCustomerData: false,
      photoLayout: 'grid',
      announcementEnabled: false,
      banners: const [],
      createdAt: now,
      updatedAt: now,
      mode: CatalogMode.varejo,
      isPublic: false,
      shareCode: '',
      ownerUid: '',
      includeCover: true,
      syncStatus: SyncStatus.pendingUpdate,
    );

    await catalogsRepository.addCatalog(catalog);
    return catalog;
  }

  Future<String> _availableSlug(String name, String catalogId) async {
    final base = _slugFromName(name);

    for (var index = 0; index < 50; index++) {
      final candidate = index == 0 ? base : '$base-${index + 1}';
      final isTaken = await catalogsRepository.isSlugTaken(
        candidate,
        excludeId: catalogId,
      );
      if (!isTaken) return candidate;
    }

    return '$base-${DateTime.now().millisecondsSinceEpoch % 10000}';
  }

  String _slugFromName(String name) {
    final normalized = removeDiacritics(name)
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');

    if (normalized.length >= 3) return normalized;
    return 'pedido-importado';
  }
}
