import 'package:cloud_firestore/cloud_firestore.dart';
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

  @HiveField(4)
  final String categoryId;

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
    required this.categoryId,
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
    String? categoryId,
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
      categoryId: categoryId ?? this.categoryId,
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

  double priceForMode(String mode) {
    return mode.toLowerCase() == 'atacado' ? priceAtacado : priceVarejo;
  }

  Map<String, dynamic> toFirestoreMap() {
    return {
      'name': name,
      'reference': reference,
      'sku': sku,
      'categoryId': categoryId,
      'priceVarejo': priceVarejo,
      'priceAtacado': priceAtacado,
      'retailPrice': priceVarejo,
      'wholesalePrice': priceAtacado,
      'minWholesaleQty': minWholesaleQty,
      'sizes': sizes,
      'colors': colors,
      'images': images,
      'mainImageIndex': mainImageIndex,
      'isActive': isActive,
      'isOutOfStock': isOutOfStock,
      'isOnSale': isOnSale,
      'createdAt': Timestamp.fromDate(createdAt),
      'saleDiscountPercent': saleDiscountPercent,
    };
  }

  factory Product.fromFirestore(String id, Map<String, dynamic> data) {
    List<String> castStringList(dynamic value) {
      if (value is Iterable) {
        return value.map((e) => e.toString()).toList();
      }
      return [];
    }

    final varejo = (data['priceVarejo'] as num?)?.toDouble() ??
        (data['retailPrice'] as num?)?.toDouble() ??
        0.0;
    final atacado = (data['priceAtacado'] as num?)?.toDouble() ??
        (data['wholesalePrice'] as num?)?.toDouble() ??
        varejo;
    final createdAtValue = data['createdAt'];
    final createdAt = createdAtValue is Timestamp
        ? createdAtValue.toDate()
        : (createdAtValue is DateTime
            ? createdAtValue
            : DateTime.now());

    return Product(
      id: id,
      name: data['name'] as String? ?? '',
      reference: data['reference'] as String? ?? '',
      sku: data['sku'] as String? ?? '',
      categoryId: data['categoryId'] as String? ?? '',
      priceVarejo: varejo,
      priceAtacado: atacado,
      minWholesaleQty: (data['minWholesaleQty'] as num?)?.toInt() ?? 1,
      sizes: castStringList(data['sizes']),
      colors: castStringList(data['colors']),
      images: castStringList(data['images']),
      mainImageIndex: (data['mainImageIndex'] as int?) ?? 0,
      isActive: data['isActive'] as bool? ?? true,
      isOutOfStock: data['isOutOfStock'] as bool? ?? false,
      isOnSale: data['isOnSale'] as bool? ?? false,
      createdAt: createdAt,
      saleDiscountPercent: (data['saleDiscountPercent'] as int?) ?? 0,
    );
  }
}
