// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product_image.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ProductImageAdapter extends TypeAdapter<ProductImage> {
  @override
  final int typeId = 26;

  @override
  ProductImage read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ProductImage(
      id: fields[0]?.toString() ?? '',
      sourceType: fields[1] is ProductImageSource
          ? fields[1] as ProductImageSource
          : ProductImageSource.unknown,
      uri: fields[2]?.toString() ?? '',
      label: fields[3]?.toString(),
      order: fields[4] is num ? (fields[4] as num).toInt() : 0,
      colorTag: fields[5]?.toString(),
    );
  }

  @override
  void write(BinaryWriter writer, ProductImage obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.sourceType)
      ..writeByte(2)
      ..write(obj.uri)
      ..writeByte(3)
      ..write(obj.label)
      ..writeByte(4)
      ..write(obj.order)
      ..writeByte(5)
      ..write(obj.colorTag);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProductImageAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ProductImageSourceAdapter extends TypeAdapter<ProductImageSource> {
  @override
  final int typeId = 25;

  @override
  ProductImageSource read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return ProductImageSource.localPath;
      case 1:
        return ProductImageSource.networkUrl;
      case 2:
        return ProductImageSource.memory;
      case 3:
        return ProductImageSource.unknown;
      case 4:
        return ProductImageSource.storage;
      default:
        return ProductImageSource.localPath;
    }
  }

  @override
  void write(BinaryWriter writer, ProductImageSource obj) {
    switch (obj) {
      case ProductImageSource.localPath:
        writer.writeByte(0);
        break;
      case ProductImageSource.networkUrl:
        writer.writeByte(1);
        break;
      case ProductImageSource.memory:
        writer.writeByte(2);
        break;
      case ProductImageSource.unknown:
        writer.writeByte(3);
        break;
      case ProductImageSource.storage:
        writer.writeByte(4);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProductImageSourceAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
