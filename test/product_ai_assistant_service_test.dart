import 'package:catalogo_ja/core/services/product_ai_assistant_service.dart';
import 'package:catalogo_ja/models/product.dart';
import 'package:catalogo_ja/models/product_variant.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('selects only shirts with available stock', () {
    final service = ProductAiAssistantService();
    const plan = ProductAssistantPlan(
      action: 'select',
      searchTerms: ['blusa'],
      stock: 'in_stock',
      status: 'any',
      promotion: 'any',
      photos: 'any',
      sort: 'none',
      message: 'Selecionar blusas com estoque.',
    );

    final matches = service.findMatches(
      plan: plan,
      products: [
        _product(
          id: 'available-shirt',
          name: 'Blusa Feminina',
          variants: const [
            ProductVariant(sku: 'B-1', stock: 3, attributes: {}),
          ],
        ),
        _product(
          id: 'sold-out-shirt',
          name: 'Blusa Manga Longa',
          variants: const [
            ProductVariant(sku: 'B-2', stock: 0, attributes: {}),
          ],
        ),
        _product(
          id: 'available-dress',
          name: 'Vestido Floral',
          variants: const [
            ProductVariant(sku: 'V-1', stock: 5, attributes: {}),
          ],
        ),
      ],
      categories: const [],
    );

    expect(matches.map((product) => product.id), ['available-shirt']);
    expect(plan.shouldSelect, isTrue);
  });
}

Product _product({
  required String id,
  required String name,
  required List<ProductVariant> variants,
}) {
  final now = DateTime(2026, 5, 25);
  return Product(
    id: id,
    name: name,
    ref: id,
    sku: id,
    categoryIds: const [],
    priceRetail: 0,
    priceWholesale: 0,
    minWholesaleQty: 1,
    sizes: const [],
    colors: const [],
    images: const [],
    mainImageIndex: 0,
    isActive: true,
    isOutOfStock: false,
    promoEnabled: false,
    createdAt: now,
    updatedAt: now,
    variants: variants,
  );
}
