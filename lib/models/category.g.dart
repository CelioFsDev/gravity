// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'category.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

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
        return CollectionCoverMode.template;
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
      mode: fields[0] as CollectionCoverMode,
      coverImagePath: fields[1] as String?,
      title: fields[2] as String?,
      brand: fields[3] as String?,
      subtitle: fields[4] as String?,
      backgroundColor: fields[5] as int?,
      overlayOpacity: fields[6] as double?,
      bannerImagePath: fields[7] as String?,
      heroImagePath: fields[8] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, CollectionCover obj) {
    writer
      ..writeByte(9)
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
      ..write(obj.heroImagePath);
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
      id: fields[0] as String,
      name: fields[1] as String,
      order: fields[2] as int,
      createdAt: fields[3] as DateTime,
      updatedAt: fields[4] as DateTime,
      type: fields[5] as CategoryType,
      cover: fields[6] as CollectionCover?,
    );
  }

  @override
  void write(BinaryWriter writer, Category obj) {
    writer
      ..writeByte(7)
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
      ..write(obj.cover);
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
