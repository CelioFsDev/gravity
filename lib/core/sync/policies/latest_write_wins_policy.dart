import 'package:catalogo_ja/core/sync/models/sync_queue_item.dart';
import 'package:catalogo_ja/core/sync/policies/sync_conflict_policy.dart';

class LatestWriteWinsPolicy implements SyncConflictPolicy {
  @override
  Future<bool> resolveConflict({
    required SyncQueueItem localItem,
    required Map<String, dynamic>? remoteData,
  }) async {
    if (remoteData == null) {
      // Remote doesn't exist anymore or didn't fetch properly
      // Let's assume local wins if it was an update/create.
      return true;
    }

    final localBaseVersion = localItem.baseVersion ?? DateTime.fromMillisecondsSinceEpoch(0);
    DateTime? remoteUpdatedAt;

    // Tentar extrair do modelo comum
    if (remoteData.containsKey('updatedAt')) {
      final val = remoteData['updatedAt'];
      if (val is String) {
        remoteUpdatedAt = DateTime.tryParse(val);
      } else if (val != null) {
        // Fallback for timestamps depending on what firebase translates it to 
        try {
           remoteUpdatedAt = (val as dynamic).toDate();
        } catch (_) {}
      }
    }

    if (remoteUpdatedAt == null) return true;

    // Se o lastKnown do local for MAIOR ou IGUAL a versão atual do remote,
    // significa que ninguém tocou na cloud desde a minha leitura base. Eu ganho.
    // Se a cloud foi alterada (remote > baseVersion), eu perdi.
    if (remoteUpdatedAt.isAfter(localBaseVersion)) {
      return false; // Remote ganha. O device está desatualizado.
    }

    return true; // Local ganha.
  }
}
