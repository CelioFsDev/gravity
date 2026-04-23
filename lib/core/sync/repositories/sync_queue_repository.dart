import 'package:hive_flutter/hive_flutter.dart';
import 'package:catalogo_ja/core/sync/models/sync_queue_item.dart';

class SyncQueueRepository {
  static const String boxName = 'sync_queue';
  final Box<SyncQueueItem> _box;

  SyncQueueRepository(this._box);

  Future<void> enqueue(SyncQueueItem item) async {
    await _box.put(item.id, item);
  }

  Future<void> updateItem(SyncQueueItem item) async {
    item.updatedAt = DateTime.now();
    await _box.put(item.id, item);
  }

  Future<void> deleteItem(String id) async {
    await _box.delete(id);
  }

  SyncQueueItem? getItem(String id) {
    return _box.get(id);
  }

  List<SyncQueueItem> getPendingOrErrorItems() {
    final now = DateTime.now();
    return _box.values.where((item) {
      if (item.status == SyncItemStatus.pending) return true;
      if (item.status == SyncItemStatus.error) {
        // Se tem proxima tentativa configurada e a hora já chegou
        if (item.nextRetryAt != null && item.nextRetryAt!.isBefore(now)) {
          return true;
        }
      }
      return false;
    }).toList();
  }

  List<SyncQueueItem> getAll() {
    return _box.values.toList();
  }

  /// Limpa itens que já foram sincronizados com sucesso há mais de X tempo (Cleanup)
  Future<void> clearSuccessfullySynced({Duration olderThan = const Duration(days: 1)}) async {
    final cutoff = DateTime.now().subtract(olderThan);
    final keysToRemove = _box.values
        .where((item) => item.status == SyncItemStatus.synced && item.updatedAt.isBefore(cutoff))
        .map((e) => e.id)
        .toList();

    await _box.deleteAll(keysToRemove);
  }
}
