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
}
