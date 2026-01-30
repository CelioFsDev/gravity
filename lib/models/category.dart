import 'package:hive/hive.dart';
import 'package:gravity/models/category_type.dart';

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
  static const String defaultBrand = 'VITORIANA';

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
    );
  }
}

@HiveType(typeId: 3)
class Category {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

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

  Category({
    required this.id,
    required this.name,
    required this.order,
    required this.createdAt,
    required this.updatedAt,
    this.type = CategoryType.productType,
    this.cover,
  });

  Category copyWith({
    String? id,
    String? name,
    int? order,
    DateTime? createdAt,
    DateTime? updatedAt,
    CategoryType? type,
    CollectionCover? cover,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      order: order ?? this.order,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      type: type ?? this.type,
      cover: cover ?? this.cover,
    );
  }
}
