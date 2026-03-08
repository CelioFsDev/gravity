import 'package:catalogo_ja/models/category.dart';
import 'package:catalogo_ja/models/product.dart';
import 'package:catalogo_ja/models/product_image.dart';

class CatalogoJaExportPayload {
  final String app;
  final int version;
  final String exportedAt;
  final StoreInfoDTO? store;
  final List<CategoryDTO> categories;
  final List<CategoryDTO>
  collections; // Collections are Categories with type=collection
  final List<ProductDTO> products;

  CatalogoJaExportPayload({
    required this.app,
    required this.version,
    required this.exportedAt,
    this.store,
    required this.categories,
    required this.collections,
    required this.products,
  });

  Map<String, dynamic> toJson() {
    return {
      'app': app,
      'version': version,
      'exportedAt': exportedAt,
      if (store != null) 'store': store!.toJson(),
      'categories': categories.map((e) => e.toJson()).toList(),
      'collections': collections.map((e) => e.toJson()).toList(),
      'products': products.map((e) => e.toJson()).toList(),
    };
  }

  factory CatalogoJaExportPayload.fromJson(Map<String, dynamic> json) {
    return CatalogoJaExportPayload(
      app: json['app'] as String? ?? 'CatalogoJa',
      version: json['version'] as int? ?? 1,
      exportedAt:
          json['exportedAt'] as String? ?? DateTime.now().toIso8601String(),
      store: json['store'] != null
          ? StoreInfoDTO.fromJson(json['store'])
          : null,
      categories:
          (json['categories'] as List<dynamic>?)
              ?.map((e) => CategoryDTO.fromJson(e))
              .toList() ??
          [],
      collections:
          (json['collections'] as List<dynamic>?)
              ?.map((e) => CategoryDTO.fromJson(e))
              .toList() ??
          [],
      products:
          (json['products'] as List<dynamic>?)
              ?.map((e) => ProductDTO.fromJson(e))
              .toList() ??
          [],
    );
  }
}

class StoreInfoDTO {
  final String? name;
  final String? phone;

  StoreInfoDTO({this.name, this.phone});

  Map<String, dynamic> toJson() => {'name': name, 'phone': phone};

  factory StoreInfoDTO.fromJson(Map<String, dynamic> json) {
    return StoreInfoDTO(name: json['name'], phone: json['phone']);
  }
}

/// Simplified definition for Export/Import
/// We map existing entities to these DTOs to decouple from Hive specifics if needed,
/// though for now we can mirror the fields closely.
class CategoryDTO {
  final String id;
  final String name;
  final String slug;
  final bool isActive;
  final int order;
  final String? type; // 'productType' | 'collection'

  // Specific to Collection
  final CollectionCoverDTO? cover;

  final String? createdAt;
  final String? updatedAt;

  CategoryDTO({
    required this.id,
    required this.name,
    required this.slug,
    this.isActive = true,
    this.order = 0,
    this.type,
    this.cover,
    this.createdAt,
    this.updatedAt,
  });

  factory CategoryDTO.fromModel(Category category) {
    return CategoryDTO(
      id: category.id,
      name: category.safeName,
      slug: category.safeSlug,
      isActive: category.isActive,
      order: category.order,
      type: category.type == CategoryType.productType
          ? 'productType'
          : 'collection',
      cover: category.cover != null
          ? CollectionCoverDTO.fromModel(category.cover!)
          : null,
      createdAt: category.createdAt.toIso8601String(),
      updatedAt: category.updatedAt.toIso8601String(),
    );
  }

