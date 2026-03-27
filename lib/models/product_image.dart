import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'product_image.g.dart';

@HiveType(typeId: 25)
enum ProductImageSource {
  @HiveField(0)
  localPath,
  @HiveField(1)
  networkUrl,
  @HiveField(2)
  memory,
  @HiveField(3)
  unknown,
}

@HiveType(typeId: 26)
class ProductImage {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final ProductImageSource sourceType;

  @HiveField(2)
  final String uri;

  @HiveField(3)
  final String? label;

  @HiveField(4)
  final int order;

  @HiveField(5)
  final String? colorTag;

  const ProductImage({
    required this.id,
    required this.sourceType,
    required this.uri,
    this.label,
    this.order = 0,
    this.colorTag,
  });

  factory ProductImage.local({
    required String path,
    String? label,
    int order = 0,
    String? colorTag,
  }) {
    return ProductImage(
      id: const Uuid().v4().substring(0, 8),
      sourceType: ProductImageSource.localPath,
      uri: path,
      label: label,
      order: order,
      colorTag: colorTag,
    );
  }

  factory ProductImage.network({
    required String url,
    String? label,
    int order = 0,
    String? colorTag,
  }) {
    return ProductImage(
      id: const Uuid().v4().substring(0, 8),
      sourceType: ProductImageSource.networkUrl,
      uri: url,
      label: label,
      order: order,
      colorTag: colorTag,
    );
  }

  ProductImage copyWith({
    String? id,
    ProductImageSource? sourceType,
    String? uri,
    String? label,
    int? order,
    String? colorTag,
  }) {
    return ProductImage(
      id: id ?? this.id,
      sourceType: sourceType ?? this.sourceType,
      uri: uri ?? this.uri,
      label: label ?? this.label,
      order: order ?? this.order,
      colorTag: colorTag ?? this.colorTag,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sourceType': sourceType.name,
      'uri': uri,
      'label': label,
      'order': order,
      'colorTag': colorTag,
    };
  }

  factory ProductImage.fromMap(Map<String, dynamic> map) {
    return ProductImage(
      id: map['id'] ?? '',
      sourceType: ProductImageSource.values.firstWhere(
        (e) => e.name == map['sourceType'],
        orElse: () => ProductImageSource.unknown,
      ),
      uri: map['uri'] ?? '',
      label: map['label'],
      order: map['order'] ?? 0,
      colorTag: map['colorTag'],
    );
  }
}
