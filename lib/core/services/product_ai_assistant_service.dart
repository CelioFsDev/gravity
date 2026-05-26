import 'package:catalogo_ja/models/category.dart';
import 'package:catalogo_ja/models/product.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:diacritic/diacritic.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProductAssistantPlan {
  const ProductAssistantPlan({
    required this.action,
    required this.searchTerms,
    required this.stock,
    required this.status,
    required this.promotion,
    required this.photos,
    required this.sort,
    required this.message,
    this.minPrice,
    this.maxPrice,
    this.usedAi = true,
  });

  factory ProductAssistantPlan.fromMap(Map<String, dynamic> map) {
    return ProductAssistantPlan(
      action: map['action']?.toString() ?? 'filter',
      searchTerms: (map['searchTerms'] as List<dynamic>? ?? const [])
          .map((term) => term.toString().trim())
          .where((term) => term.isNotEmpty)
          .toList(),
      stock: map['stock']?.toString() ?? 'any',
      status: map['status']?.toString() ?? 'any',
      promotion: map['promotion']?.toString() ?? 'any',
      photos: map['photos']?.toString() ?? 'any',
      minPrice: (map['minPrice'] as num?)?.toDouble(),
      maxPrice: (map['maxPrice'] as num?)?.toDouble(),
      sort: map['sort']?.toString() ?? 'none',
      message: map['message']?.toString() ?? 'Resultado encontrado.',
    );
  }

  final String action;
  final List<String> searchTerms;
  final String stock;
  final String status;
  final String promotion;
  final String photos;
  final double? minPrice;
  final double? maxPrice;
  final String sort;
  final String message;
  final bool usedAi;

  bool get shouldSelect => action == 'select';
  bool get isSupported => action != 'unsupported';
}

class ProductAiAssistantService {
  ProductAiAssistantService({FirebaseFunctions? functions})
    : _functions = functions;

  final FirebaseFunctions? _functions;

  Future<ProductAssistantPlan> interpret(String command) async {
    final trimmed = command.trim();
    if (trimmed.length < 3) {
      throw ArgumentError('Digite o que voce deseja localizar.');
    }

    try {
      final callable = (_functions ?? FirebaseFunctions.instance).httpsCallable(
        'productAssistantCommand',
      );
      final response = await callable.call<Map<String, dynamic>>({
        'command': trimmed,
      });
      return ProductAssistantPlan.fromMap(response.data);
    } on FirebaseFunctionsException catch (error) {
      if (error.code == 'unauthenticated' ||
          error.code == 'permission-denied' ||
          error.code == 'invalid-argument') {
        rethrow;
      }
      return _interpretLocally(trimmed);
    } catch (_) {
      return _interpretLocally(trimmed);
    }
  }

  List<Product> findMatches({
    required ProductAssistantPlan plan,
    required List<Product> products,
    required List<Category> categories,
  }) {
    final categoryNames = <String, String>{
      for (final category in categories) category.id: category.safeName,
    };

    final matches = products.where((product) {
      if (!_matchesTerms(product, plan.searchTerms, categoryNames)) {
        return false;
      }

      final hasStock = product.variants.isNotEmpty
          ? product.variants.any((variant) => variant.stock > 0)
          : !product.isOutOfStock;

      if (plan.stock == 'in_stock' && !hasStock) return false;
      if (plan.stock == 'out_of_stock' && hasStock) return false;
      if (plan.status == 'active' && !product.isActive) return false;
      if (plan.status == 'inactive' && product.isActive) return false;
      if (plan.promotion == 'on_sale' && !product.promoEnabled) return false;
      if (plan.promotion == 'not_on_sale' && product.promoEnabled) {
        return false;
      }

      final hasPhotos = product.images.isNotEmpty || product.photos.isNotEmpty;
      if (plan.photos == 'with_photos' && !hasPhotos) return false;
      if (plan.photos == 'without_photos' && hasPhotos) return false;
      if (plan.minPrice != null && product.retailPrice < plan.minPrice!) {
        return false;
      }
      if (plan.maxPrice != null && product.retailPrice > plan.maxPrice!) {
        return false;
      }
      return true;
    }).toList();

    switch (plan.sort) {
      case 'price_asc':
        matches.sort((a, b) => a.retailPrice.compareTo(b.retailPrice));
        break;
      case 'price_desc':
        matches.sort((a, b) => b.retailPrice.compareTo(a.retailPrice));
        break;
      case 'name_asc':
        matches.sort((a, b) => a.name.compareTo(b.name));
        break;
      case 'recent':
        matches.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
    }

    return matches;
  }

