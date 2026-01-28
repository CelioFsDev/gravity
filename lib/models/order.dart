import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import 'package:gravity/models/order_status.dart';
import 'package:gravity/models/order_item.dart';

part 'order.g.dart';

@HiveType(typeId: 0)
class Order {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final double total;

  @HiveField(2)
  final OrderStatus status;

  @HiveField(3)
  final DateTime createdAt;

  @HiveField(4)
  final List<OrderItem> items;
  
  @HiveField(5)
  final String clientName;
  
  @HiveField(6)
  final String clientPhone;

  Order({
    required this.id,
    required this.total,
    required this.status,
    required this.createdAt,
    required this.items,
    required this.clientName,
    required this.clientPhone,
  });

  Order copyWith({
    String? id,
    double? total,
    OrderStatus? status,
    DateTime? createdAt,
    List<OrderItem>? items,
    String? clientName,
    String? clientPhone,
  }) {
    return Order(
      id: id ?? this.id,
      total: total ?? this.total,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      items: items ?? this.items,
      clientName: clientName ?? this.clientName,
      clientPhone: clientPhone ?? this.clientPhone,
    );
  }

  Map<String, dynamic> toFirestoreMap() {
    return {
      'total': total,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'items': items.map((i) => i.toFirestoreMap()).toList(),
      'clientName': clientName,
      'clientPhone': clientPhone,
    };
  }

  factory Order.fromFirestore(String id, Map<String, dynamic> data) {
    final status = data['status']?.toString();
    final parsedStatus = _orderStatusFromString(status);

    final createdAtValue = data['createdAt'];
    final createdAt = createdAtValue is Timestamp
        ? createdAtValue.toDate()
        : (createdAtValue is DateTime ? createdAtValue : DateTime.now());

    final itemsList = <OrderItem>[];
    final rawItems = data['items'];
    if (rawItems is Iterable) {
      for (final entry in rawItems) {
        if (entry is Map) {
          itemsList.add(OrderItem.fromFirestore(entry.cast<String, dynamic>()));
        }
      }
    }

    return Order(
      id: id,
      total: (data['total'] as num?)?.toDouble() ?? 0.0,
      status: parsedStatus,
      createdAt: createdAt,
      items: itemsList,
      clientName: data['clientName']?.toString() ?? '',
      clientPhone: data['clientPhone']?.toString() ?? '',
    );
  }
}

OrderStatus _orderStatusFromString(String? value) {
  return OrderStatus.values.firstWhere(
    (status) => status.name == value,
    orElse: () => OrderStatus.pending,
  );
}
