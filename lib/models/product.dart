import 'package:hive/hive.dart';

part 'product.g.dart';

@HiveType(typeId: 4)
class Product {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String reference; // REF

  @HiveField(3)
  final String sku;

  @HiveField(17)
  final List<String> categoryIds;

  @HiveField(5)
  final double priceVarejo;

  @HiveField(6)
  final double priceAtacado;

  @HiveField(7)
  final int minWholesaleQty;

  @HiveField(8)
  final List<String> sizes;

  @HiveField(9)
  final List<String> colors;

  @HiveField(10)
  final List<String> images;

  @HiveField(11)
  final int mainImageIndex;

  @HiveField(12)
  final bool isActive;

  @HiveField(13)
  final bool isOutOfStock;

  @HiveField(14)
  final bool isOnSale;

  @HiveField(15)
  final DateTime createdAt;

  @HiveField(16)
  final int saleDiscountPercent; // Porcentagem de desconto (ex: 10 para 10%)

  Product({
    required this.id,
    required this.name,
    required this.reference,
    required this.sku,
    required this.categoryIds,
    required this.priceVarejo,
    required this.priceAtacado,
    required this.minWholesaleQty,
    required this.sizes,
    required this.colors,
    required this.images,
    required this.mainImageIndex,
    required this.isActive,
    required this.isOutOfStock,
    required this.isOnSale,
    required this.createdAt,
    this.saleDiscountPercent = 0,
  });

  Product copyWith({
    String? id,
    String? name,
    String? reference,
    String? sku,
    List<String>? categoryIds,
    double? priceVarejo,
    double? priceAtacado,
    int? minWholesaleQty,
    List<String>? sizes,
    List<String>? colors,
    List<String>? images,
    int? mainImageIndex,
    bool? isActive,
    bool? isOutOfStock,
    bool? isOnSale,
    DateTime? createdAt,
    int? saleDiscountPercent,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      reference: reference ?? this.reference,
      sku: sku ?? this.sku,
      categoryIds: categoryIds ?? this.categoryIds,
      priceVarejo: priceVarejo ?? this.priceVarejo,
      priceAtacado: priceAtacado ?? this.priceAtacado,
      minWholesaleQty: minWholesaleQty ?? this.minWholesaleQty,
      sizes: sizes ?? this.sizes,
      colors: colors ?? this.colors,
      images: images ?? this.images,
      mainImageIndex: mainImageIndex ?? this.mainImageIndex,
      isActive: isActive ?? this.isActive,
      isOutOfStock: isOutOfStock ?? this.isOutOfStock,
      isOnSale: isOnSale ?? this.isOnSale,
      createdAt: createdAt ?? this.createdAt,
      saleDiscountPercent: saleDiscountPercent ?? this.saleDiscountPercent,
    );
  }

  double get retailPrice => priceVarejo;

  double get wholesalePrice => priceAtacado;

  String? get primaryCategoryId =>
      categoryIds.isNotEmpty ? categoryIds.first : null;

  bool hasCategory(String categoryId) => categoryIds.contains(categoryId);

  double priceForMode(String mode) {
    return mode.toLowerCase() == 'atacado' ? priceAtacado : priceVarejo;
  }
}
