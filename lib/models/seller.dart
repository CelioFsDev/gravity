import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';

part 'seller.g.dart';

@HiveType(typeId: 7)
class Seller {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String whatsapp;

  @HiveField(3)
  final bool isActive;

  @HiveField(4)
  final DateTime createdAt;

  Seller({
    required this.id,
    required this.name,
    required this.whatsapp,
    required this.isActive,
    required this.createdAt,
  });

  Seller copyWith({
    String? id,
    String? name,
    String? whatsapp,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return Seller(
      id: id ?? this.id,
      name: name ?? this.name,
      whatsapp: whatsapp ?? this.whatsapp,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toFirestoreMap() {
    return {
      'name': name,
      'whatsapp': whatsapp,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory Seller.fromFirestore(String id, Map<String, dynamic> data) {
    final createdAtValue = data['createdAt'];
    final createdAt = createdAtValue is Timestamp
        ? createdAtValue.toDate()
        : (createdAtValue is DateTime ? createdAtValue : DateTime.now());

    return Seller(
      id: id,
      name: data['name']?.toString() ?? '',
      whatsapp: data['whatsapp']?.toString() ?? '',
      isActive: data['isActive'] as bool? ?? true,
      createdAt: createdAt,
    );
  }
}
