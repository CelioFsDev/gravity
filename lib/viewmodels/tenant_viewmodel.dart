import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:catalogo_ja/data/repositories/tenant_repository.dart';
import 'package:catalogo_ja/models/tenant.dart';
import 'package:catalogo_ja/viewmodels/active_session_viewmodel.dart';
import 'package:catalogo_ja/viewmodels/auth_viewmodel.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


/// Provider que observa o usuário logado e carrega os dados da empresa dele.
final currentTenantProvider = StreamProvider<Tenant?>((ref) {
  final activeSession = ref.watch(activeSessionProvider);
  final sessionTenantId = activeSession.tenantId?.trim();
  if (sessionTenantId != null && sessionTenantId.isNotEmpty) {
    final fallbackTenant = Tenant(
      id: sessionTenantId,
      name: activeSession.tenantName?.trim().isNotEmpty == true
          ? activeSession.tenantName!.trim()
          : sessionTenantId,
      stores: const [],
    );

    return (() async* {
      yield fallbackTenant;
      yield* ref
          .watch(tenantRepositoryProvider)
          .watchTenant(sessionTenantId)
          .timeout(
            const Duration(seconds: 15),
            onTimeout: (sink) => sink.add(fallbackTenant),
          )
          .map((tenant) => tenant ?? fallbackTenant);
    })();
  }

  final authUser = ref.watch(authViewModelProvider).value;
  if (authUser == null || authUser.email == null) return Stream.value(null);

  final email = authUser.email!.trim().toLowerCase();

  // 1. Primeiro pegamos o tenantId do documento do usuário
  return FirebaseFirestore.instance
      .collection('users')
      .doc(email)
      .snapshots()
      // Se não emitir nenhum evento (nem erro) em 10s, lança erro para não travar o login
      .timeout(
        const Duration(seconds: 15),
        onTimeout: (sink) => sink.addError(
          Exception(
            'Tempo limite excedido ao carregar dados. Verifique a conexão.',
          ),
        ),
      )
      // 🔑 distinct: ignora re-emissões que não mudem o tenantId.
      .distinct((a, b) => a.data()?['tenantId'] == b.data()?['tenantId'])
      .asyncMap((userDoc) async {
        if (!userDoc.exists) return null;
        final tenantId = userDoc.data()?['tenantId'] as String?;
        if (tenantId == null || tenantId.isEmpty) return null;

        // 2. Com o tenantId, retornamos os dados da empresa
        try {
          final tenant = await ref
              .read(tenantRepositoryProvider)
              .getTenant(tenantId);
          if (tenant == null) throw Exception('Empresa não encontrada.');
          return tenant;
        } catch (e) {
          throw Exception('Falha ao obter dados da empresa: $e');
        }
      });
});

final tenantViewModelProvider = Provider<TenantRepository>((ref) {
  return ref.watch(tenantRepositoryProvider);
});

/// Provider que lista todos os tenants a que o usuário ativo pertence
final userTenantsProvider = FutureProvider<List<Tenant>>((ref) async {
  final authUser = ref.watch(authViewModelProvider).value;
  if (authUser == null || authUser.email == null) return [];

  final repo = ref.read(tenantRepositoryProvider);
  return await repo.getUserTenants(authUser.email!);
});

final requiresTenantOnboardingProvider = FutureProvider<bool>((ref) async {
  final authUser = ref.watch(authViewModelProvider).value;
  if (authUser == null || authUser.email == null) return false;

  try {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(authUser.email!.trim().toLowerCase())
        .get()
        .timeout(const Duration(seconds: 10)); // Timeout aumentado para Web

    final tenantIds = List<String>.from(doc.data()?['tenantIds'] ?? []);
    final oldTenantId = doc.data()?['tenantId'] as String?;

    return tenantIds.isEmpty && (oldTenantId == null || oldTenantId.isEmpty);
  } catch (e) {
    debugPrint('⚠️ [requiresTenantOnboardingProvider] Erro ou timeout: $e');
    throw Exception('Falha ao verificar dados da empresa. Tente novamente.');
  }
});

/// Provider que observa a unidade (loja) atual selecionada pelo usuário.
final currentStoreIdProvider = StreamProvider<String?>((ref) {
  final activeSession = ref.watch(activeSessionProvider);
  if (activeSession.hasTenant) {
    return Stream.value(activeSession.storeId);
  }

  final authUser = ref.watch(authViewModelProvider).value;
  if (authUser == null || authUser.email == null) return Stream.value(null);

  final email = authUser.email!.trim().toLowerCase();

  return FirebaseFirestore.instance
      .collection('users')
      .doc(email)
      .snapshots()
      .map((doc) => doc.data()?['currentStoreId'] as String?);
});
