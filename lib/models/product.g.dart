// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ProductAdapter extends TypeAdapter<Product> {
  @override
  final int typeId = 4;

  @override
  Product read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    final legacyCategoryId = fields[4] as String?;
    final categoryIds =
        (fields[17] as List?)?.cast<String>() ?? <String>[];
    final resolvedCategoryIds = categoryIds.isNotEmpty
        ? categoryIds
        : (legacyCategoryId != null && legacyCategoryId.isNotEmpty)
            ? <String>[legacyCategoryId]
            : <String>[];
    return Product(
      id: fields[0] as String,
      name: fields[1] as String,
      reference: fields[2] as String,
      sku: fields[3] as String,
      categoryIds: resolvedCategoryIds,
      priceVarejo: fields[5] as double,
      priceAtacado: fields[6] as double,
      minWholesaleQty: fields[7] as int,
      sizes: (fields[8] as List).cast<String>(),
      colors: (fields[9] as List).cast<String>(),
      images: (fields[10] as List).cast<String>(),
      mainImageIndex: fields[11] as int,
      isActive: fields[12] as bool,
      isOutOfStock: fields[13] as bool,
      isOnSale: fields[14] as bool,
      createdAt: fields[15] as DateTime,
      saleDiscountPercent: fields[16] as int,
    );
  }

  @override
  void write(BinaryWriter writer, Product obj) {
    final primaryCategoryId =
        obj.categoryIds.isNotEmpty ? obj.categoryIds.first : '';
    writer
      ..writeByte(18)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.reference)
      ..writeByte(3)
      ..write(obj.sku)
      ..writeByte(4)
      ..write(primaryCategoryId)
      ..writeByte(5)
      ..write(obj.priceVarejo)
      ..writeByte(6)
      ..write(obj.priceAtacado)
      ..writeByte(7)
      ..write(obj.minWholesaleQty)
      ..writeByte(8)
      ..write(obj.sizes)
      ..writeByte(9)
      ..write(obj.colors)
      ..writeByte(10)
      ..write(obj.images)
      ..writeByte(11)
      ..write(obj.mainImageIndex)
      ..writeByte(12)
      ..write(obj.isActive)
      ..writeByte(13)
      ..write(obj.isOutOfStock)
      ..writeByte(14)
      ..write(obj.isOnSale)
      ..writeByte(15)
      ..write(obj.createdAt)
      ..writeByte(16)
      ..write(obj.saleDiscountPercent)
      ..writeByte(17)
      ..write(obj.categoryIds);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProductAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
