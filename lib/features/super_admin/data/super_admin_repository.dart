import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:catalogo_ja/models/tenant.dart';

class SuperAdminRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Retorna todas as empresas (Tenants) do sistema.
  Stream<List<Tenant>> getAllTenantsStream() {
    return _firestore
        .collection('tenants')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Tenant.fromMap(doc.data())).toList());
  }

  /// Retorna todos os usuários do sistema.
  Stream<List<Map<String, dynamic>>> getAllUsersStream() {
    return _firestore
        .collection('users')
        .orderBy('email')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  /// Bloqueia ou desbloqueia uma empresa, usando o campo metadata.isBlocked
  Future<void> toggleTenantBlock(String tenantId, bool isBlocked) async {
    await _firestore.collection('tenants').doc(tenantId).set({
      'metadata': {
        'isBlocked': isBlocked,
      }
    }, SetOptions(merge: true));

    logAdminAction(
      isBlocked ? 'block_tenant' : 'unblock_tenant',
      {'tenantId': tenantId},
    );
  }

  /// Bloqueia ou desbloqueia um usuário, usando o campo disabled.
  Future<void> toggleUserBlock(String email, bool isBlocked) async {
    final normalizedEmail = email.trim().toLowerCase();
    await _firestore.collection('users').doc(normalizedEmail).set({
      'disabled': isBlocked,
    }, SetOptions(merge: true));

    logAdminAction(
      isBlocked ? 'block_user' : 'unblock_user',
      {'email': normalizedEmail},
    );
  }

  /// Registra uma ação administrativa no banco
  Future<void> logAdminAction(String action, Map<String, dynamic> details) async {
    try {
      await _firestore.collection('super_admin_logs').add({
        'action': action,
        'details': details,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Ignora falhas de log se houver problema de permissão temporária
    }
  }
}

final superAdminRepositoryProvider = Provider<SuperAdminRepository>((ref) {
  return SuperAdminRepository();
});
