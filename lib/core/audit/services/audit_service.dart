import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:catalogo_ja/core/audit/models/audit_log_entry.dart';
import 'package:catalogo_ja/core/sync/models/sync_queue_item.dart';
import 'package:catalogo_ja/core/sync/repositories/sync_queue_repository.dart';
import 'package:catalogo_ja/core/sync/providers/sync_providers.dart';
import 'package:catalogo_ja/viewmodels/auth_viewmodel.dart';
import 'package:catalogo_ja/viewmodels/tenant_viewmodel.dart';

class AuditService {
  final SyncQueueRepository _syncQueue;
  final String? _userId;
  final String? _userEmail;
  final String? _tenantId;

  AuditService(
    this._syncQueue,
    this._userId,
    this._userEmail,
    this._tenantId,
  );

  /// Registra uma ação de auditoria usando a própria Fila de Sincronização offline-first
  Future<void> logAction({
    required String entityType,
    required String entityId,
    required String action,
    Map<String, dynamic>? metadata,
  }) async {
    if (_tenantId == null) return;

    final entry = AuditLogEntry(
      tenantId: _tenantId!,
      entityType: entityType,
      entityId: entityId,
      action: action,
      userId: _userId,
      userEmail: _userEmail,
      metadata: metadata,
    );

    // Salvar num Hive Box específico de auditoria local (opcional)
    // Para simplificar a arquitetura inicial, já enfileiramos direto pro Firebase.
    // Assim, se o dev estiver offline, isso sobe assim que a internet voltar 
    // junto com a entidade que foi modificada.
    await _syncQueue.enqueue(SyncQueueItem(
      tenantId: _tenantId!,
      entityType: 'audit_log', // A coleção no Firestore será 'audit_logs'
      entityId: entry.id,
      operation: SyncOperation.create, // Auditoria é sempre create (append-only)
      payload: entry.toMap(),
    ));
  }
}

// Provedor Global do Serviço de Auditoria
final auditServiceProvider = Provider<AuditService>((ref) {
  final user = ref.watch(authViewModelProvider).valueOrNull;
  final tenantAsync = ref.watch(currentTenantProvider);
  final syncQueue = ref.watch(syncQueueRepositoryProvider);

  return AuditService(
    syncQueue,
    user?.uid,
    user?.email,
    tenantAsync.valueOrNull?.id,
  );
});
