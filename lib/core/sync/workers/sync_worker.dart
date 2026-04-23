import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:catalogo_ja/core/sync/models/sync_queue_item.dart';
import 'package:catalogo_ja/core/sync/repositories/sync_queue_repository.dart';
import 'package:catalogo_ja/core/sync/policies/sync_conflict_policy.dart';

class SyncWorker {
  final SyncQueueRepository _queueRepo;
  final SyncConflictPolicy _conflictPolicy;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isProcessing = false;

  SyncWorker(this._queueRepo, this._conflictPolicy);

  Future<void> processQueue() async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      final itemsToSync = _queueRepo.getPendingOrErrorItems();
      if (itemsToSync.isEmpty) return;

      for (final item in itemsToSync) {
        if (item.status == SyncItemStatus.conflict) continue; // Conflito precisa de interacao ou politica forçada

        item.status = SyncItemStatus.syncing;
        item.lastAttemptAt = DateTime.now();
        item.retryCount += 1;
        await _queueRepo.updateItem(item);

        try {
          await _processSingleItem(item);
          // Sucesso
          item.status = SyncItemStatus.synced;
          item.errorMessage = null;
          await _queueRepo.updateItem(item);
        } catch (e) {
          // Trata Erro e faz o Backoff
          _handleError(item, e);
          await _queueRepo.updateItem(item);
        }
      }
    } finally {
      _isProcessing = false;
      // Podemos agendar uma limpeza da fila de sucesso
      await _queueRepo.clearSuccessfullySynced();
    }
  }

  Future<void> _processSingleItem(SyncQueueItem item) async {
    final collectionName = _getCollectionNameForEntity(item.entityType);
    final docRef = _firestore.collection(collectionName).doc(item.entityId);

    if (item.operation == SyncOperation.delete) {
      await docRef.delete();
      return;
    }

    if (item.payload == null) {
      throw Exception('Missing payload for operation ${item.operation}');
    }

    final payload = item.payload!;

    // Resolvendo conectividade/conflito
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

    // Gravação segura
    // Injeção forçada do tenantId por segurança de SaaS
    payload['tenantId'] = item.tenantId;

    if (item.operation == SyncOperation.create) {
      await docRef.set(payload);
    } else if (item.operation == SyncOperation.update) {
      await docRef.set(payload, SetOptions(merge: true));
    }
  }

  String _getCollectionNameForEntity(String entityType) {
    switch (entityType) {
      case 'product':
        return 'products';
      case 'category':
        return 'categories';
      case 'catalog':
        return 'catalogs';
      // Mapear outras conforme necessário
      default:
        // By default, pluralize trivially or fallback
        return '${entityType}s';
    }
  }

  void _handleError(SyncQueueItem item, Object error) {
    if (item.status == SyncItemStatus.conflict) return; // Ja foi marcado

    item.status = SyncItemStatus.error;
    item.errorMessage = error.toString();
    
    // Backoff Exponencial Basico
    // 1 falha = 30s, 2 = 1m, 3 = 2m, etc... até um teto máximo de retries
    if (item.retryCount >= 10) {
      // Se chegou em 10, deixa em erro até intervencao manual
      item.nextRetryAt = null; 
    } else {
      final backoffSeconds = 30 * (1 << (item.retryCount - 1)); // 30, 60, 120...
      item.nextRetryAt = DateTime.now().add(Duration(seconds: backoffSeconds));
    }
  }
}
