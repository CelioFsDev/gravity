// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'category.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CollectionCoverAdapter extends TypeAdapter<CollectionCover> {
  @override
  final int typeId = 10;

  @override
  CollectionCover read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CollectionCover(
      mode: fields[0] is CollectionCoverMode
          ? fields[0] as CollectionCoverMode
          : CollectionCoverMode.template,
      coverImagePath: fields[1]?.toString(),
      title: fields[2]?.toString(),
      brand: fields[3]?.toString(),
      subtitle: fields[4]?.toString(),
      backgroundColor: fields[5] is num ? (fields[5] as num).toInt() : null,
      overlayOpacity: fields[6] is num ? (fields[6] as num).toDouble() : null,
      bannerImagePath: fields[7]?.toString(),
      heroImagePath: fields[8]?.toString(),
      coverHeaderImagePath: fields[9]?.toString(),
      coverMainImagePath: fields[10]?.toString(),
      coverMiniPath: fields[11]?.toString(),
      coverPagePath: fields[12]?.toString(),
    );
  }

  @override
  void write(BinaryWriter writer, CollectionCover obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.mode)
      ..writeByte(1)
      ..write(obj.coverImagePath)
      ..writeByte(2)
      ..write(obj.title)
      ..writeByte(3)
      ..write(obj.brand)
      ..writeByte(4)
      ..write(obj.subtitle)
      ..writeByte(5)
      ..write(obj.backgroundColor)
      ..writeByte(6)
      ..write(obj.overlayOpacity)
      ..writeByte(7)
      ..write(obj.bannerImagePath)
      ..writeByte(8)
      ..write(obj.heroImagePath)
      ..writeByte(9)
      ..write(obj.coverHeaderImagePath)
      ..writeByte(10)
      ..write(obj.coverMainImagePath)
      ..writeByte(11)
      ..write(obj.coverMiniPath)
      ..writeByte(12)
      ..write(obj.coverPagePath);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CollectionCoverAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class CategoryAdapter extends TypeAdapter<Category> {
  @override
  final int typeId = 3;

  @override
  Category read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Category(
      id: fields[0]?.toString() ?? '',
      order: fields[2] is num ? (fields[2] as num).toInt() : 0,
      createdAt: fields[3] is DateTime ? fields[3] as DateTime : DateTime.now(),
      updatedAt: fields[4] is DateTime ? fields[4] as DateTime : DateTime.now(),
      type: fields[5] is CategoryType
          ? fields[5] as CategoryType
          : CategoryType.productType,
      cover: fields[6] is CollectionCover ? fields[6] as CollectionCover : null,
      isActive: fields[8] is bool ? fields[8] as bool : true,
      tenantId: fields[9]?.toString(),
      syncStatus: fields[10] is SyncStatus
          ? fields[10] as SyncStatus
          : SyncStatus.synced,
      name: fields[1]?.toString(),
      slug: fields[7]?.toString(),
    );
  }

  @override
  void write(BinaryWriter writer, Category obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.order)
      ..writeByte(3)
      ..write(obj.createdAt)
      ..writeByte(4)
      ..write(obj.updatedAt)
      ..writeByte(5)
      ..write(obj.type)
      ..writeByte(6)
      ..write(obj.cover)
      ..writeByte(7)
      ..write(obj.slug)
      ..writeByte(8)
      ..write(obj.isActive)
      ..writeByte(9)
      ..write(obj.tenantId)
      ..writeByte(10)
      ..write(obj.syncStatus);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CategoryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class CollectionCoverModeAdapter extends TypeAdapter<CollectionCoverMode> {
  @override
  final int typeId = 9;

  @override
  CollectionCoverMode read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return CollectionCoverMode.image;
      case 1:
        return CollectionCoverMode.template;
      default:
        return CollectionCoverMode.image;
    }
  }

  @override
  void write(BinaryWriter writer, CollectionCoverMode obj) {
    switch (obj) {
      case CollectionCoverMode.image:
        writer.writeByte(0);
        break;
      case CollectionCoverMode.template:
        writer.writeByte(1);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CollectionCoverModeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
