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
      id: fields[0] as String,
      imagePath: fields[1] as String,
      title: fields[2] as String?,
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
      id: fields[0] as String,
      name: fields[1] as String,
      slug: fields[2] as String,
      active: fields[3] as bool,
      productIds: (fields[4] as List).cast<String>(),
      requireCustomerData: fields[5] as bool,
      photoLayout: fields[6] as String,
      announcementEnabled: fields[7] as bool,
      announcementText: fields[8] as String?,
      banners: (fields[9] as List).cast<CatalogBanner>(),
      createdAt: fields[10] as DateTime,
      updatedAt: fields[11] as DateTime,
      mode: fields[12] as CatalogMode,
      isPublic: fields[13] as bool,
      shareCode: fields[14] as String,
      ownerUid: fields[15] as String,
      includeCover: fields[16] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, Catalog obj) {
    writer
      ..writeByte(17)
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
      ..write(obj.includeCover);
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
