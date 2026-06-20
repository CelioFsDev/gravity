import 'package:catalogo_ja/core/utils/product_image_sync.dart';
import 'package:catalogo_ja/models/product.dart';
import 'package:catalogo_ja/models/product_image.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Product product({
    required List<ProductImage> images,
    List<String> remoteImages = const [],
  }) {
    return Product(
      id: 'product-1',
      name: 'Produto',
      ref: 'REF-1',
      sku: 'SKU-1',
      categoryIds: const [],
      priceRetail: 10,
      priceWholesale: 10,
      minWholesaleQty: 1,
      sizes: const [],
      colors: const [],
      images: images,
      remoteImages: remoteImages,
      mainImageIndex: 0,
      isActive: true,
      isOutOfStock: false,
      promoEnabled: false,
      createdAt: DateTime(2026),
    );
  }

  test('reuses the matching imported URL for a local image', () {
    final localImages = [
      ProductImage.local(path: 'C:/cache/principal.jpg', label: 'P'),
      ProductImage.local(path: 'C:/cache/detalhe.jpg', label: 'D1'),
    ];
    final source = product(
      images: localImages,
      remoteImages: const [
        'https://images.example.com/principal.jpg',
        'https://images.example.com/detalhe.jpg',
      ],
    );

    expect(
      findCloudImageFallback(
        product: source,
        image: localImages[1],
        imageIndex: 1,
      ),
      'https://images.example.com/detalhe.jpg',
    );
  });

  test('does not invent a fallback when no cloud URL is known', () {
    final localImage = ProductImage.local(path: 'C:/cache/principal.jpg');

    expect(
      findCloudImageFallback(
        product: product(images: [localImage]),
        image: localImage,
        imageIndex: 0,
      ),
      isNull,
    );
  });

  test('uses the same image slot from the cloud product', () {
    final localImage = ProductImage.local(path: 'C:/cache/principal.jpg');
    final cloudImage = ProductImage.network(
      url: 'https://storage.example.com/principal.jpg',
    );

    expect(
      findCloudImageFallback(
        product: product(images: [cloudImage]),
        image: localImage,
        imageIndex: 0,
      ),
      'https://storage.example.com/principal.jpg',
    );
  });
}