  bool _matchesTerms(
    Product product,
    List<String> terms,
    Map<String, String> categoryNames,
  ) {
    if (terms.isEmpty) return true;

    final categoryText = product.categoryIds
        .map((categoryId) => categoryNames[categoryId] ?? '')
        .join(' ');
    final content = _normalize(
      [
        product.name,
        product.reference,
        product.sku,
        product.colors.join(' '),
        product.tags.join(' '),
        categoryText,
      ].join(' '),
    );
    final contentTokens = content.split(' ').where((word) => word.isNotEmpty);

    final normalizedTerms = terms
        .expand((term) => _normalize(term).split(' '))
        .where((term) => term.isNotEmpty)
        .map(_singular);

    return normalizedTerms.every((normalizedTerm) {
      if (normalizedTerm.isEmpty) return true;
      return contentTokens.any((word) {
        final normalizedWord = _singular(word);
        return normalizedWord.contains(normalizedTerm) ||
            normalizedTerm.contains(normalizedWord);
      });
    });
  }

  ProductAssistantPlan _interpretLocally(String command) {
    final normalized = _normalize(command);
    final shouldSelect = _hasAny(normalized, const [
      'separe',
      'selecione',
      'marque',
      'escolha',
    ]);
    final inStock =
        normalized.contains('com estoque') ||
        normalized.contains('tem estoque') ||
        normalized.contains('disponivel');
    final outOfStock =
        normalized.contains('sem estoque') || normalized.contains('esgotad');
    final onSale =
        normalized.contains('promocao') || normalized.contains('oferta');
    final inactive = normalized.contains('inativ');
    final active = !inactive && normalized.contains('ativ');
    final withoutPhotos = normalized.contains('sem foto');
    final withPhotos = normalized.contains('com foto');

    const ignoredWords = {
      'a',
      'as',
      'ativo',
      'ativos',
      'com',
      'de',
      'disponivel',
      'disponiveis',
      'esgotada',
      'esgotadas',
      'esgotado',
      'esgotados',
      'em',
      'escolha',
      'estoque',
      'foto',
      'fotos',
      'inativa',
      'inativas',
      'inativo',
      'inativos',
      'listar',
      'liste',
      'marque',
      'me',
      'mostre',
      'o',
      'os',
      'produto',
      'produtos',
      'promocao',
      'oferta',
      'que',
      'selecione',
      'separe',
      'sem',
      'tem',
      'tenham',
      'todas',
      'todos',
      'ver',
    };
    final terms = normalized
        .split(' ')
        .where((word) => word.length > 2 && !ignoredWords.contains(word))
        .map(_singular)
        .toSet()
        .toList();

    return ProductAssistantPlan(
      action: shouldSelect ? 'select' : 'filter',
      searchTerms: terms,
      stock: inStock ? 'in_stock' : (outOfStock ? 'out_of_stock' : 'any'),
      status: inactive ? 'inactive' : (active ? 'active' : 'any'),
      promotion: onSale ? 'on_sale' : 'any',
      photos: withoutPhotos
          ? 'without_photos'
          : (withPhotos ? 'with_photos' : 'any'),
      sort: 'none',
      message: shouldSelect
          ? 'Selecionei os produtos encontrados pelo pedido.'
          : 'Mostrando os produtos encontrados pelo pedido.',
      usedAi: false,
    );
  }

  bool _hasAny(String text, List<String> terms) =>
      terms.any((term) => text.contains(term));

  String _normalize(String value) => removeDiacritics(value)
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  String _singular(String value) {
    if (value.length > 4 && value.endsWith('s')) {
      return value.substring(0, value.length - 1);
    }
    return value;
  }
}

final productAiAssistantServiceProvider = Provider<ProductAiAssistantService>((
  ref,
) {
  return ProductAiAssistantService();
});
