// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product_variant.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ProductVariantAdapter extends TypeAdapter<ProductVariant> {
  @override
  final int typeId = 8;

  @override
  ProductVariant read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ProductVariant(
      sku: fields[0] as String,
      stock: fields[1] as int,
      attributes: (fields[2] as Map).cast<String, String>(),
    );
  }

  @override
  void write(BinaryWriter writer, ProductVariant obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.sku)
      ..writeByte(1)
      ..write(obj.stock)
      ..writeByte(2)
      ..write(obj.attributes);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProductVariantAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
