import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:catalogo_ja/models/tenant.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TenantRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _cachedTenantId;

  Future<String?> getCachedTenantId(String email) async {
    if (_cachedTenantId != null) return _cachedTenantId;
    final doc = await _firestore.collection('users').doc(email.trim().toLowerCase()).get();
    _cachedTenantId = doc.data()?['tenantId'] as String?;
    return _cachedTenantId;
  }

  void clearTenantCache() => _cachedTenantId = null;

  Future<Tenant?> getTenant(String tenantId) async {
    try {
      final doc = await _firestore.collection('tenants').doc(tenantId).get();
      if (doc.exists) {
        return Tenant.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> updateTenant(Tenant tenant) async {
    await _firestore.collection('tenants').doc(tenant.id).set(
      tenant.toMap(),
      SetOptions(merge: true),
    );
  }

  /// 🚀 Cria um novo Tenant (Empresa) e a 1ª Loja
  Future<String> createTenantWithStore({
    required String companyName,
    required String storeName,
    required String adminEmail,
  }) async {
    final email = adminEmail.trim().toLowerCase();
    
    // 1. Gera ID amigável (slug)
    String tenantId = companyName
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^a-z0-9]'), '-')
        .replaceAll(RegExp(r'-+'), '-');
    
    // Evita IDs vazios ou muito curtos
    if (tenantId.length < 3) {
      tenantId = 'empresa-${DateTime.now().millisecondsSinceEpoch}';
    }

    // Verifica se já existe, se sim adiciona um sufixo
    final existing = await _firestore.collection('tenants').doc(tenantId).get();
    if (existing.exists) {
      tenantId = '$tenantId-${DateTime.now().millisecondsSinceEpoch % 10000}';
    }

    final newTenant = Tenant(
      id: tenantId,
      name: companyName,
      stores: [storeName],
    );

    // 2. Cria o Tenant
    await _firestore.collection('tenants').doc(tenantId).set(newTenant.toMap());

    // 3. Vincula o Usuário como Admin
    await _firestore.collection('users').doc(email).set({
      'tenantId': tenantId,
      'tenantIds': FieldValue.arrayUnion([tenantId]),
      'currentStoreId': storeName,
      'role': 'admin', // Quem cria é sempre Admin
    }, SetOptions(merge: true));

    _cachedTenantId = tenantId;
    return tenantId;
  }

  /// 📍 Adiciona a 2ª Loja (limite de 2)
  Future<void> addStoreToTenant(String tenantId, String storeName) async {
    final doc = await _firestore.collection('tenants').doc(tenantId).get();
    if (!doc.exists) throw Exception('Empresa não encontrada.');

    final tenant = Tenant.fromMap(doc.data()!);
    if (tenant.stores.length >= 2) {
      throw Exception('Limite de 2 unidades atingido para esta empresa.');
    }

    final updatedStores = [...tenant.stores, storeName];
    await _firestore.collection('tenants').doc(tenantId).update({
      'stores': updatedStores,
    });
  }

  Stream<Tenant?> watchTenant(String tenantId) {
    return _firestore
        .collection('tenants')
        .doc(tenantId)
        .snapshots()
        .map((doc) => doc.exists ? Tenant.fromMap(doc.data()!) : null);
  }
}

final tenantRepositoryProvider = Provider<TenantRepository>((ref) {
  return TenantRepository();
});