  // Converts DTO back to Model.
  // NOTE: 'type' parameter is used to force type if DTO doesn't establish it (e.g. from separate lists)
  Category toModel({CategoryType? forceType}) {
    CategoryType resolvedType = forceType ?? CategoryType.productType;
    if (type == 'collection') resolvedType = CategoryType.collection;

    return Category(
      id: id,
      name: name,
      slug: slug,
      isActive: isActive,
      order: order,
      type: resolvedType,
      cover: cover?.toModel(),
      createdAt: DateTime.tryParse(createdAt ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(updatedAt ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      'isActive': isActive,
      'order': order,
      'type': type,
      if (cover != null) 'cover': cover!.toJson(),
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  factory CategoryDTO.fromJson(Map<String, dynamic> json) {
    return CategoryDTO(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      slug: json['slug'] ?? '',
      isActive: json['isActive'] ?? true,
      order: json['order'] ?? 0,
      type: json['type'],
      cover: json['cover'] != null
          ? CollectionCoverDTO.fromJson(json['cover'])
          : null,
      createdAt: json['createdAt'],
      updatedAt: json['updatedAt'],
    );
  }
}

class CollectionCoverDTO {
  final String? title;
  final String? mode; // 'image', 'template'
  final String? coverImagePath;
  final String? coverMiniPath;
  final String? coverPagePath;

  // Reduced set of fields for P0
  CollectionCoverDTO({
    this.title,
    this.mode,
    this.coverImagePath,
    this.coverMiniPath,
    this.coverPagePath,
  });

  factory CollectionCoverDTO.fromModel(CollectionCover cover) {
    return CollectionCoverDTO(
      title: cover.title,
      mode: cover.mode == CollectionCoverMode.image ? 'image' : 'template',
      coverImagePath: cover.coverImagePath,
      coverMiniPath: cover.coverMiniPath,
      coverPagePath: cover.coverPagePath,
    );
  }

  CollectionCover toModel() {
    return CollectionCover(
      title: title ?? '',
      mode: mode == 'image'
          ? CollectionCoverMode.image
          : CollectionCoverMode.template,
      coverImagePath: coverImagePath,
      coverMiniPath: coverMiniPath,
      coverPagePath: coverPagePath,
    );
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'mode': mode,
    'coverImagePath': coverImagePath,
    'coverMiniPath': coverMiniPath,
    'coverPagePath': coverPagePath,
  };

  factory CollectionCoverDTO.fromJson(Map<String, dynamic> json) {
    return CollectionCoverDTO(
      title: json['title'],
      mode: json['mode'],
      coverImagePath: json['coverImagePath'],
      coverMiniPath: json['coverMiniPath'],
      coverPagePath: json['coverPagePath'],
    );
  }
}

class ProductPhotoDTO {
  final String path;
  final String? colorKey;
  final bool isPrimary;
  final String? photoType;

  ProductPhotoDTO({
    required this.path,
    this.colorKey,
    this.isPrimary = false,
    this.photoType,
  });

  factory ProductPhotoDTO.fromModel(ProductPhoto photo) {
    return ProductPhotoDTO(
      path: photo.path,
      colorKey: photo.colorKey,
      isPrimary: photo.isPrimary,
      photoType: photo.photoType,
    );
  }

  ProductPhoto toModel() {
    return ProductPhoto(
      path: path,
      colorKey: colorKey,
      isPrimary: isPrimary,
      photoType: photoType,
    );
  }

  ProductImage toProductImage() {
    return ProductImage(
      id: '', // Blank or generate
      sourceType: ProductImageSource.localPath,
      uri: path,
      label: photoType,
      colorTag: colorKey,
    );
  }

  Map<String, dynamic> toJson() => {
    'path': path,
    'colorKey': colorKey,
    'isPrimary': isPrimary,
    'photoType': photoType,
  };

  factory ProductPhotoDTO.fromJson(Map<String, dynamic> json) {
    return ProductPhotoDTO(
      path: json['path'] ?? '',
      colorKey: json['colorKey'],
      isPrimary: json['isPrimary'] ?? false,
      photoType: json['photoType'],
    );
  }
}

class ProductImageDTO {
  final String id;
  final String sourceType;
  final String uri;
  final String? label;
  final int order;
  final String? colorTag;

  ProductImageDTO({
    required this.id,
    required this.sourceType,
    required this.uri,
    this.label,
    required this.order,
    this.colorTag,
  });

  factory ProductImageDTO.fromModel(ProductImage model) {
    return ProductImageDTO(
      id: model.id,
      sourceType: model.sourceType.name,
      uri: model.uri,
      label: model.label,
      order: model.order,
      colorTag: model.colorTag,
    );
  }

  ProductImage soul() {
    return ProductImage(
      id: id,
      sourceType: ProductImageSource.values.firstWhere(
        (e) => e.name == sourceType,
        orElse: () => ProductImageSource.unknown,
      ),
      uri: uri,
      label: label,
      order: order,
      colorTag: colorTag,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'sourceType': sourceType,
    'uri': uri,
    'label': label,
    'order': order,
    'colorTag': colorTag,
  };

  factory ProductImageDTO.fromJson(Map<String, dynamic> json) {
    return ProductImageDTO(
      id: json['id'] ?? '',
      sourceType: json['sourceType'] ?? 'unknown',
      uri: json['uri'] ?? '',
      label: json['label'],
      order: json['order'] ?? 0,
      colorTag: json['colorTag'],
    );
  }
}

class ProductDTO {
  final String id;
  final String name;
  final String ref;
  final String sku;
  final double priceRetail;
  final double priceWholesale;
  final bool isActive;
  final bool isOutOfStock;
  final bool promoEnabled;
  final double promoPercent;
  final List<ProductImageDTO> images;
  final List<ProductPhotoDTO> photos;
  final int mainImageIndex;

  // Relations
  final List<String>? categoryIds; // Can be collections or actual categories
  // In the model, categoryIds holds both.

  final List<String> sizes;
  final List<String> colors;

  final String? createdAt;
  final String? updatedAt;

  final List<String> remoteImages;

  ProductDTO({
    required this.id,
    required this.name,
    required this.ref,
    required this.sku,
    required this.priceRetail,
    required this.priceWholesale,
    this.isActive = true,
    this.isOutOfStock = false,
    this.promoEnabled = false,
    this.promoPercent = 0,
    this.images = const [],
    this.photos = const [],
    this.remoteImages = const [],
    this.mainImageIndex = 0,
    this.categoryIds,
    this.sizes = const [],
    this.colors = const [],
    this.createdAt,
    this.updatedAt,
  });

  factory ProductDTO.fromModel(Product product) {
    return ProductDTO(
      id: product.id,
      name: product.name,
      ref: product.ref,
      sku: product.sku,
      priceRetail: product.priceRetail,
      priceWholesale: product.priceWholesale,
      isActive: product.isActive,
      isOutOfStock: product.isOutOfStock,
      promoEnabled: product.promoEnabled,
      promoPercent: product.promoPercent,
      images: product.images.map((i) => ProductImageDTO.fromModel(i)).toList(),
      photos: product.photos.map((p) => ProductPhotoDTO.fromModel(p)).toList(),
      remoteImages: product.remoteImages,
      mainImageIndex: product.mainImageIndex,
      categoryIds: product.categoryIds,
      sizes: product.sizes,
      colors: product.colors,
      createdAt: product.createdAt.toIso8601String(),
      updatedAt: product.updatedAt.toIso8601String(),
    );
  }

  Product toModel() {
    return Product(
      id: id,
      name: name,
      ref: ref,
      sku: sku,
      categoryIds: categoryIds ?? [],
      priceRetail: priceRetail,
      priceWholesale: priceWholesale,
      minWholesaleQty: 1, // Default
      sizes: sizes,
      colors: colors,
      images: images.map((i) => i.soul()).toList(),
      photos: photos.map((p) => p.toModel()).toList(),
      remoteImages: remoteImages,
      mainImageIndex: mainImageIndex,
      isActive: isActive,
      isOutOfStock: isOutOfStock,
      promoEnabled: promoEnabled,
      promoPercent: promoPercent,
      createdAt: DateTime.tryParse(createdAt ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(updatedAt ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'ref': ref,
      'sku': sku,
      'priceRetail': priceRetail,
      'priceWholesale': priceWholesale,
      'isActive': isActive,
      'isOutOfStock': isOutOfStock,
      'promoEnabled': promoEnabled,
      'promoPercent': promoPercent,
      'images': images.map((i) => i.toJson()).toList(),
      'photos': photos.map((p) => p.toJson()).toList(),
      'remoteImages': remoteImages,
      'mainImageIndex': mainImageIndex,
      'categoryIds': categoryIds,
      'sizes': sizes,
      'colors': colors,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  factory ProductDTO.fromJson(Map<String, dynamic> json) {
    return ProductDTO(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      ref: json['ref'] ?? '',
      sku: json['sku'] ?? '',
      priceRetail: (json['priceRetail'] as num?)?.toDouble() ?? 0.0,
      priceWholesale: (json['priceWholesale'] as num?)?.toDouble() ?? 0.0,
      isActive: json['isActive'] ?? true,
      isOutOfStock: json['isOutOfStock'] ?? false,
      promoEnabled: json['promoEnabled'] ?? false,
      promoPercent: (json['promoPercent'] as num?)?.toDouble() ?? 0.0,
      images:
          (json['images'] as List<dynamic>?)?.map((e) {
            if (e is Map<String, dynamic>) {
              return ProductImageDTO.fromJson(e);
            }
            // Legacy conversion
            return ProductImageDTO.fromModel(
              ProductImage.local(path: e.toString()),
            );
          }).toList() ??
          [],
      photos:
          (json['photos'] as List<dynamic>?)
              ?.map((e) => ProductPhotoDTO.fromJson(e))
              .toList() ??
          [],
      remoteImages:
          (json['remoteImages'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      mainImageIndex: json['mainImageIndex'] ?? 0,
      categoryIds: (json['categoryIds'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
      sizes:
          (json['sizes'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      colors:
          (json['colors'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      createdAt: json['createdAt'],
      updatedAt: json['updatedAt'],
    );
  }
}
