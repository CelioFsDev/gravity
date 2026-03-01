import 'package:hive/hive.dart';

part 'catalog.g.dart';

@HiveType(typeId: 5)
class CatalogBanner {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String imagePath;

  @HiveField(2)
  final String? title;

  CatalogBanner({required this.id, required this.imagePath, this.title});
}

@HiveType(typeId: 21)
enum CatalogMode {
  @HiveField(0)
  varejo,
  @HiveField(1)
  atacado,
}

extension CatalogModeExtension on CatalogMode {
  String get label =>
      this == CatalogMode.atacado ? 'CAT\u00c1LOGO ATACADO' : 'CAT\u00c1LOGO VAREJO';
}

@HiveType(typeId: 6)
class Catalog {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String slug;

  @HiveField(3)
  final bool active;

  @HiveField(4)
  final List<String> productIds;

  @HiveField(5)
  final bool requireCustomerData;

  @HiveField(6)
  final String photoLayout; // "grid", "list", "carousel"

  @HiveField(7)
  final bool announcementEnabled;

  @HiveField(8)
  final String? announcementText;

  @HiveField(9)
  final List<CatalogBanner> banners;

  @HiveField(10)
  final DateTime createdAt;

  @HiveField(11)
  final DateTime updatedAt;

  @HiveField(12)
  final CatalogMode mode;

  @HiveField(13)
  final bool isPublic;

  @HiveField(14)
  final String shareCode;

  @HiveField(15)
  final String ownerUid;

  @HiveField(16)
  final bool includeCover;

  @HiveField(17)
  final String? coverType; // "standard", "collection", "none" (maps to legacy includeCover=false)

  Catalog({
    required this.id,
    required this.name,
    required this.slug,
    required this.active,
    required this.productIds,
    required this.requireCustomerData,
    required this.photoLayout,
    required this.announcementEnabled,
    this.announcementText,
    required this.banners,
    required this.createdAt,
    required this.updatedAt,
    required this.mode,
    this.isPublic = false,
    this.shareCode = '',
    this.ownerUid = '',
    this.includeCover = true,
    this.coverType,
  });

  Catalog copyWith({
    String? id,
    String? name,
    String? slug,
    bool? active,
    List<String>? productIds,
    bool? requireCustomerData,
    String? photoLayout,
    bool? announcementEnabled,
    String? announcementText,
    List<CatalogBanner>? banners,
    DateTime? createdAt,
    DateTime? updatedAt,
    CatalogMode? mode,
    bool? isPublic,
    String? shareCode,
    String? ownerUid,
    bool? includeCover,
    String? coverType,
  }) {
    return Catalog(
      id: id ?? this.id,
      name: name ?? this.name,
      slug: slug ?? this.slug,
      active: active ?? this.active,
      productIds: productIds ?? this.productIds,
      requireCustomerData: requireCustomerData ?? this.requireCustomerData,
      photoLayout: photoLayout ?? this.photoLayout,
      announcementEnabled: announcementEnabled ?? this.announcementEnabled,
      announcementText: announcementText ?? this.announcementText,
      banners: banners ?? this.banners,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      mode: mode ?? this.mode,
      isPublic: isPublic ?? this.isPublic,
      shareCode: shareCode ?? this.shareCode,
      ownerUid: ownerUid ?? this.ownerUid,
      includeCover: includeCover ?? this.includeCover,
      coverType: coverType ?? this.coverType,
    );
  }
}
