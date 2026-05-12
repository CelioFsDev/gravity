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
    int parseInt(dynamic value) {
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    final rawAttributes = map['attributes'];
    final attributes = <String, String>{};
    if (rawAttributes is Map) {
      rawAttributes.forEach((key, value) {
        if (key != null && value != null) {
          attributes[key.toString()] = value.toString();
        }
      });
    }

    return ProductVariant(
      sku: map['sku']?.toString() ?? '',
      stock: parseInt(map['stock']),
      attributes: attributes,
    );
  }
}
