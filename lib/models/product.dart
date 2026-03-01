import 'package:hive/hive.dart';
import 'package:catalogo_ja/core/utils/price_calculator.dart';
import 'package:catalogo_ja/models/product_variant.dart';
import 'package:catalogo_ja/models/product_image.dart';

part 'product.g.dart';

// KEEP ProductPhoto for backward compatibility during migration, but mark it?
// The user wants ProductImage instead. I'll keep it as a legacy holder if needed.
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

  ProductImage toProductImage() {
    return ProductImage(
      id: 'legacy_${path.hashCode}',
      sourceType: path.startsWith('http')
          ? ProductImageSource.networkUrl
          : ProductImageSource.localPath,
      uri: path,
      label: photoType ?? (isPrimary ? 'principal' : null),
      colorTag: colorKey,
      order: isPrimary ? 0 : 1,
    );
  }
}

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
  final List<ProductImage> images; // Updated from List<String>

  @HiveField(11)
  final int mainImageIndex; // Deprecated but kept for Hive compat

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
  final List<ProductPhoto> photos; // Legacy photos

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
    required this.images, // Now List<ProductImage>
    required this.mainImageIndex,
    required this.isActive,
    required this.isOutOfStock,
    required this.promoEnabled,
    required this.createdAt,
    this.photos = const [],
    this.promoPercent = 0.0,
    this.slug = '',
    this.description,
    this.tags = const [],
    this.remoteImages = const [],
    this.variants = const [],
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? createdAt;

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
    List<ProductImage>? images,
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
      images: images ?? this.images,
      mainImageIndex: mainImageIndex ?? this.mainImageIndex,
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
      photos: photos ?? this.photos,
    );
  }

  // --- HELPERS (ProductImage) ---

  ProductImage? get mainImage {
    if (images.isEmpty) return null;
    final main = images.where((i) => i.label == 'principal').toList();
    if (main.isNotEmpty) return main.first;
    final sorted = List<ProductImage>.from(images)
      ..sort((a, b) => a.order.compareTo(b.order));
    return sorted.first;
  }

  List<ProductImage> get detailImages =>
      images.where((i) => i.label?.startsWith('detalhe') ?? false).toList();

  List<ProductImage> get colorImages => images
      .where((i) => (i.label?.startsWith('cor') ?? false) || i.colorTag != null)
      .toList();

  Map<String, List<int>> get imageIndicesByColor {
    final result = <String, List<int>>{};
    for (var i = 0; i < images.length; i++) {
      final img = images[i];
      if (img.colorTag != null) {
        result.putIfAbsent(img.colorTag!, () => []).add(i);
      }
    }
    return result;
  }

  // --- ALIASES for compatibility ---
  double get retailPrice => priceRetail;
  double get priceVarejo => priceRetail;
  double get wholesalePrice => priceWholesale;
  double get priceAtacado => priceWholesale;
  String get reference => ref;
  bool get isOnSale => promoEnabled;
  int get saleDiscountPercent => promoPercent.toInt();

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
}
