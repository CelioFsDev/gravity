import 'package:hive/hive.dart';
import 'package:catalogo_ja/core/utils/safe_parse.dart';

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
    final rawAttributes = safeMap(map['attributes']);
    final attributes = <String, String>{};
    rawAttributes.forEach((key, value) {
      final parsed = safeNullableString(value);
      if (parsed != null) attributes[key] = parsed;
    });

    return ProductVariant(
      sku: safeString(map['sku']),
      stock: safeInt(map['stock']),
      attributes: attributes,
    );
  }
}
