import 'package:hive/hive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
      id: map['id']?.toString() ?? '',
      imagePath: map['imagePath']?.toString() ?? '',
      title: map['title']?.toString(),
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
    DateTime parseDate(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is DateTime) return value;
      if (value is Timestamp) return value.toDate();
      try {
        if (value.runtimeType.toString().contains('Timestamp')) {
          final dynamic timestamp = value;
          final converted = timestamp.toDate();
          if (converted is DateTime) return converted;
        }
      } catch (_) {}
      if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
      return DateTime.now();
    }

    List<String> parseStringList(dynamic value) {
      if (value is String && value.trim().isNotEmpty) return [value.trim()];
      if (value is! List) return const [];
      return value
          .where((item) => item != null)
          .map((item) => item.toString())
          .where((item) => item.isNotEmpty)
          .toList();
    }

    bool parseBool(dynamic value, bool fallback) {
      if (value is bool) return value;
      if (value is num) return value != 0;
      if (value is String) return value.toLowerCase() == 'true';
      return fallback;
    }

    SyncStatus parseSyncStatus(dynamic value) {
      if (value is int && value >= 0 && value < SyncStatus.values.length) {
        return SyncStatus.values[value];
      }
      if (value is String) {
        return SyncStatus.values.firstWhere(
          (status) => status.name == value,
          orElse: () => SyncStatus.synced,
        );
      }
      return SyncStatus.synced;
    }

    CatalogMode parseMode(dynamic value) {
      if (value is String) {
        return CatalogMode.values.firstWhere(
          (e) => e.name == value,
          orElse: () => CatalogMode.varejo,
        );
      }
      if (value is int && value >= 0 && value < CatalogMode.values.length) {
        return CatalogMode.values[value];
      }
      return CatalogMode.varejo;
    }

    List<Map<String, dynamic>> parseMapList(dynamic value) {
      if (value is! List) return const [];
      return value
          .whereType<Map>()
          .map((item) => item.map((key, val) => MapEntry(key.toString(), val)))
          .toList();
    }

    return Catalog(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      slug: map['slug']?.toString() ?? '',
      active: parseBool(map['active'], true),
      productIds: parseStringList(map['productIds']),
      requireCustomerData: parseBool(map['requireCustomerData'], false),
      photoLayout: map['photoLayout']?.toString() ?? 'grid',
      announcementEnabled: parseBool(map['announcementEnabled'], false),
      announcementText: map['announcementText']?.toString(),
      banners: parseMapList(map['banners'])
          .map<CatalogBanner>((b) => CatalogBanner.fromMap(b))
          .toList(),
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
      mode: parseMode(map['mode']),
      isPublic: parseBool(map['isPublic'], false),
      shareCode: map['shareCode']?.toString() ?? '',
      ownerUid: map['ownerUid']?.toString() ?? '',
      includeCover: parseBool(map['includeCover'], true),
      coverType: map['coverType']?.toString(),
      tenantId: map['tenantId']?.toString(),
      syncStatus: parseSyncStatus(map['syncStatus']),
    );
  }
}
