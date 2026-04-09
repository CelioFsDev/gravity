// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ProductPhotoAdapter extends TypeAdapter<ProductPhoto> {
  @override
  final int typeId = 11;

  @override
  ProductPhoto read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ProductPhoto(
      path: fields[0] as String,
      colorKey: fields[1] as String?,
      isPrimary: fields[2] as bool,
      photoType: fields[3] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, ProductPhoto obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.path)
      ..writeByte(1)
      ..write(obj.colorKey)
      ..writeByte(2)
      ..write(obj.isPrimary)
      ..writeByte(3)
      ..write(obj.photoType);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProductPhotoAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ProductAdapter extends TypeAdapter<Product> {
  @override
  final int typeId = 4;

  @override
  Product read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Product(
      id: fields[0] as String,
      name: fields[1] as String,
      ref: fields[2] as String,
      sku: fields[3] as String,
      categoryIds: (fields[17] as List).cast<String>(),
      priceRetail: fields[5] as double,
      priceWholesale: fields[6] as double,
      minWholesaleQty: fields[7] as int,
      sizes: (fields[8] as List).cast<String>(),
      colors: (fields[9] as List).cast<String>(),
      images: (fields[10] as List).cast<ProductImage>(),
      mainImageIndex: fields[11] as int,
      isActive: fields[12] as bool,
      isOutOfStock: fields[13] as bool,
      promoEnabled: fields[14] as bool,
      createdAt: fields[15] as DateTime,
      photos: (fields[24] as List).cast<ProductPhoto>(),
      promoPercent: fields[16] as double,
      slug: fields[18] as String,
      description: fields[19] as String?,
      tags: (fields[20] as List).cast<String>(),
      remoteImages: (fields[21] as List).cast<String>(),
      variants: (fields[22] as List).cast<ProductVariant>(),
      tenantId: fields[25] as String?,
      storeOverrides: (fields[26] as Map).map((dynamic k, dynamic v) =>
          MapEntry(k as String, (v as Map).cast<String, dynamic>())),
      syncStatus: fields[27] as SyncStatus,
      updatedAt: fields[23] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, Product obj) {
    writer
      ..writeByte(27)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.ref)
      ..writeByte(3)
      ..write(obj.sku)
      ..writeByte(17)
      ..write(obj.categoryIds)
      ..writeByte(5)
      ..write(obj.priceRetail)
      ..writeByte(6)
      ..write(obj.priceWholesale)
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
      ..write(obj.promoEnabled)
      ..writeByte(15)
      ..write(obj.createdAt)
      ..writeByte(16)
      ..write(obj.promoPercent)
      ..writeByte(18)
      ..write(obj.slug)
      ..writeByte(19)
      ..write(obj.description)
      ..writeByte(20)
      ..write(obj.tags)
      ..writeByte(21)
      ..write(obj.remoteImages)
      ..writeByte(22)
      ..write(obj.variants)
      ..writeByte(23)
      ..write(obj.updatedAt)
      ..writeByte(24)
      ..write(obj.photos)
      ..writeByte(25)
      ..write(obj.tenantId)
      ..writeByte(26)
      ..write(obj.storeOverrides)
      ..writeByte(27)
      ..write(obj.syncStatus);
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
