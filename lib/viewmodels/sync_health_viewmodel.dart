import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:catalogo_ja/core/sync/models/sync_queue_item.dart';
import 'package:catalogo_ja/core/sync/providers/sync_providers.dart';

/// Modelo de saúde da sincronização (Ideal para um Dashboard do Lojista)
class SyncHealthMetrics {
  final int totalPending;
  final int totalSyncing;
  final int totalErrors;
  final int totalSyncedThisSession;
  final List<SyncQueueItem> recentErrors;

  SyncHealthMetrics({
    this.totalPending = 0,
    this.totalSyncing = 0,
    this.totalErrors = 0,
    this.totalSyncedThisSession = 0,
    this.recentErrors = const [],
  });

  bool get isHealthy => totalErrors == 0;
  bool get isIdle => totalPending == 0 && totalSyncing == 0;
  double get errorRate => (totalPending + totalErrors) == 0
      ? 0
      : totalErrors / (totalPending + totalErrors);
}

class SyncHealthViewModel extends StateNotifier<SyncHealthMetrics> {
  final Ref _ref;

  SyncHealthViewModel(this._ref) : super(SyncHealthMetrics()) {
    _startObserving();
  }

  void _startObserving() {
    // Usamos um timer simples aqui pois o Hive não expõe streams filtradas tão facilmente
    // Em um app produtivo gigante, usaríamos ValueListenableBuilder direto na box do Hive
    // Porém essa métrica pode ser consultada a cada X segundos para popular o dashboard de settings.

    // Simulação reativa inicial
    refreshMetrics();
  }

  void refreshMetrics() {
    final repo = _ref.read(syncQueueRepositoryProvider);
    final allItems = repo.getAll();

    int pending = 0;
    int syncing = 0;
    int errors = 0;
    int synced = 0;
    List<SyncQueueItem> errList = [];

    for (final item in allItems) {
      if (item.status == SyncItemStatus.pending) {
        pending++;
      } else if (item.status == SyncItemStatus.syncing)
        syncing++;
      else if (item.status == SyncItemStatus.error ||
          item.status == SyncItemStatus.conflict) {
        errors++;
        errList.add(item);
      } else if (item.status == SyncItemStatus.synced)
        synced++;
    }

    state = SyncHealthMetrics(
      totalPending: pending,
      totalSyncing: syncing,
      totalErrors: errors,
      totalSyncedThisSession: synced,
      recentErrors: errList,
    );
  }
}

/// Provider que fornece as métricas de saúde da Sincronização B2B para telas administrativas
final syncHealthProvider =
    StateNotifierProvider<SyncHealthViewModel, SyncHealthMetrics>((ref) {
      return SyncHealthViewModel(ref);
    });
