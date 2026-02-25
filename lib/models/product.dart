import 'package:hive/hive.dart';
import 'package:catalogo_ja/core/utils/price_calculator.dart';
import 'package:catalogo_ja/models/product_variant.dart';

part 'product.g.dart';

@HiveType(typeId: 11)
class ProductPhoto {
  @HiveField(0)
  final String path;

  @HiveField(1)
  final String? colorKey;

  @HiveField(2)
  final bool isPrimary;

  @HiveField(3)
  final String? photoType;

  const ProductPhoto({
    required this.path,
    this.colorKey,
    this.isPrimary = false,
    this.photoType,
  });

  ProductPhoto copyWith({
    String? path,
    String? colorKey,
    bool? isPrimary,
    String? photoType,
  }) {
    return ProductPhoto(
      path: path ?? this.path,
      colorKey: colorKey ?? this.colorKey,
      isPrimary: isPrimary ?? this.isPrimary,
      photoType: photoType ?? this.photoType,
    );
  }
}

@HiveType(typeId: 4)
@HiveType(typeId: 4)
class Product {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String ref; // Renamed from reference

  @HiveField(3)
  final String sku;

  @HiveField(17)
  final List<String> categoryIds;

  @HiveField(5)
  final double priceRetail; // Renamed from priceVarejo

  @HiveField(6)
  final double priceWholesale; // Renamed from priceAtacado

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
  final bool promoEnabled; // Renamed from isOnSale

  @HiveField(15)
  final DateTime createdAt;

  @HiveField(16)
  final double promoPercent; // Renamed from saleDiscountPercent (and int -> double)

  @HiveField(18)
  final String slug;

  @HiveField(19)
  final String? description;

  @HiveField(20)
  final List<String> tags;

  @HiveField(21)
  final List<String> remoteImages;

  @HiveField(22)
  final List<ProductVariant> variants;

  @HiveField(23)
  final DateTime updatedAt;

  @HiveField(24)
  final List<ProductPhoto> photos;

  Product({
    required this.id,
    required this.name,
    required this.ref,
    required this.sku,
    required this.categoryIds,
    required this.priceRetail,
    required this.priceWholesale,
    required this.minWholesaleQty,
    required this.sizes,
    required this.colors,
    required this.images,
    required this.mainImageIndex,
    required this.isActive,
    required this.isOutOfStock,
    required this.promoEnabled,
    required this.createdAt,
    List<ProductPhoto> photos = const [],
    this.promoPercent = 0.0,
    this.slug = '',
    this.description,
    this.tags = const [],
    this.remoteImages = const [],
    this.variants = const [],
    DateTime? updatedAt,
  }) : photos = photos.isNotEmpty
           ? photos
           : _photosFromLegacy(images, mainImageIndex),
       updatedAt = updatedAt ?? createdAt;

  Product copyWith({
    String? id,
    String? name,
    String? ref,
    String? sku,
    List<String>? categoryIds,
    double? priceRetail,
    double? priceWholesale,
    int? minWholesaleQty,
    List<String>? sizes,
    List<String>? colors,
    List<String>? images,
    int? mainImageIndex,
    bool? isActive,
    bool? isOutOfStock,
    bool? promoEnabled,
    DateTime? createdAt,
    double? promoPercent,
    String? slug,
    String? description,
    List<String>? tags,
    List<String>? remoteImages,
    List<ProductVariant>? variants,
    DateTime? updatedAt,
    List<ProductPhoto>? photos,
  }) {
    final resolvedPhotos =
        photos ??
        (images != null
            ? _photosFromLegacy(images, mainImageIndex ?? this.mainImageIndex)
            : this.photos);
    final resolvedImages = images ?? _imagesFromPhotos(resolvedPhotos);
    final resolvedMainIndex =
        mainImageIndex ??
        _mainIndexFromPhotos(resolvedPhotos, this.mainImageIndex);
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      ref: ref ?? this.ref,
      sku: sku ?? this.sku,
      categoryIds: categoryIds ?? this.categoryIds,
      priceRetail: priceRetail ?? this.priceRetail,
      priceWholesale: priceWholesale ?? this.priceWholesale,
      minWholesaleQty: minWholesaleQty ?? this.minWholesaleQty,
      sizes: sizes ?? this.sizes,
      colors: colors ?? this.colors,
      images: resolvedImages,
      mainImageIndex: resolvedMainIndex,
      isActive: isActive ?? this.isActive,
      isOutOfStock: isOutOfStock ?? this.isOutOfStock,
      promoEnabled: promoEnabled ?? this.promoEnabled,
      createdAt: createdAt ?? this.createdAt,
      promoPercent: promoPercent ?? this.promoPercent,
      slug: slug ?? this.slug,
      description: description ?? this.description,
      tags: tags ?? this.tags,
      remoteImages: remoteImages ?? this.remoteImages,
      variants: variants ?? this.variants,
      updatedAt: updatedAt ?? this.updatedAt,
      photos: resolvedPhotos,
    );
  }

  // ALIASES for compatibility
  double get retailPrice => priceRetail; // Alias
  double get priceVarejo => priceRetail; // Alias old
  double get wholesalePrice => priceWholesale; // Alias
  double get priceAtacado => priceWholesale; // Alias old
  String get reference => ref; // Alias old
  bool get isOnSale => promoEnabled; // Alias old
  int get saleDiscountPercent => promoPercent.toInt(); // Alias old compatible

  double get effectivePriceRetail =>
      PriceCalculator.effectiveRetail(priceRetail, promoEnabled, promoPercent);

  double get effectivePriceWholesale => PriceCalculator.effectiveWholesale(
    priceWholesale,
    promoEnabled,
    promoPercent,
  );

  String? get primarySku => variants.isNotEmpty ? variants.first.sku : null;

  String? get primaryCategoryId =>
      categoryIds.isNotEmpty ? categoryIds.first : null;

  bool hasCategory(String categoryId) => categoryIds.contains(categoryId);

  double priceForMode(String mode) {
    final isWholesale = mode.toLowerCase() == 'atacado';
    return isWholesale
        ? PriceCalculator.effectiveWholesale(
            priceWholesale,
            promoEnabled,
            promoPercent,
          )
        : PriceCalculator.effectiveRetail(
            priceRetail,
            promoEnabled,
            promoPercent,
          );
  }

  Map<String, List<int>> get imageIndicesByColor {
    final map = <String, List<int>>{};
    for (int i = 0; i < photos.length; i++) {
      final color = photos[i].colorKey;
      if (color != null) {
        map.putIfAbsent(color, () => []).add(i);
      }
    }
    return map;
  }

  static List<ProductPhoto> _photosFromLegacy(
    List<String> images,
    int mainImageIndex,
  ) {
    if (images.isEmpty) return const [];
    final safeIndex = mainImageIndex.clamp(0, images.length - 1);
    return images.asMap().entries.map((entry) {
      return ProductPhoto(
        path: entry.value,
        colorKey: null,
        isPrimary: entry.key == safeIndex,
      );
    }).toList();
  }

  static List<String> _imagesFromPhotos(List<ProductPhoto> photos) {
    if (photos.isEmpty) return const [];
    return photos.map((p) => p.path).toList();
  }

  static int _mainIndexFromPhotos(List<ProductPhoto> photos, int fallback) {
    if (photos.isEmpty) return fallback;
    final primaryIndex = photos.indexWhere((p) => p.isPrimary);
    return primaryIndex >= 0 ? primaryIndex : 0;
  }
}
