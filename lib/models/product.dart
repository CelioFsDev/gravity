import 'dart:convert';
import 'package:hive/hive.dart';
import 'package:catalogo_ja/core/utils/safe_parse.dart';
import 'package:catalogo_ja/models/sync_status.dart';

export 'sync_status.dart';
import 'package:catalogo_ja/core/utils/price_calculator.dart';
import 'package:catalogo_ja/models/product_variant.dart';
import 'package:catalogo_ja/models/product_image.dart';

part 'product.g.dart';

bool _isRemoteOrStorageImageUri(String uri) {
  final trimmed = uri.trim();
  return trimmed.startsWith('http://') ||
      trimmed.startsWith('https://') ||
      trimmed.startsWith('gs://') ||
      trimmed.startsWith('tenants/') ||
      trimmed.startsWith('public_catalogs/') ||
      trimmed.startsWith('data:') ||
      trimmed.startsWith('blob:');
}

bool _isLocalOnlyImageUri(String uri) {
  final trimmed = uri.trim();
  if (trimmed.isEmpty) return false;
  if (trimmed.startsWith('data:') || trimmed.startsWith('blob:')) return true;
  return !_isRemoteOrStorageImageUri(trimmed);
}

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

  @HiveField(4)
  final String? id;

  @HiveField(5)
  final String url;

  const ProductPhoto({
    required this.path,
    this.colorKey,
    this.isPrimary = false,
    this.photoType,
    this.id,
    this.url = '',
  });

  ProductPhoto copyWith({
    String? path,
    String? colorKey,
    bool? isPrimary,
    String? photoType,
    String? id,
    String? url,
  }) {
    return ProductPhoto(
      path: path ?? this.path,
      colorKey: colorKey ?? this.colorKey,
      isPrimary: isPrimary ?? this.isPrimary,
      photoType: photoType ?? this.photoType,
      id: id ?? this.id,
      url: url ?? this.url,
    );
  }

  ProductImage toProductImage() {
    final imageUri = url.isNotEmpty ? url : path;
    final isRemote = _isRemoteOrStorageImageUri(imageUri);
    return ProductImage(
      id: id ?? 'legacy_${imageUri.hashCode}',
      sourceType: isRemote
          ? ProductImageSource.networkUrl
          : ProductImageSource.localPath,
      uri: imageUri,
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
      'categoryIds': categoryIds.toList(),
      'priceRetail': priceRetail,
      'priceWholesale': priceWholesale,
      'minWholesaleQty': minWholesaleQty,
      'sizes': sizes.toList(),
      'colors': colors.toList(),
      'images': images
          .map(
            (img) => {
              'id': img.id,
              'uri': img.uri,
              'sourceType': img.sourceType.index,
              'label': img.label,
              'order': img.order,
              'colorTag': img.colorTag,
            },
          )
          .toList(),
      'mainImageIndex': mainImageIndex,
      'isActive': isActive,
      'isOutOfStock': isOutOfStock,
      'promoEnabled': promoEnabled,
      'createdAt': createdAt.toIso8601String(),
      'promoPercent': promoPercent,
      'slug': slug,
      'description': description,
      'tags': tags.toList(),
      'remoteImages': remoteImages.toList(),
      'variants': variants
          .map(
            (v) => {'sku': v.sku, 'stock': v.stock, 'attributes': v.attributes},
          )
          .toList(),
      'updatedAt': updatedAt.toIso8601String(),
      'photos': photos
          .map(
            (p) => {
              'path': p.path,
              'colorKey': p.colorKey,
              'isPrimary': p.isPrimary,
              'photoType': p.photoType,
              'id': p.id,
              'url': p.url,
            },
          )
          .toList(),
      'tenantId': tenantId,
      'storeOverrides': storeOverrides,
      'syncStatus': syncStatus.index,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    List<ProductVariant> parseVariants(dynamic value) {
      if (value is! List) return const [];
      return value
          .where((item) => item is ProductVariant || item is Map)
          .map<ProductVariant>((item) {
            if (item is ProductVariant) return item;
            return ProductVariant.fromMap(safeMap(item));
          })
          .toList();
    }

    Map<String, Map<String, dynamic>> parseStoreOverrides(dynamic value) {
      final overrides = safeMap(value);
      if (overrides.isEmpty) return const {};
      final result = <String, Map<String, dynamic>>{};
      overrides.forEach((key, item) {
        final nested = safeMap(item);
        if (nested.isNotEmpty) result[key] = nested;
      });
      return result;
    }

    List<dynamic> parseDynamicList(dynamic value) {
      if (value == null) return const [];
      if (value is List) return value;
      if (value is String && value.trim().isNotEmpty) return [value.trim()];
      return const [];
    }

    SyncStatus parseSyncStatus(dynamic value) {
      if (value is SyncStatus) return value;
      final index = value is int ? value : int.tryParse(safeString(value));
      if (index != null && index >= 0 && index < SyncStatus.values.length) {
        return SyncStatus.values[index];
      }
      final name = safeString(value).trim();
      if (name.isNotEmpty) {
        return SyncStatus.values.firstWhere(
          (status) => status.name == name,
          orElse: () => SyncStatus.synced,
        );
      }
      return SyncStatus.synced;
    }

    return Product(
      id: safeString(map['id']),
      name: safeString(map['name']),
      ref: safeString(map['ref'] ?? map['reference']),
      sku: safeString(map['sku']),
      categoryIds: safeStringList(map['categoryIds']),
      priceRetail: safeDouble(map['priceRetail'] ?? map['priceVarejo']),
      priceWholesale: safeDouble(map['priceWholesale'] ?? map['priceAtacado']),
      minWholesaleQty: safeInt(map['minWholesaleQty'], fallback: 1),
      sizes: safeStringList(map['sizes']),
      colors: safeStringList(map['colors']),
      images: parseDynamicList(map['images']).map<ProductImage>((item) {
        if (item is ProductImage) return item;
        if (item is Map) {
          return ProductImage.fromMap(safeMap(item));
        }
        if (item is String) {
          return ProductImage.network(url: item);
        }
        return ProductImage.unknown();
      }).toList(),
      mainImageIndex: safeInt(map['mainImageIndex']),
      isActive: safeBool(map['isActive'], fallback: true),
      isOutOfStock: safeBool(map['isOutOfStock'], fallback: false),
      promoEnabled: safeBool(
        map['promoEnabled'] ?? map['isOnSale'],
        fallback: false,
      ),
      promoPercent: safeDouble(
        map['promoPercent'] ?? map['saleDiscountPercent'],
      ),
      slug: safeString(map['slug']),
      description: safeNullableString(map['description']),
      tags: safeStringList(map['tags']),
      remoteImages: safeStringList(
        map['remoteImages'] ??
            map['imageUrls'] ??
            map['imageUrl'] ??
            map['image'] ??
            map['photo'],
      ),
      variants: parseVariants(map['variants']),
      createdAt: safeDateTime(map['createdAt']),
      updatedAt: safeDateTime(map['updatedAt']),
      photos: parseDynamicList(map['photos'])
          .where((p) => p is ProductPhoto || p is Map || p is String)
          .map<ProductPhoto>((p) {
            if (p is ProductPhoto) return p;
            if (p is String) {
              return ProductPhoto(path: p);
            }
            if (p is! Map) {
              return const ProductPhoto(path: '');
            }

            final photoMap = safeMap(p);
            return ProductPhoto(
              path: safeString(photoMap['path'] ?? photoMap['url']),
              colorKey: safeNullableString(photoMap['colorKey']),
              isPrimary: safeBool(photoMap['isPrimary'], fallback: false),
              photoType: safeNullableString(photoMap['photoType']),
              id: safeNullableString(photoMap['id']),
              url: safeString(photoMap['url']),
            );
          })
          .toList(),
      tenantId: safeNullableString(map['tenantId']),
      storeOverrides: parseStoreOverrides(map['storeOverrides']),
      syncStatus: parseSyncStatus(map['syncStatus']),
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
      final sorted = images.toList()
        ..sort((a, b) => a.order.compareTo(b.order));
      return sorted.first;
    }

    // Priority 2: Legacy photos list
    if (photos.isNotEmpty) {
      final mainP = photos.where((p) => p.isPrimary).toList();
      if (mainP.isNotEmpty) return mainP.first.toProductImage();
      return photos.first.toProductImage();
    }

    if (remoteImages.isNotEmpty) {
      final remoteUrl = remoteImages.firstWhere(
        (url) => url.trim().isNotEmpty,
        orElse: () => '',
      );
      if (remoteUrl.isNotEmpty) {
        return ProductImage.network(url: remoteUrl.trim());
      }
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

  double _overrideDouble(String? storeId, String key, double fallback) {
    final value = _getOverride(storeId)?[key];
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(value.replaceAll(',', '.')) ?? fallback;
    }
    return fallback;
  }

  bool _overrideBool(String? storeId, String key, bool fallback) {
    final value = _getOverride(storeId)?[key];
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1') return true;
      if (normalized == 'false' || normalized == '0') return false;
    }
    return fallback;
  }

  List<String> _overrideStringList(String? storeId, String key) {
    final value = _getOverride(storeId)?[key];
    if (value is! List) return const [];
    return value
        .where((item) => item != null)
        .map((item) => item.toString())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  double getRetailPrice(String? storeId) =>
      _overrideDouble(storeId, 'priceRetail', priceRetail);

  double getWholesalePrice(String? storeId) =>
      _overrideDouble(storeId, 'priceWholesale', priceWholesale);

  bool getIsActive(String? storeId) =>
      _overrideBool(storeId, 'isActive', isActive);

  List<String> getAvailableSizes(String? storeId) {
    final unavailable = _overrideStringList(storeId, 'unavailableSizes');
    if (unavailable.isEmpty) return sizes;
    return sizes.where((s) => !unavailable.contains(s)).toList();
  }

  List<String> getAvailableColors(String? storeId) {
    final unavailable = _overrideStringList(storeId, 'unavailableColors');
    if (unavailable.isEmpty) return colors;
    return colors.where((c) => !unavailable.contains(c)).toList();
  }

  bool isColorAvailable(String color, String? storeId) =>
      getAvailableColors(storeId).contains(color);

  /// 🔄 Verifica se o produto tem fotos locais pendentes de sincronização
  bool get hasLocalOnlyPhotos {
    // Verifica na lista moderna de images
    final hasLocalImages = images.any((i) => _isLocalOnlyImageUri(i.uri));

    if (hasLocalImages) return true;

    // Verifica na lista legado de photos
    return photos.any(
      (p) =>
          _isLocalOnlyImageUri(p.path) ||
          (p.url.trim().isNotEmpty && _isLocalOnlyImageUri(p.url)),
    );
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
