import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

enum SyncOperation {
  create,
  update,
  delete,
}

enum SyncItemStatus {
  pending,
  syncing,
  synced,
  error,
  conflict,
}

class SyncQueueItem {
  final String id;
  final String tenantId;
  final String entityType; // e.g. 'product', 'category'
  final String entityId;
  final SyncOperation operation;
  
  Map<String, dynamic>? payload;
  SyncItemStatus status;
  
  int retryCount;
  DateTime? lastAttemptAt;
  DateTime? nextRetryAt;
  String? errorMessage;
  
  final String? deviceId;
  final DateTime createdAt;
  DateTime updatedAt;
  
  // Para resolução de conflitos: qual era a data original no server antes dessa operação
  DateTime? baseVersion;

  SyncQueueItem({
    String? id,
    required this.tenantId,
    required this.entityType,
    required this.entityId,
    required this.operation,
    this.payload,
    this.status = SyncItemStatus.pending,
    this.retryCount = 0,
    this.lastAttemptAt,
    this.nextRetryAt,
    this.errorMessage,
    this.deviceId,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.baseVersion,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  SyncQueueItem copyWith({
    String? id,
    String? tenantId,
    String? entityType,
    String? entityId,
    SyncOperation? operation,
    Map<String, dynamic>? payload,
    SyncItemStatus? status,
    int? retryCount,
    DateTime? lastAttemptAt,
    DateTime? nextRetryAt,
    String? errorMessage,
    String? deviceId,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? baseVersion,
  }) {
    return SyncQueueItem(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      operation: operation ?? this.operation,
      payload: payload ?? this.payload,
      status: status ?? this.status,
      retryCount: retryCount ?? this.retryCount,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      nextRetryAt: nextRetryAt ?? this.nextRetryAt,
      errorMessage: errorMessage ?? this.errorMessage,
      deviceId: deviceId ?? this.deviceId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      baseVersion: baseVersion ?? this.baseVersion,
    );
  }
}

// Manual Adapter para garantir que o Hive funcione sem quebrar o build_runner
class SyncQueueItemAdapter extends TypeAdapter<SyncQueueItem> {
  @override
  final int typeId = 40;

  @override
  SyncQueueItem read(BinaryReader reader) {
    return SyncQueueItem(
      id: reader.read() as String,
      tenantId: reader.read() as String,
      entityType: reader.read() as String,
      entityId: reader.read() as String,
      operation: SyncOperation.values[reader.read() as int],
      payload: (reader.read() as Map?)?.cast<String, dynamic>(),
      status: SyncItemStatus.values[reader.read() as int],
      retryCount: reader.read() as int,
      lastAttemptAt: reader.read() as DateTime?,
      nextRetryAt: reader.read() as DateTime?,
      errorMessage: reader.read() as String?,
      deviceId: reader.read() as String?,
      createdAt: reader.read() as DateTime,
      updatedAt: reader.read() as DateTime,
      baseVersion: reader.read() as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, SyncQueueItem obj) {
    writer.write(obj.id);
    writer.write(obj.tenantId);
    writer.write(obj.entityType);
    writer.write(obj.entityId);
    writer.write(obj.operation.index);
    writer.write(obj.payload);
    writer.write(obj.status.index);
    writer.write(obj.retryCount);
    writer.write(obj.lastAttemptAt);
    writer.write(obj.nextRetryAt);
    writer.write(obj.errorMessage);
    writer.write(obj.deviceId);
    writer.write(obj.createdAt);
    writer.write(obj.updatedAt);
    writer.write(obj.baseVersion);
  }
}
