import 'package:catalogo_ja/core/sync/models/sync_queue_item.dart';
import 'package:catalogo_ja/core/sync/repositories/sync_queue_repository.dart';
import 'package:catalogo_ja/core/sync/handlers/sync_entity_handler.dart';

class SyncWorker {
  final SyncQueueRepository _queueRepo;
  final Map<String, SyncEntityHandler> _handlers; // Injeção dinâmica

  bool _isProcessing = false;

  SyncWorker(this._queueRepo, this._handlers);

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
    final handler = _handlers[item.entityType];
    
    if (handler == null) {
      throw Exception('Missing SyncEntityHandler for entityType: ${item.entityType}');
    }

    // Delega a responsabilidade total (resolução e salvamento) para o Handler
    await handler.processItem(item);
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
