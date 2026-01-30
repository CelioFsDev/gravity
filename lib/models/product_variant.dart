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
}
