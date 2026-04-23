import 'package:catalogo_ja/models/order.dart';
import 'package:catalogo_ja/data/repositories/contracts/orders_repository_contract.dart';
import 'package:catalogo_ja/data/repositories/hive_orders_repository.dart';
import 'package:catalogo_ja/core/sync/models/sync_queue_item.dart';
import 'package:catalogo_ja/core/sync/repositories/sync_queue_repository.dart';
import 'package:catalogo_ja/core/sync/providers/sync_providers.dart';
import 'package:catalogo_ja/viewmodels/tenant_viewmodel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Wrappa o HiveOrdersRepository e intercepta gravações para enfileirar no SyncWorker
class FirestoreOrdersRepository implements OrdersRepositoryContract {
  final HiveOrdersRepository _localRepo;
  final SyncQueueRepository _syncQueue;
  final String _tenantId;

  FirestoreOrdersRepository(this._localRepo, this._syncQueue, this._tenantId);

  @override
  Future<Order?> getOrder(String id) => _localRepo.getOrder(id);

  @override
  Future<List<Order>> getOrders() => _localRepo.getOrders();

  @override
  Stream<List<Order>> watchOrders() => _localRepo.watchOrders();

  @override
  Future<void> addOrder(Order order) async {
    final orderTenant = order.copyWith(tenantId: _tenantId);
    // 1. Salva offline instantaneamente
    await _localRepo.addOrder(orderTenant);
    // 2. Coloca na fila de sincronização
    await _syncQueue.enqueue(SyncQueueItem(
      tenantId: _tenantId,
      entityType: 'order',
      entityId: orderTenant.id,
      operation: SyncOperation.create,
      payload: orderTenant.toMap(),
    ));
  }

  @override
  Future<void> updateOrder(Order order) async {
    final orderTenant = order.copyWith(tenantId: _tenantId, updatedAt: DateTime.now());
    await _localRepo.updateOrder(orderTenant);
    await _syncQueue.enqueue(SyncQueueItem(
      tenantId: _tenantId,
      entityType: 'order',
      entityId: orderTenant.id,
      operation: SyncOperation.update,
      payload: orderTenant.toMap(),
    ));
  }

  @override
  Future<void> deleteOrder(String id) async {
    await _localRepo.deleteOrder(id);
    await _syncQueue.enqueue(SyncQueueItem(
      tenantId: _tenantId,
      entityType: 'order',
      entityId: id,
      operation: SyncOperation.delete,
    ));
  }

  @override
  Future<void> clearAll() => _localRepo.clearAll();
}

final syncOrdersRepositoryProvider = Provider<OrdersRepositoryContract>((ref) {
  final tenantAsync = ref.watch(currentTenantProvider);
  final localRepo = ref.watch(hiveOrdersRepositoryProvider);
  final syncQueue = ref.watch(syncQueueRepositoryProvider);

  return tenantAsync.when(
    data: (tenant) {
      if (tenant != null) {
        return FirestoreOrdersRepository(localRepo, syncQueue, tenant.id);
      }
      return localRepo; // Fallback se não tiver tenant
    },
    loading: () => localRepo,
    error: (_, _) => localRepo,
  );
});
