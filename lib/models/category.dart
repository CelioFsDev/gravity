import 'package:hive/hive.dart';
import 'package:catalogo_ja/models/category_type.dart';

export 'category_type.dart';

part 'category.g.dart';

@HiveType(typeId: 9)
enum CollectionCoverMode {
  @HiveField(0)
  image,
  @HiveField(1)
  template,
}

@HiveType(typeId: 10)
class CollectionCover {
  static const String defaultTitle = 'CAT\u00c1LOGO';
  static const String defaultBrand = '2026';

  @HiveField(0)
  final CollectionCoverMode mode;

  @HiveField(1)
  final String? coverImagePath;

  @HiveField(2)
  final String? title;

  @HiveField(3)
  final String? brand;

  @HiveField(4)
  final String? subtitle;

  @HiveField(5)
  final int? backgroundColor;

  @HiveField(6)
  final double? overlayOpacity;

  @HiveField(7)
  final String? bannerImagePath;

  @HiveField(8)
  final String? heroImagePath;

  @HiveField(9)
  final String? coverHeaderImagePath;

  @HiveField(10)
  final String? coverMainImagePath;

  @HiveField(11)
  final String? coverMiniPath;

  @HiveField(12)
  final String? coverPagePath;

  const CollectionCover({
    this.mode = CollectionCoverMode.template,
    this.coverImagePath,
    this.title = defaultTitle,
    this.brand = defaultBrand,
    this.subtitle,
    this.backgroundColor,
    this.overlayOpacity,
    this.bannerImagePath,
    this.heroImagePath,
    this.coverHeaderImagePath,
    this.coverMainImagePath,
    this.coverMiniPath,
    this.coverPagePath,
  });

  CollectionCover copyWith({
    CollectionCoverMode? mode,
    String? coverImagePath,
    String? title,
    String? brand,
    String? subtitle,
    int? backgroundColor,
    double? overlayOpacity,
    String? bannerImagePath,
    String? heroImagePath,
    String? coverHeaderImagePath,
    String? coverMainImagePath,
    String? coverMiniPath,
    String? coverPagePath,
  }) {
    return CollectionCover(
      mode: mode ?? this.mode,
      coverImagePath: coverImagePath ?? this.coverImagePath,
      title: title ?? this.title,
      brand: brand ?? this.brand,
      subtitle: subtitle ?? this.subtitle,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      overlayOpacity: overlayOpacity ?? this.overlayOpacity,
      bannerImagePath: bannerImagePath ?? this.bannerImagePath,
      heroImagePath: heroImagePath ?? this.heroImagePath,
      coverHeaderImagePath: coverHeaderImagePath ?? this.coverHeaderImagePath,
      coverMainImagePath: coverMainImagePath ?? this.coverMainImagePath,
      coverMiniPath: coverMiniPath ?? this.coverMiniPath,
      coverPagePath: coverPagePath ?? this.coverPagePath,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'mode': mode.name,
      'coverImagePath': coverImagePath,
      'title': title,
      'brand': brand,
      'subtitle': subtitle,
      'backgroundColor': backgroundColor,
      'overlayOpacity': overlayOpacity,
      'bannerImagePath': bannerImagePath,
      'heroImagePath': heroImagePath,
      'coverHeaderImagePath': coverHeaderImagePath,
      'coverMainImagePath': coverMainImagePath,
      'coverMiniPath': coverMiniPath,
      'coverPagePath': coverPagePath,
    };
  }

  factory CollectionCover.fromMap(Map<String, dynamic> map) {
    return CollectionCover(
      mode: CollectionCoverMode.values.firstWhere(
        (e) => e.name == map['mode'],
        orElse: () => CollectionCoverMode.template,
      ),
      coverImagePath: map['coverImagePath'],
      title: map['title'],
      brand: map['brand'],
      subtitle: map['subtitle'],
      backgroundColor: map['backgroundColor'],
      overlayOpacity: map['overlayOpacity'],
      bannerImagePath: map['bannerImagePath'],
      heroImagePath: map['heroImagePath'],
      coverHeaderImagePath: map['coverHeaderImagePath'],
      coverMainImagePath: map['coverMainImagePath'],
      coverMiniPath: map['coverMiniPath'],
      coverPagePath: map['coverPagePath'],
    );
  }
}

@HiveType(typeId: 3)
class Category {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String? name;

  @HiveField(2)
  final int order;

  @HiveField(3)
  final DateTime createdAt;

  @HiveField(4)
  final DateTime updatedAt;

  @HiveField(5)
  final CategoryType type;

  @HiveField(6)
  final CollectionCover? cover;

  @HiveField(7)
  final String? slug;

  @HiveField(8)
  final bool isActive;

  @HiveField(9)
  final String? tenantId;

  Category({
    required this.id,
    required this.order,
    required this.createdAt,
    required this.updatedAt,
    this.type = CategoryType.productType,
    this.cover,
    this.isActive = true,
    this.tenantId,
    String? name,
    String? slug,
  }) : name = name,
       slug = slug;

  /// Retorna o nome ou um valor padr\u00e3o se for nulo/vazio
  String get safeName =>
      (name == null || name!.trim().isEmpty) ? 'Sem nome' : name!;

  /// Retorna o slug ou um valor padr\u00e3o se for nulo/vazio
  String get safeSlug =>
      (slug == null || slug!.trim().isEmpty) ? 'sem-slug' : slug!;

  Category copyWith({
    String? id,
    String? name,
    int? order,
    DateTime? createdAt,
    DateTime? updatedAt,
    CategoryType? type,
    CollectionCover? cover,
    String? slug,
    bool? isActive,
    String? tenantId,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      order: order ?? this.order,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      type: type ?? this.type,
      cover: cover ?? this.cover,
      slug: slug ?? this.slug,
      isActive: isActive ?? this.isActive,
      tenantId: tenantId ?? this.tenantId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'order': order,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'type': type.name,
      'cover': cover?.toMap(),
      'slug': slug,
      'isActive': isActive,
      'tenantId': tenantId,
    };
  }

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'] ?? '',
      name: map['name'],
      order: map['order'] ?? 0,
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
      type: CategoryType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => CategoryType.productType,
      ),
      cover: map['cover'] != null
          ? CollectionCover.fromMap(Map<String, dynamic>.from(map['cover']))
          : null,
      slug: map['slug'],
      isActive: map['isActive'] ?? true,
      tenantId: map['tenantId'],
    );
  }

  /// Gera um slug a partir do nome
  static String generateSlug(String name) {
    return name
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
  }

  /// 🔄 Verifica se a categoria/coleção tem capas locais pendentes de sincronização
  bool get hasLocalOnlyCover {
    if (cover == null) return false;
    final cv = cover!;
    final paths = [
      cv.coverImagePath,
      cv.bannerImagePath,
      cv.heroImagePath,
      cv.coverHeaderImagePath,
      cv.coverMainImagePath,
      cv.coverMiniPath,
      cv.coverPagePath
    ];

    return paths.any((p) =>
        p != null &&
        p.isNotEmpty &&
        (!p.startsWith('http') && !p.startsWith('gs://') && !p.startsWith('data:')));
  }
}
