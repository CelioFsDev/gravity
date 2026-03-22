import 'package:hive/hive.dart';

part 'product_variant.g.dart';

@HiveType(typeId: 8)
class ProductVariant {
  @HiveField(0)
  final String sku;

  @HiveField(1)
  final int stock;

  @HiveField(2)
  final Map<String, String> attributes;

  const ProductVariant({
    required this.sku,
    required this.stock,
    required this.attributes,
  });

  Map<String, dynamic> toMap() {
    return {
      'sku': sku,
      'stock': stock,
      'attributes': attributes,
    };
  }

  factory ProductVariant.fromMap(Map<String, dynamic> map) {
    return ProductVariant(
      sku: map['sku'] ?? '',
      stock: map['stock'] ?? 0,
      attributes: Map<String, String>.from(map['attributes'] ?? {}),
    );
  }
}
