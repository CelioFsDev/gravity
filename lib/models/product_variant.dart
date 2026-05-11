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
    return {'sku': sku, 'stock': stock, 'attributes': attributes};
  }

  factory ProductVariant.fromMap(Map<String, dynamic> map) {
    final rawAttributes = map['attributes'];
    final attributes = rawAttributes is Map
        ? rawAttributes.map(
            (key, value) => MapEntry(key.toString(), value.toString()),
          )
        : <String, String>{};

    return ProductVariant(
      sku: map['sku']?.toString() ?? '',
      stock: (map['stock'] as num?)?.toInt() ?? 0,
      attributes: attributes,
    );
  }
}
