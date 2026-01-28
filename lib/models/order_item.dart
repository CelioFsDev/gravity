import 'package:hive/hive.dart';

part 'order_item.g.dart';

@HiveType(typeId: 2)
class OrderItem {
  @HiveField(0)
  final String productName;

  @HiveField(1)
  final String productReference;

  @HiveField(2)
  final String? selectedSize;

  @HiveField(3)
  final int quantity;

  @HiveField(4)
  final double unitPrice;

  @HiveField(5)
  final double total; // unitPrice * quantity

  @HiveField(6)
  final String productId;

  OrderItem({
    required this.productId,
    required this.productName,
    required this.productReference,
    required this.selectedSize,
    required this.quantity,
    required this.unitPrice,
    required this.total,
  });

  OrderItem copyWith({
    String? productId,
    String? productName,
    String? productReference,
    String? selectedSize,
    int? quantity,
    double? unitPrice,
    double? total,
  }) {
    return OrderItem(
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      productReference: productReference ?? this.productReference,
      selectedSize: selectedSize ?? this.selectedSize,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      total: total ?? this.total,
    );
  }

  Map<String, dynamic> toFirestoreMap() {
    return {
      'productId': productId,
      'productName': productName,
      'productReference': productReference,
      'selectedSize': selectedSize,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'total': total,
    };
  }

  factory OrderItem.fromFirestore(Map<String, dynamic> data) {
    return OrderItem(
      productId: data['productId']?.toString() ?? '',
      productName: data['productName']?.toString() ?? '',
      productReference: data['productReference']?.toString() ?? '',
      selectedSize: data['selectedSize']?.toString(),
      quantity: (data['quantity'] as num?)?.toInt() ?? 0,
      unitPrice: (data['unitPrice'] as num?)?.toDouble() ?? 0.0,
      total: (data['total'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
