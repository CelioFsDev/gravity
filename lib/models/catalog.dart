import 'package:hive/hive.dart';
import 'package:catalogo_ja/core/utils/safe_parse.dart';
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
    return {'id': id, 'imagePath': imagePath, 'title': title};
  }

  factory CatalogBanner.fromMap(Map<String, dynamic> map) {
    return CatalogBanner(
      id: safeString(map['id']),
      imagePath: safeString(map['imagePath']),
      title: safeNullableString(map['title']),
    );
  }

  CatalogBanner copyWith({String? id, String? imagePath, String? title}) {
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
  String get label => this == CatalogMode.atacado
      ? 'CAT\u00c1LOGO ATACADO'
      : 'CAT\u00c1LOGO VAREJO';
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

    CatalogMode parseMode(dynamic value) {
      if (value is CatalogMode) return value;
      final index = value is int ? value : int.tryParse(safeString(value));
      if (index != null && index >= 0 && index < CatalogMode.values.length) {
        return CatalogMode.values[index];
      }
      final name = safeString(value).trim();
      if (name.isNotEmpty) {
        return CatalogMode.values.firstWhere(
          (e) => e.name == name,
          orElse: () => CatalogMode.varejo,
        );
      }
      return CatalogMode.varejo;
    }

    List<Map<String, dynamic>> parseMapList(dynamic value) {
      if (value is! List) return const [];
      return value.where((item) => item is CatalogBanner || item is Map).map((
        item,
      ) {
        if (item is CatalogBanner) return item.toMap();
        return safeMap(item);
      }).toList();
    }

    return Catalog(
      id: safeString(map['id']),
      name: safeString(map['name']),
      slug: safeString(map['slug']),
      active: safeBool(map['active'], fallback: true),
      productIds: safeStringList(map['productIds']),
      requireCustomerData: safeBool(
        map['requireCustomerData'],
        fallback: false,
      ),
      photoLayout: safeString(map['photoLayout'], fallback: 'grid'),
      announcementEnabled: safeBool(
        map['announcementEnabled'],
        fallback: false,
      ),
      announcementText: safeNullableString(map['announcementText']),
      banners: parseMapList(
        map['banners'],
      ).map<CatalogBanner>((b) => CatalogBanner.fromMap(b)).toList(),
      createdAt: safeDateTime(map['createdAt']),
      updatedAt: safeDateTime(map['updatedAt']),
      mode: parseMode(map['mode']),
      isPublic: safeBool(map['isPublic'], fallback: false),
      shareCode: safeString(map['shareCode']),
      ownerUid: safeString(map['ownerUid']),
      includeCover: safeBool(map['includeCover'], fallback: true),
      coverType: safeNullableString(map['coverType']),
      tenantId: safeNullableString(map['tenantId']),
      syncStatus: parseSyncStatus(map['syncStatus']),
    );
  }
}
