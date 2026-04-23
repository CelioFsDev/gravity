import 'package:uuid/uuid.dart';

class AuditLogEntry {
  final String id;
  final String tenantId;
  final String entityType; // e.g., 'product', 'catalog', 'category'
  final String entityId;
  final String action; // e.g., 'create', 'update_price', 'delete_image', 'publish'
  final String? userId;
  final String? userEmail;
  final DateTime timestamp;
  
  // Detalhes extras importantes para a operação (ex: "De R$ 10 para R$ 15")
  final Map<String, dynamic>? metadata;

  AuditLogEntry({
    String? id,
    required this.tenantId,
    required this.entityType,
    required this.entityId,
    required this.action,
    this.userId,
    this.userEmail,
    DateTime? timestamp,
    this.metadata,
  })  : id = id ?? const Uuid().v4(),
        timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tenantId': tenantId,
      'entityType': entityType,
      'entityId': entityId,
      'action': action,
      'userId': userId,
      'userEmail': userEmail,
      'timestamp': timestamp.toIso8601String(),
      'metadata': metadata,
    };
  }

  factory AuditLogEntry.fromMap(Map<String, dynamic> map) {
    return AuditLogEntry(
      id: map['id'] ?? '',
      tenantId: map['tenantId'] ?? '',
      entityType: map['entityType'] ?? '',
      entityId: map['entityId'] ?? '',
      action: map['action'] ?? '',
      userId: map['userId'],
      userEmail: map['userEmail'],
      timestamp: map['timestamp'] != null ? DateTime.parse(map['timestamp']) : null,
      metadata: map['metadata'] != null ? Map<String, dynamic>.from(map['metadata']) : null,
    );
  }
}
