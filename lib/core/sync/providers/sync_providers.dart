import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:catalogo_ja/core/sync/models/sync_queue_item.dart';
import 'package:catalogo_ja/core/sync/repositories/sync_queue_repository.dart';
import 'package:catalogo_ja/core/sync/policies/latest_write_wins_policy.dart';
import 'package:catalogo_ja/core/sync/policies/sync_conflict_policy.dart';
import 'package:catalogo_ja/core/sync/workers/sync_worker.dart';

// Repositorio Local
final syncQueueRepositoryProvider = Provider<SyncQueueRepository>((ref) {
  final box = Hive.box<SyncQueueItem>(SyncQueueRepository.boxName);
  return SyncQueueRepository(box);
});

// A Política atual
final syncConflictPolicyProvider = Provider<SyncConflictPolicy>((ref) {
  return LatestWriteWinsPolicy();
});

// Worker Engine
final syncWorkerProvider = Provider<SyncWorker>((ref) {
  final repo = ref.watch(syncQueueRepositoryProvider);
  final policy = ref.watch(syncConflictPolicyProvider);
  return SyncWorker(repo, policy);
});

// Observabilidade (Contador de Pendentes/Erros) // TODO: Mudar para ValueListenable no futuro p/ performance 
final syncStatusSummaryProvider = Provider<Map<String, int>>((ref) {
  final repo = ref.watch(syncQueueRepositoryProvider);
  final all = repo.getAll();
  
  int pending = 0;
  int error = 0;
  int conflict = 0;
  int syncing = 0;

  for (var item in all) {
    if (item.status == SyncItemStatus.pending) pending++;
    else if (item.status == SyncItemStatus.error) error++;
    else if (item.status == SyncItemStatus.conflict) conflict++;
    else if (item.status == SyncItemStatus.syncing) syncing++;
  }

  return {
    'pending': pending,
    'error': error,
    'conflict': conflict,
    'syncing': syncing,
  };
});
