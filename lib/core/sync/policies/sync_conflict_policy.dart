import 'package:catalogo_ja/core/sync/models/sync_queue_item.dart';

abstract class SyncConflictPolicy {
  /// Retorna TRUE se a politica decidiu que a alteracao LOCAL deve sobrescrever o remoto.
  /// Retorna FALSE se o remoto ganhou (o item será dropado da fila ou marcado como conflict irreconcilável).
  Future<bool> resolveConflict({
    required SyncQueueItem localItem,
    required Map<String, dynamic>? remoteData,
  });
}
