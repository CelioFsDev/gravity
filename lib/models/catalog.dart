import 'package:cloud_firestore/cloud_firestore.dart';
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

  CatalogBanner({
    required this.id,
    required this.imagePath,
    this.title,
  });
}

enum CatalogMode { varejo, atacado }

extension CatalogModeExtension on CatalogMode {
  String get label => this == CatalogMode.atacado ? 'CATÁLOGO ATACADO' : 'CATÁLOGO VAREJO';
}

CatalogMode _catalogModeFromString(String? value) {
  if (value == null) return CatalogMode.varejo;
  return CatalogMode.values.firstWhere(
    (mode) => mode.name == value.toLowerCase(),
    orElse: () => CatalogMode.varejo,
  );
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
    );
  }

  Map<String, dynamic> toFirestoreMap() {
    return {
      'name': name,
      'slug': slug,
      'active': active,
      'productIds': productIds,
      'requireCustomerData': requireCustomerData,
      'photoLayout': photoLayout,
      'announcementEnabled': announcementEnabled,
      'announcementText': announcementText,
      'banners': banners
          .map((b) => {
                'id': b.id,
                'imagePath': b.imagePath,
                'title': b.title,
              })
          .toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'mode': mode.name,
      'isPublic': isPublic,
      'shareCode': shareCode,
      'ownerUid': ownerUid,
    };
  }

  factory Catalog.fromFirestore(String id, Map<String, dynamic> data) {
    List<CatalogBanner> mapBanners(dynamic raw) {
      if (raw is Iterable) {
        return raw.map((entry) {
          return CatalogBanner(
            id: entry['id']?.toString() ?? '',
            imagePath: entry['imagePath']?.toString() ?? '',
            title: entry['title']?.toString(),
          );
        }).toList();
      }
      return [];
    }

    DateTime extractDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      return DateTime.now();
    }

    return Catalog(
      id: id,
      name: data['name'] as String? ?? '',
      slug: data['slug'] as String? ?? '',
      active: data['active'] as bool? ?? true,
      productIds: (data['productIds'] as List<dynamic>?)
              ?.map((v) => v?.toString() ?? '')
              .where((element) => element.isNotEmpty)
              .toList() ??
          [],
      requireCustomerData: data['requireCustomerData'] as bool? ?? false,
      photoLayout: data['photoLayout'] as String? ?? 'grid',
      announcementEnabled: data['announcementEnabled'] as bool? ?? false,
      announcementText: data['announcementText'] as String?,
      banners: mapBanners(data['banners']),
      createdAt: extractDate(data['createdAt']),
      updatedAt: extractDate(data['updatedAt']),
      mode: _catalogModeFromString(data['mode'] as String?),
      isPublic: data['isPublic'] as bool? ?? false,
      shareCode: data['shareCode']?.toString() ?? '',
      ownerUid: data['ownerUid']?.toString() ?? '',
    );
  }
}
