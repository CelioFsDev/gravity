import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:catalogo_ja/core/sync/models/sync_queue_item.dart';
import 'package:catalogo_ja/core/sync/handlers/sync_entity_handler.dart';
import 'package:catalogo_ja/core/sync/policies/sync_conflict_policy.dart';

/// Handler padrão (Fallback) que faz "set/delete JSON" no Firestore sem tratar arquivos extras.
/// Útil para 'category', 'catalog', 'audit_logs', etc.
class DefaultSyncHandler implements SyncEntityHandler {
  final String _entityType;
  final String _collectionName;
  final SyncConflictPolicy _conflictPolicy;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DefaultSyncHandler(this._entityType, this._collectionName, this._conflictPolicy);

  @override
  String get entityType => _entityType;

  @override
  Future<void> processItem(SyncQueueItem item) async {
    final docRef = _firestore.collection(_collectionName).doc(item.entityId);

    if (item.operation == SyncOperation.delete) {
      await docRef.delete();
      return;
    }

    if (item.payload == null) {
      throw Exception('Missing payload for operation ${item.operation}');
    }

    if (item.operation == SyncOperation.update) {
      final snapshot = await docRef.get(const GetOptions(source: Source.server));
      final remoteData = snapshot.exists ? snapshot.data() : null;

      final localWins = await _conflictPolicy.resolveConflict(
        localItem: item,
        remoteData: remoteData,
      );

      if (!localWins) {
        item.status = SyncItemStatus.conflict;
        item.errorMessage = 'Conflict detected: Server has newer version.';
        throw Exception(item.errorMessage);
      }
    }

    final payload = Map<String, dynamic>.from(item.payload!);
    payload['tenantId'] = item.tenantId;

    if (item.operation == SyncOperation.create) {
      await docRef.set(payload);
    } else if (item.operation == SyncOperation.update) {
      await docRef.set(payload, SetOptions(merge: true));
    }
  }
}
