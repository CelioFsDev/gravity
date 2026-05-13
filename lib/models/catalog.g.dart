// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'catalog.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CatalogBannerAdapter extends TypeAdapter<CatalogBanner> {
  @override
  final int typeId = 5;

  @override
  CatalogBanner read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CatalogBanner(
      id: fields[0]?.toString() ?? '',
      imagePath: fields[1]?.toString() ?? '',
      title: fields[2]?.toString(),
    );
  }

  @override
  void write(BinaryWriter writer, CatalogBanner obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.imagePath)
      ..writeByte(2)
      ..write(obj.title);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CatalogBannerAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class CatalogAdapter extends TypeAdapter<Catalog> {
  @override
  final int typeId = 6;

  @override
  Catalog read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Catalog(
      id: fields[0]?.toString() ?? '',
      name: fields[1]?.toString() ?? '',
      slug: fields[2]?.toString() ?? '',
      active: fields[3] is bool ? fields[3] as bool : true,
      productIds:
          (fields[4] as List?)?.map((e) => e.toString()).toList() ??
          <String>[],
      requireCustomerData: fields[5] is bool ? fields[5] as bool : false,
      photoLayout: fields[6]?.toString() ?? 'grid',
      announcementEnabled: fields[7] is bool ? fields[7] as bool : false,
      announcementText: fields[8]?.toString(),
      banners:
          (fields[9] as List?)
              ?.where((e) => e is CatalogBanner || e is Map)
              .map<CatalogBanner>((e) {
                if (e is CatalogBanner) return e;
                return CatalogBanner.fromMap(Map<String, dynamic>.from(e as Map));
              })
              .toList() ??
          <CatalogBanner>[],
      createdAt: fields[10] is DateTime ? fields[10] as DateTime : DateTime.now(),
      updatedAt: fields[11] is DateTime ? fields[11] as DateTime : DateTime.now(),
      mode: fields[12] is CatalogMode ? fields[12] as CatalogMode : CatalogMode.varejo,
      isPublic: fields[13] is bool ? fields[13] as bool : false,
      shareCode: fields[14]?.toString() ?? '',
      ownerUid: fields[15]?.toString() ?? '',
      includeCover: fields[16] is bool ? fields[16] as bool : true,
      coverType: fields[17]?.toString(),
      tenantId: fields[18]?.toString(),
      syncStatus: fields[19] is SyncStatus
          ? fields[19] as SyncStatus
          : SyncStatus.synced,
    );
  }

  @override
  void write(BinaryWriter writer, Catalog obj) {
    writer
      ..writeByte(20)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.slug)
      ..writeByte(3)
      ..write(obj.active)
      ..writeByte(4)
      ..write(obj.productIds)
      ..writeByte(5)
      ..write(obj.requireCustomerData)
      ..writeByte(6)
      ..write(obj.photoLayout)
      ..writeByte(7)
      ..write(obj.announcementEnabled)
      ..writeByte(8)
      ..write(obj.announcementText)
      ..writeByte(9)
      ..write(obj.banners)
      ..writeByte(10)
      ..write(obj.createdAt)
      ..writeByte(11)
      ..write(obj.updatedAt)
      ..writeByte(12)
      ..write(obj.mode)
      ..writeByte(13)
      ..write(obj.isPublic)
      ..writeByte(14)
      ..write(obj.shareCode)
      ..writeByte(15)
      ..write(obj.ownerUid)
      ..writeByte(16)
      ..write(obj.includeCover)
      ..writeByte(17)
      ..write(obj.coverType)
      ..writeByte(18)
      ..write(obj.tenantId)
      ..writeByte(19)
      ..write(obj.syncStatus);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CatalogAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class CatalogModeAdapter extends TypeAdapter<CatalogMode> {
  @override
  final int typeId = 21;

  @override
  CatalogMode read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return CatalogMode.varejo;
      case 1:
        return CatalogMode.atacado;
      default:
        return CatalogMode.varejo;
    }
  }

  @override
  void write(BinaryWriter writer, CatalogMode obj) {
    switch (obj) {
      case CatalogMode.varejo:
        writer.writeByte(0);
        break;
      case CatalogMode.atacado:
        writer.writeByte(1);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CatalogModeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
