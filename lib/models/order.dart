import 'package:uuid/uuid.dart';

enum OrderStatus {
  pending,      // Novo pedido, aguardando aprovação/pagamento
  processing,   // Pagamento aprovado, separando no estoque
  ready,        // Separado, pronto para retirada ou envio
  shipped,      // Em trânsito para o cliente
  delivered,    // Entregue
  cancelled,    // Cancelado
}

class OrderItem {
  final String productId;
  final String productName;
  final String? sku;
  final int quantity;
  final double unitPrice;
  final Map<String, String>? attributes; // Cor, Tamanho, etc.
  final String? notes; // "Mandar com embalagem de presente"

  OrderItem({
    required this.productId,
    required this.productName,
    this.sku,
    required this.quantity,
    required this.unitPrice,
    this.attributes,
    this.notes,
  });

  double get totalPrice => quantity * unitPrice;

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'sku': sku,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'attributes': attributes,
      'notes': notes,
    };
  }

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      productId: map['productId'] ?? '',
      productName: map['productName'] ?? '',
      sku: map['sku'],
      quantity: map['quantity'] ?? 1,
      unitPrice: (map['unitPrice'] as num?)?.toDouble() ?? 0.0,
      attributes: map['attributes'] != null ? Map<String, String>.from(map['attributes']) : null,
      notes: map['notes'],
    );
  }
}

/// O Pedido fecha o ciclo entre a Vitrine Web (Carrinho de WhatsApp) 
/// e o App do Lojista (Gestão de status e separação).
class Order {
  final String id;
  final String tenantId;
  final String catalogId; // Origem da venda
  
  // CRM Leve
  final String? customerId; 
  final String customerName;
  final String customerPhone;
  
  final List<OrderItem> items;
  final OrderStatus status;
  final double discount;
  final double shippingCost;
  
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? sellerId; // Quem fechou/atendeu esse pedido

  Order({
    String? id,
    required this.tenantId,
    required this.catalogId,
    this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.items,
    this.status = OrderStatus.pending,
    this.discount = 0.0,
    this.shippingCost = 0.0,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.sellerId,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  double get subtotal => items.fold(0, (sum, item) => sum + item.totalPrice);
  double get totalAmount => (subtotal - discount) + shippingCost;

  Order copyWith({
    OrderStatus? status,
    double? discount,
    double? shippingCost,
    DateTime? updatedAt,
    String? sellerId,
  }) {
    return Order(
      id: id,
      tenantId: tenantId,
      catalogId: catalogId,
      customerId: customerId,
      customerName: customerName,
      customerPhone: customerPhone,
      items: items,
      status: status ?? this.status,
      discount: discount ?? this.discount,
      shippingCost: shippingCost ?? this.shippingCost,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      sellerId: sellerId ?? this.sellerId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tenantId': tenantId,
      'catalogId': catalogId,
      'customerId': customerId,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'items': items.map((x) => x.toMap()).toList(),
      'status': status.name,
      'discount': discount,
      'shippingCost': shippingCost,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'sellerId': sellerId,
    };
  }

  factory Order.fromMap(Map<String, dynamic> map) {
    return Order(
      id: map['id'] ?? '',
      tenantId: map['tenantId'] ?? '',
      catalogId: map['catalogId'] ?? '',
      customerId: map['customerId'],
      customerName: map['customerName'] ?? '',
      customerPhone: map['customerPhone'] ?? '',
      items: List<OrderItem>.from(map['items']?.map((x) => OrderItem.fromMap(x)) ?? []),
      status: OrderStatus.values.firstWhere((e) => e.name == map['status'], orElse: () => OrderStatus.pending),
      discount: (map['discount'] as num?)?.toDouble() ?? 0.0,
      shippingCost: (map['shippingCost'] as num?)?.toDouble() ?? 0.0,
      createdAt: map['createdAt'] != null ? DateTime.parse(map['createdAt']) : null,
      updatedAt: map['updatedAt'] != null ? DateTime.parse(map['updatedAt']) : null,
      sellerId: map['sellerId'],
    );
  }
}
