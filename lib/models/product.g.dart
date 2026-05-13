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
      path: fields[0]?.toString() ?? '',
      colorKey: fields[1]?.toString(),
      isPrimary: fields[2] is bool ? fields[2] as bool : false,
      photoType: fields[3]?.toString(),
      id: fields[4]?.toString(),
      url: fields[5]?.toString() ?? '',
    );
  }

  @override
  void write(BinaryWriter writer, ProductPhoto obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.path)
      ..writeByte(1)
      ..write(obj.colorKey)
      ..writeByte(2)
      ..write(obj.isPrimary)
      ..writeByte(3)
      ..write(obj.photoType)
      ..writeByte(4)
      ..write(obj.id)
      ..writeByte(5)
      ..write(obj.url);
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
      id: fields[0]?.toString() ?? '',
      name: fields[1]?.toString() ?? '',
      ref: fields[2]?.toString() ?? '',
      sku: fields[3]?.toString() ?? '',
      categoryIds:
          (fields[17] as List?)?.map((e) => e.toString()).toList() ??
          <String>[],
      priceRetail: fields[5] is num ? (fields[5] as num).toDouble() : 0,
      priceWholesale: fields[6] is num ? (fields[6] as num).toDouble() : 0,
      minWholesaleQty: fields[7] is num ? (fields[7] as num).toInt() : 1,
      sizes:
          (fields[8] as List?)?.map((e) => e.toString()).toList() ?? <String>[],
      colors:
          (fields[9] as List?)?.map((e) => e.toString()).toList() ?? <String>[],
      images:
          (fields[10] as List?)
              ?.where((e) => e is ProductImage || e is Map || e is String)
              .map<ProductImage>((e) {
                if (e is ProductImage) return e;
                if (e is Map) return ProductImage.fromMap(Map<String, dynamic>.from(e));
                return ProductImage.network(url: e.toString());
              })
              .toList() ??
          <ProductImage>[],
      mainImageIndex: fields[11] is num ? (fields[11] as num).toInt() : 0,
      isActive: fields[12] is bool ? fields[12] as bool : true,
      isOutOfStock: fields[13] is bool ? fields[13] as bool : false,
      promoEnabled: fields[14] is bool ? fields[14] as bool : false,
      createdAt: fields[15] is DateTime ? fields[15] as DateTime : DateTime.now(),
      photos:
          (fields[24] as List?)
              ?.where((e) => e is ProductPhoto || e is Map || e is String)
              .map<ProductPhoto>((e) {
                if (e is ProductPhoto) return e;
                if (e is Map) {
                  final map = Map<String, dynamic>.from(e);
                  return ProductPhoto(
                    path: (map['path'] ?? map['url'] ?? '').toString(),
                    colorKey: map['colorKey']?.toString(),
                    isPrimary: map['isPrimary'] is bool
                        ? map['isPrimary'] as bool
                        : false,
                    photoType: map['photoType']?.toString(),
                    id: map['id']?.toString(),
                    url: map['url']?.toString() ?? '',
                  );
                }
                return ProductPhoto(path: e.toString());
              })
              .toList() ??
          <ProductPhoto>[],
      promoPercent: fields[16] is num ? (fields[16] as num).toDouble() : 0,
      slug: fields[18]?.toString() ?? '',
      description: fields[19]?.toString(),
      tags:
          (fields[20] as List?)?.map((e) => e.toString()).toList() ??
          <String>[],
      remoteImages:
          (fields[21] as List?)?.map((e) => e.toString()).toList() ??
          <String>[],
      variants:
          (fields[22] as List?)
              ?.where((e) => e is ProductVariant || e is Map)
              .map<ProductVariant>((e) {
                if (e is ProductVariant) return e;
                return ProductVariant.fromMap(Map<String, dynamic>.from(e as Map));
              })
              .toList() ??
          <ProductVariant>[],
      tenantId: fields[25]?.toString(),
      storeOverrides: (fields[26] as Map?)
              ?.map(
                (dynamic k, dynamic v) => MapEntry(
                  k.toString(),
                  v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{},
                ),
              ) ??
          <String, Map<String, dynamic>>{},
      syncStatus: fields[27] is SyncStatus
          ? fields[27] as SyncStatus
          : SyncStatus.synced,
      updatedAt: fields[23] is DateTime ? fields[23] as DateTime : null,
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
