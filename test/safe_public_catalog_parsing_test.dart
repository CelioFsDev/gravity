import 'package:catalogo_ja/core/utils/safe_parse.dart';
import 'package:catalogo_ja/models/catalog.dart';
import 'package:catalogo_ja/models/category.dart';
import 'package:catalogo_ja/models/product.dart';
import 'package:catalogo_ja/models/product_image.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('safe parse helpers accept mixed public catalog values', () {
    expect(safeString(null, fallback: 'x'), 'x');
    expect(safeNullableString('  nome  '), 'nome');
    expect(safeDouble('R\$ 1.234,56'), 1234.56);
    expect(safeDouble('12,5'), 12.5);
    expect(safeInt('7,9'), 7);
    expect(safeBool('false', fallback: true), isFalse);
    expect(safeBool(1), isTrue);
    expect(safeStringList([' P ', null, 42]), ['P', '42']);
    expect(safeMap({'a': 1}), {'a': 1});
    expect(
      safeMapList([
        {'a': 1},
        null,
        'x',
      ]),
      [
        {'a': 1},
      ],
    );
    expect(
      safeDateTime({'_seconds': 1700000000, '_nanoseconds': 500000000}),
      DateTime.fromMillisecondsSinceEpoch(1700000000500),
    );
  });

  test('public catalog models do not throw on loose snapshot fields', () {
    final catalog = Catalog.fromMap({
      'id': 123,
      'name': 'Vitrine',
      'active': 'true',
      'productIds': ['p1', 2, null],
      'requireCustomerData': 0,
      'announcementEnabled': 'false',
      'banners': [
        {'id': 1, 'imagePath': 'https://example.com/banner.png'},
        'invalid',
      ],
      'createdAt': '2026-01-02T03:04:05.000',
      'updatedAt': {'seconds': 1700000000},
      'mode': 'atacado',
      'isPublic': 1,
      'shareCode': 987,
    });

    expect(catalog.id, '123');
    expect(catalog.active, isTrue);
    expect(catalog.productIds, ['p1', '2']);
    expect(catalog.mode, CatalogMode.atacado);
    expect(catalog.banners.length, 1);

    final product = Product.fromMap({
      'id': 'p1',
      'name': 'Produto',
      'ref': 99,
      'categoryIds': 'cat1',
      'priceRetail': 'R\$ 1.234,56',
      'priceWholesale': 20,
      'minWholesaleQty': '3',
      'sizes': ['P', null, 40],
      'colors': 'Azul',
      'images': [
        {
          'id': 1,
          'uri': 'https://example.com/a.png',
          'sourceType': ProductImageSource.networkUrl.name,
          'order': '2',
        },
        'https://example.com/b.png',
        null,
      ],
      'photos': [
        {'path': 'gs://bucket/photo.png', 'isPrimary': 'true'},
        1,
      ],
      'variants': [
        {
          'sku': 10,
          'stock': '5',
          'attributes': {'Cor': 'Azul', 'Tamanho': 40},
        },
      ],
      'isActive': 'true',
      'createdAt': null,
      'updatedAt': '2026-01-02T03:04:05.000',
    });

    expect(product.ref, '99');
    expect(product.categoryIds, ['cat1']);
    expect(product.priceRetail, 1234.56);
    expect(product.colors, ['Azul']);
    expect(product.images.length, 3);
    expect(product.photos.length, 1);
    expect(product.variants.single.attributes['Tamanho'], '40');

    final category = Category.fromMap({
      'id': 'cat1',
      'name': 123,
      'order': '9',
      'type': 'productType',
      'isActive': 1,
      'cover': {'mode': 'template', 'overlayOpacity': '0,5'},
    });

    expect(category.safeName, '123');
    expect(category.order, 9);
    expect(category.type, CategoryType.productType);
    expect(category.cover?.overlayOpacity, 0.5);
  });
}
