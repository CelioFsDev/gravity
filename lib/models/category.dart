import 'package:hive/hive.dart';

part 'category.g.dart';

@HiveType(typeId: 7)
enum CategoryType {
  @HiveField(0)
  collection,
  @HiveField(1)
  productType,
}

@HiveType(typeId: 3)
class Category {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final int order;

  @HiveField(3)
  final DateTime createdAt;

  @HiveField(4)
  final DateTime updatedAt;

  @HiveField(5)
  final CategoryType type;

  Category({
    required this.id,
    required this.name,
    required this.order,
    required this.createdAt,
    required this.updatedAt,
    this.type = CategoryType.productType,
  });

  Category copyWith({
    String? id,
    String? name,
    int? order,
    DateTime? createdAt,
    DateTime? updatedAt,
    CategoryType? type,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      order: order ?? this.order,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      type: type ?? this.type,
    );
  }
}
