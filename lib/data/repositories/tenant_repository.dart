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
