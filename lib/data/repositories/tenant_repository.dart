import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:catalogo_ja/models/tenant.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TenantRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _cachedTenantId;

  Future<String?> getCachedTenantId(String email) async {
    if (_cachedTenantId != null) return _cachedTenantId;
    final doc = await _firestore
        .collection('users')
        .doc(email.trim().toLowerCase())
        .get();
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

  /// Retorna a lista de empresas (Tenants) a que este usuário pertence.
  Future<List<Tenant>> getUserTenants(String email) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(email.trim().toLowerCase())
          .get();
      final List<String> tenantIds = List<String>.from(
        doc.data()?['tenantIds'] ?? [],
      );

      // Se tiver só tenantId antigo sem array
      final oldTenantId = doc.data()?['tenantId'] as String?;
      if (tenantIds.isEmpty && oldTenantId != null) {
        tenantIds.add(oldTenantId);
      }

      if (tenantIds.isEmpty) return [];

      // Divide em chunks de 10 porque o Firestore tem limite no arrayContainsAny / in
      final List<Tenant> allTenants = [];
      for (var i = 0; i < tenantIds.length; i += 10) {
        final chunk = tenantIds.sublist(
          i,
          i + 10 > tenantIds.length ? tenantIds.length : i + 10,
        );
        final snapshot = await _firestore
            .collection('tenants')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        allTenants.addAll(snapshot.docs.map((d) => Tenant.fromMap(d.data())));
      }

      return allTenants;
    } catch (e) {
      return [];
    }
  }

  Future<void> updateTenant(Tenant tenant) async {
    await _firestore
        .collection('tenants')
        .doc(tenant.id)
        .set(tenant.toMap(), SetOptions(merge: true));
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
      metadata: {'ownerEmail': email},
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
    final updatedStores = [...tenant.stores, storeName];
    await _firestore.collection('tenants').doc(tenantId).update({
      'stores': updatedStores,
    });
  }

  /// 🤝 Permite um vendedor se juntar a uma empresa informando o ID
  Future<void> joinTenant({
    required String tenantId,
    required String email,
    String? storeId,
  }) async {
    final doc = await _firestore.collection('tenants').doc(tenantId).get();
    if (!doc.exists) {
      throw Exception('ID de Empresa inválido ou não encontrado.');
    }

    final normalizedEmail = email.trim().toLowerCase();
    final tenant = Tenant.fromMap(doc.data()!);
    final normalizedStoreId = storeId?.trim();
    final currentStoreId =
        normalizedStoreId != null && normalizedStoreId.isNotEmpty
        ? normalizedStoreId
        : (tenant.stores.isNotEmpty ? tenant.stores.first : null);

    // Adiciona o tenantId na array e define a loja atual do vendedor
    await _firestore.collection('users').doc(normalizedEmail).set({
      'tenantIds': FieldValue.arrayUnion([tenantId]),
      'currentStoreId': currentStoreId,
      'tenantId':
          tenantId, // Opcional, para forçar ele a entrar direto nesse tenant agora
      'role': 'seller', // Quem entra via ID cai como Vendedor por padrão
    }, SetOptions(merge: true));

    _cachedTenantId = tenantId;
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
