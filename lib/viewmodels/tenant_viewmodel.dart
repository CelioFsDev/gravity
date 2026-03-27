import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:catalogo_ja/data/repositories/tenant_repository.dart';
import 'package:catalogo_ja/models/tenant.dart';
import 'package:catalogo_ja/viewmodels/auth_viewmodel.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Provider que observa o usuário logado e carrega os dados da empresa dele.
final currentTenantProvider = StreamProvider<Tenant?>((ref) {
  final authUser = ref.watch(authViewModelProvider).valueOrNull;
  if (authUser == null || authUser.email == null) return Stream.value(null);

  final email = authUser.email!.trim().toLowerCase();

  // 1. Primeiro pegamos o tenantId do documento do usuário
  return FirebaseFirestore.instance
      .collection('users')
      .doc(email)
      .snapshots()
      .asyncMap((userDoc) async {
        if (!userDoc.exists) return null;
        
        final tenantId = userDoc.data()?['tenantId'] as String?;
        if (tenantId == null || tenantId.isEmpty) return null;

        // 2. Com o tenantId, retornamos o stream dos dados da empresa
        return ref.read(tenantRepositoryProvider).getTenant(tenantId);
      });
});

final tenantViewModelProvider = Provider<TenantRepository>((ref) {
  return ref.watch(tenantRepositoryProvider);
});
