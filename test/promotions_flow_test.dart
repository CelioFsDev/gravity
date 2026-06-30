import 'package:flutter_test/flutter_test.dart';
import 'package:catalogo_ja/models/product.dart';

Product createTestProduct({
  bool promoEnabled = false,
  double promoPercent = 0.0,
  double? priceOriginal,
  double? pricePromotion,
  String? promotionType,
}) {
  return Product(
    id: '1',
    name: 'Camiseta',
    ref: 'CM01',
    sku: 'SKU01',
    categoryIds: [],
    priceWholesale: 0.0,
    minWholesaleQty: 1,
    sizes: [],
    colors: [],
    images: [],
    remoteImages: [],
    photos: [],
    mainImageIndex: 0,
    isActive: true,
    isOutOfStock: false,
    createdAt: DateTime.now(),
    priceRetail: 100.0,
    promoEnabled: promoEnabled,
    promoPercent: promoPercent,
    priceOriginal: priceOriginal,
    pricePromotion: pricePromotion,
    promotionType: promotionType,
  );
}

void main() {
  group('Testes de Lógica de Promoções (Product Model)', () {
    test('Produto sem promoção deve retornar preço original', () {
      final product = createTestProduct();

      expect(product.hasActivePromotion, isFalse);
      expect(product.effectivePriceRetail, equals(100.0));
      expect(product.priceOriginalForPromotion, equals(100.0));
    });

    test('Produto com promoção de porcentagem', () {
      final product = createTestProduct(
        promoEnabled: true,
        promoPercent: 20.0,
        priceOriginal: 100.0,
        promotionType: 'percent',
      );

      expect(product.hasActivePromotion, isTrue);
      expect(product.promotionPriceRetail, equals(80.0));
      expect(product.effectivePriceRetail, equals(80.0));
    });

    test('Produto com promoção manual', () {
      final product = createTestProduct(
        promoEnabled: true,
        priceOriginal: 100.0,
        pricePromotion: 55.0,
        promotionType: 'manual',
      );

      expect(product.hasActivePromotion, isTrue);
      expect(product.promotionPriceRetail, equals(55.0));
      expect(product.effectivePriceRetail, equals(55.0));
    });

    test('Promoção inválida (preço promo maior que original) não deve ser ativa', () {
      final product = createTestProduct(
        promoEnabled: true,
        priceOriginal: 100.0,
        pricePromotion: 120.0,
        promotionType: 'manual',
      );

      expect(product.hasActivePromotion, isFalse);
      expect(product.effectivePriceRetail, equals(100.0));
    });

    test('Remoção de promoção limpa os estados corretamente usando copyWith', () {
      final product = createTestProduct(
        promoEnabled: true,
        priceOriginal: 100.0,
        pricePromotion: 55.0,
        promotionType: 'manual',
      );

      final cleared = product.copyWith(
        promoEnabled: false,
        promoPercent: 0,
        clearPriceOriginal: true,
        clearPricePromotion: true,
        clearPromotionType: true,
      );

      expect(cleared.hasActivePromotion, isFalse);
      expect(cleared.effectivePriceRetail, equals(100.0));
      expect(cleared.priceOriginal, isNull);
      expect(cleared.pricePromotion, isNull);
      expect(cleared.promotionType, isNull);
    });
  });
}
