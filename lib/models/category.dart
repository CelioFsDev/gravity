import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';

part 'category.g.dart';

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

  Category({
    required this.id,
    required this.name,
    required this.order,
    required this.createdAt,
    required this.updatedAt,
  });

  Category copyWith({
    String? id,
    String? name,
    int? order,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      order: order ?? this.order,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toFirestoreMap() {
    return {
      'name': name,
      'order': order,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory Category.fromFirestore(String id, Map<String, dynamic> data) {
    final createdAtValue = data['createdAt'];
    final updatedAtValue = data['updatedAt'];

    DateTime _extractDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      return DateTime.now();
    }

    final created = _extractDate(createdAtValue);
    final updated = _extractDate(updatedAtValue);

    return Category(
      id: id,
      name: data['name'] as String? ?? '',
      order: (data['order'] as int?) ?? 0,
      createdAt: created,
      updatedAt: updated,
    );
  }
}
