import 'dart:convert';
import 'package:hive/hive.dart';
import 'package:catalogo_ja/models/sync_status.dart';

export 'sync_status.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
    final isRemote =
        path.startsWith('http://') ||
        path.startsWith('https://') ||
        path.startsWith('data:') ||
        path.startsWith('blob:');
    return ProductImage(
      id: 'legacy_${path.hashCode}',
      sourceType: isRemote
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

  @HiveField(25)
  final String? tenantId;

  @HiveField(26)
  final Map<String, Map<String, dynamic>> storeOverrides;

  @HiveField(27)
  final SyncStatus syncStatus;

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
    this.tenantId,
    this.storeOverrides = const {},
    this.syncStatus = SyncStatus.pendingUpdate,
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
    String? tenantId,
    Map<String, Map<String, dynamic>>? storeOverrides,
    SyncStatus? syncStatus,
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
      tenantId: tenantId ?? this.tenantId,
      storeOverrides: storeOverrides ?? this.storeOverrides,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'ref': ref,
      'sku': sku,
      'categoryIds': List<String>.from(categoryIds),
      'priceRetail': priceRetail,
      'priceWholesale': priceWholesale,
      'minWholesaleQty': minWholesaleQty,
      'sizes': List<String>.from(sizes),
      'colors': List<String>.from(colors),
      'images': images.map((img) => {
        'id': img.id,
        'uri': img.uri,
        'sourceType': img.sourceType.index,
        'label': img.label,
        'order': img.order,
        'colorTag': img.colorTag,
      }).toList(),
      'mainImageIndex': mainImageIndex,
      'isActive': isActive,
      'isOutOfStock': isOutOfStock,
      'promoEnabled': promoEnabled,
      'createdAt': createdAt.toIso8601String(),
      'promoPercent': promoPercent,
      'slug': slug,
      'description': description,
      'tags': List<String>.from(tags),
      'remoteImages': List<String>.from(remoteImages),
      'variants': variants.map((v) => {
        'sku': v.sku,
        'stock': v.stock,
        'attributes': v.attributes,
      }).toList(),
      'updatedAt': updatedAt.toIso8601String(),
      'photos': photos.map((p) => {
        'path': p.path,
        'colorKey': p.colorKey,
        'isPrimary': p.isPrimary,
        'photoType': p.photoType,
      }).toList(),
      'tenantId': tenantId,
      'storeOverrides': storeOverrides,
      'syncStatus': syncStatus.index,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
      return DateTime.now();
    }

    return Product(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      ref: (map['ref'] ?? map['reference'] ?? '').toString(),
      sku: map['sku'] ?? '',
      categoryIds: List<String>.from(map['categoryIds'] ?? []),
      priceRetail: (map['priceRetail'] ?? map['priceVarejo'] ?? 0.0).toDouble(),
      priceWholesale: (map['priceWholesale'] ?? map['priceAtacado'] ?? 0.0).toDouble(),
      minWholesaleQty: map['minWholesaleQty'] ?? 1,
      sizes: List<String>.from(map['sizes'] ?? []),
      colors: List<String>.from(map['colors'] ?? []),
      images: (map['images'] as List? ?? []).map((i) {
        if (i is Map) {
          return ProductImage.fromMap(Map<String, dynamic>.from(i));
        }
        // Legacy support: if it's a string, it's a direct URL
        if (i is String) {
          return ProductImage.network(url: i);
        }
        return ProductImage.unknown(); // Use an empty placeholder
      }).toList(),
      mainImageIndex: map['mainImageIndex'] ?? 0,
      isActive: map['isActive'] ?? true,
      isOutOfStock: map['isOutOfStock'] ?? false,
      promoEnabled: map['promoEnabled'] ?? map['isOnSale'] ?? false,
      promoPercent: (map['promoPercent'] ?? map['saleDiscountPercent'] ?? 0.0).toDouble(),
      slug: map['slug'] ?? '',
      description: map['description'],
      tags: List<String>.from(map['tags'] ?? []),
      remoteImages: List<String>.from(map['remoteImages'] ?? []),
      variants: (map['variants'] as List? ?? [])
          .map((v) => ProductVariant.fromMap(Map<String, dynamic>.from(v)))
          .toList(),
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
      photos: (map['photos'] as List? ?? [])
          .map((p) => ProductPhoto(
                path: p['path'] ?? '',
                colorKey: p['colorKey'],
                isPrimary: p['isPrimary'] ?? false,
                photoType: p['photoType'],
              ))
          .toList(),
      tenantId: map['tenantId'],
      storeOverrides: (map['storeOverrides'] as Map?)?.map(
            (k, v) => MapEntry(k.toString(), Map<String, dynamic>.from(v as Map)),
          ) ??
          {},
      syncStatus: map['syncStatus'] != null 
          ? SyncStatus.values[map['syncStatus'] as int] 
          : SyncStatus.synced,
    );
  }

  // --- HELPERS (ProductImage) ---

  ProductImage? get mainImage {
    // Priority 1: New images list
    if (images.isNotEmpty) {
      // Check for 'P' label (from form) or 'principal' (legacy import)
      final main = images.where((i) {
        final l = i.label?.trim() ?? '';
        return l == 'P' || l == 'p' || l.toLowerCase() == 'principal';
      }).toList();
      if (main.isNotEmpty) return main.first;
      
      // Fallback: highest-priority order
      final sorted = List<ProductImage>.from(images)
        ..sort((a, b) => a.order.compareTo(b.order));
      return sorted.first;
    }
    
    // Priority 2: Legacy photos list
    if (photos.isNotEmpty) {
      final mainP = photos.where((p) => p.isPrimary).toList();
      if (mainP.isNotEmpty) return mainP.first.toProductImage();
      return photos.first.toProductImage();
    }
    
    return null;
  }

  List<ProductImage> get detailImages => images.where((i) {
    final l = i.label?.trim() ?? '';
    final lLower = l.toLowerCase();
    // Handles: 'D1', 'D2' (from form), 'd1', 'd2' (case-insensitive), 'detalhe' (legacy)
    return l == 'D1' ||
        l == 'D2' ||
        lLower == 'd1' ||
        lLower == 'd2' ||
        lLower.startsWith('detalhe');
  }).toList();

  List<ProductImage> get colorImages => images.where((i) {
    final l = i.label?.trim() ?? '';
    final lLower = l.toLowerCase();
    // Handles: 'C1'–'C4' (from form), 'c1'–'c4' (case-insensitive),
    //          'cor...' prefix (legacy), colorTag not null (from import)
    final isColorSlot =
        (l == 'C1' || l == 'C2' || l == 'C3' || l == 'C4') ||
        (lLower == 'c1' ||
            lLower == 'c2' ||
            lLower == 'c3' ||
            lLower == 'c4') ||
        lLower.startsWith('cor');
    return isColorSlot || i.colorTag != null;
  }).toList();

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

  // --- STORE SPECIFIC RESOLVERS ---

  Map<String, dynamic>? _getOverride(String? storeId) =>
      storeId != null ? storeOverrides[storeId] : null;

  double getRetailPrice(String? storeId) =>
      (_getOverride(storeId)?['priceRetail'] as num?)?.toDouble() ??
      priceRetail;

  double getWholesalePrice(String? storeId) =>
      (_getOverride(storeId)?['priceWholesale'] as num?)?.toDouble() ??
      priceWholesale;

  bool getIsActive(String? storeId) =>
      _getOverride(storeId)?['isActive'] as bool? ?? isActive;

  List<String> getAvailableSizes(String? storeId) {
    final unavailable =
        List<String>.from(_getOverride(storeId)?['unavailableSizes'] ?? []);
    if (unavailable.isEmpty) return sizes;
    return sizes.where((s) => !unavailable.contains(s)).toList();
  }

  List<String> getAvailableColors(String? storeId) {
    final unavailable =
        List<String>.from(_getOverride(storeId)?['unavailableColors'] ?? []);
    if (unavailable.isEmpty) return colors;
    return colors.where((c) => !unavailable.contains(c)).toList();
  }

  bool isColorAvailable(String color, String? storeId) =>
      getAvailableColors(storeId).contains(color);

  /// 🔄 Verifica se o produto tem fotos locais pendentes de sincronização
  bool get hasLocalOnlyPhotos {
    // Verifica na lista moderna de images
    final hasLocalImages = images.any((i) =>
        i.sourceType == ProductImageSource.localPath ||
        i.uri.startsWith('data:') ||
        i.uri.startsWith('blob:') ||
        (!i.uri.startsWith('http') && !i.uri.startsWith('gs://')));

    if (hasLocalImages) return true;

    // Verifica na lista legado de photos
    return photos.any((p) =>
        (!p.path.startsWith('http') && !p.path.startsWith('gs://')) ||
        p.path.startsWith('data:') ||
        p.path.startsWith('blob:'));
  }

  /// Verifica alterações reais baseadas em JSON do objeto, 
  /// ignorando datas de atualização e status de sincronismo.
  bool hasMeaningfulChanges(Product other) {
    final myMap = toMap()
      ..remove('updatedAt')
      ..remove('createdAt')
      ..remove('syncStatus');
    
    final otherMap = other.toMap()
      ..remove('updatedAt')
      ..remove('createdAt')
      ..remove('syncStatus');
      
    return jsonEncode(myMap) != jsonEncode(otherMap);
  }
}
