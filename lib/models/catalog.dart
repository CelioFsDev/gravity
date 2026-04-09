import 'package:hive/hive.dart';
import 'package:catalogo_ja/models/sync_status.dart';

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

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'imagePath': imagePath,
      'title': title,
    };
  }

  factory CatalogBanner.fromMap(Map<String, dynamic> map) {
    return CatalogBanner(
      id: map['id'] ?? '',
      imagePath: map['imagePath'] ?? '',
      title: map['title'],
    );
  }

  CatalogBanner copyWith({
    String? id,
    String? imagePath,
    String? title,
  }) {
    return CatalogBanner(
      id: id ?? this.id,
      imagePath: imagePath ?? this.imagePath,
      title: title ?? this.title,
    );
  }
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

  @HiveField(18)
  final String? tenantId;

  @HiveField(19, defaultValue: SyncStatus.synced)
  final SyncStatus syncStatus;

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
    this.tenantId,
    this.syncStatus = SyncStatus.synced,
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
    String? tenantId,
    SyncStatus? syncStatus,
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
      tenantId: tenantId ?? this.tenantId,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      'active': active,
      'productIds': productIds,
      'requireCustomerData': requireCustomerData,
      'photoLayout': photoLayout,
      'announcementEnabled': announcementEnabled,
      'announcementText': announcementText,
      'banners': banners.map((b) => b.toMap()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'mode': mode.name,
      'isPublic': isPublic,
      'shareCode': shareCode,
      'ownerUid': ownerUid,
      'includeCover': includeCover,
      'coverType': coverType,
      'tenantId': tenantId,
      'syncStatus': syncStatus.name,
    };
  }

  factory Catalog.fromMap(Map<String, dynamic> map) {
    return Catalog(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      slug: map['slug'] ?? '',
      active: map['active'] ?? true,
      productIds: List<String>.from(map['productIds'] ?? []),
      requireCustomerData: map['requireCustomerData'] ?? false,
      photoLayout: map['photoLayout'] ?? 'grid',
      announcementEnabled: map['announcementEnabled'] ?? false,
      announcementText: map['announcementText'],
      banners: (map['banners'] as List? ?? [])
          .map((b) => CatalogBanner.fromMap(Map<String, dynamic>.from(b)))
          .toList(),
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
      mode: CatalogMode.values.firstWhere(
        (e) => e.name == map['mode'],
        orElse: () => CatalogMode.varejo,
      ),
      isPublic: map['isPublic'] ?? false,
      shareCode: map['shareCode'] ?? '',
      ownerUid: map['ownerUid'] ?? '',
      includeCover: map['includeCover'] ?? true,
      coverType: map['coverType'],
      tenantId: map['tenantId'],
      syncStatus: SyncStatus.values.firstWhere(
        (e) => e.name == map['syncStatus'],
        orElse: () => SyncStatus.synced,
      ),
    );
  }
}
