import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:catalogo_ja/core/storage/shared_preferences_service.dart';

class ActiveSessionState {
  final String? userId;
  final String? email;
  final String? tenantId;
  final String? tenantName;
  final String? storeId;
  final String? storeName;
  final String? role;
  final bool isReady;
  final String? errorMessage;

  const ActiveSessionState({
    this.userId,
    this.email,
    this.tenantId,
    this.tenantName,
    this.storeId,
    this.storeName,
    this.role,
    this.isReady = false,
    this.errorMessage,
  });

  ActiveSessionState copyWith({
    String? userId,
    String? email,
    String? tenantId,
    String? tenantName,
    String? storeId,
    String? storeName,
    String? role,
    bool? isReady,
    String? errorMessage,
  }) {
    return ActiveSessionState(
      userId: userId ?? this.userId,
      email: email ?? this.email,
      tenantId: tenantId ?? this.tenantId,
      tenantName: tenantName ?? this.tenantName,
      storeId: storeId ?? this.storeId,
      storeName: storeName ?? this.storeName,
      role: role ?? this.role,
      isReady: isReady ?? this.isReady,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  // Clear specific fields (like storeId) explicitly
  ActiveSessionState clearTenantAndStore() {
    return ActiveSessionState(
      userId: userId,
      email: email,
      tenantId: null,
      tenantName: null,
      storeId: null,
      storeName: null,
      role: role,
      isReady: isReady,
      errorMessage: null,
    );
  }

  bool get hasTenant => tenantId != null && tenantId!.isNotEmpty;
  bool get hasStore => storeId != null && storeId!.isNotEmpty;
}

class ActiveSessionNotifier extends StateNotifier<ActiveSessionState> {
  ActiveSessionNotifier() : super(const ActiveSessionState()) {
    _init();
  }

  Future<void> _init() async {
    try {
      final prefs = await SharedPreferencesService.getInstanceSafe();
      
      final savedUserId = prefs?.getString('session_userId');
      final savedEmail = prefs?.getString('session_email');
      final savedTenantId = prefs?.getString('session_tenantId');
      final savedTenantName = prefs?.getString('session_tenantName');
      final savedStoreId = prefs?.getString('session_storeId');
      final savedStoreName = prefs?.getString('session_storeName');
      final savedRole = prefs?.getString('session_role');

      state = state.copyWith(
        userId: savedUserId,
        email: savedEmail,
        tenantId: savedTenantId,
        tenantName: savedTenantName,
        storeId: savedStoreId,
        storeName: savedStoreName,
        role: savedRole,
        isReady: true,
      );
      
      if (savedEmail != null) {
        debugPrint('[SESSION] Sessão recuperada: ${savedEmail}, Tenant: ${savedTenantId}');
      }
    } catch (e) {
      debugPrint('[SESSION] Erro ao recuperar sessão: $e');
      state = state.copyWith(isReady: true, errorMessage: e.toString());
    }
  }

  Future<void> login(String userId, String email) async {
    final prefs = await SharedPreferencesService.getInstanceSafe();
    if (prefs != null) {
      await prefs.setString('session_userId', userId);
      await prefs.setString('session_email', email);
    }
    
    state = state.copyWith(
      userId: userId,
      email: email,
      isReady: true,
    );
    debugPrint('[SESSION] Usuário autenticado: $email');
  }

  Future<void> setTenant(String tenantId, {String? tenantName}) async {
    final prefs = await SharedPreferencesService.getInstanceSafe();
    if (prefs != null) {
      await prefs.setString('session_tenantId', tenantId);
      if (tenantName != null) await prefs.setString('session_tenantName', tenantName);
    }
    
    state = state.copyWith(
      tenantId: tenantId,
      tenantName: tenantName ?? state.tenantName,
      isReady: true,
    );
    debugPrint('[SESSION] ActiveSessionState atualizado (Tenant: $tenantId)');
  }

  Future<void> setStore(String storeId, {String? storeName}) async {
    final prefs = await SharedPreferencesService.getInstanceSafe();
    if (prefs != null) {
      await prefs.setString('session_storeId', storeId);
      if (storeName != null) await prefs.setString('session_storeName', storeName);
    }
    
    state = state.copyWith(
      storeId: storeId,
      storeName: storeName ?? state.storeName,
      isReady: true,
    );
    debugPrint('[SESSION] ActiveSessionState atualizado (Store: $storeId)');
  }

  Future<void> clearStore({String storeName = 'Matriz'}) async {
    final prefs = await SharedPreferencesService.getInstanceSafe();
    if (prefs != null) {
      await prefs.remove('session_storeId');
      await prefs.setString('session_storeName', storeName);
    }

    state = ActiveSessionState(
      userId: state.userId,
      email: state.email,
      tenantId: state.tenantId,
      tenantName: state.tenantName,
      storeId: null,
      storeName: storeName,
      role: state.role,
      isReady: true,
    );
    debugPrint('[SESSION] ActiveSessionState atualizado (Store: matriz)');
  }

  Future<void> setActiveTenant({
    required String tenantId,
    String? tenantName,
    String? storeId,
    String? storeName = 'Matriz',
    String? userId,
    String? email,
    String? role,
  }) async {
    final prefs = await SharedPreferencesService.getInstanceSafe();
    final normalizedStoreId = storeId?.trim();
    final effectiveStoreId =
        normalizedStoreId == null || normalizedStoreId.isEmpty
            ? null
            : normalizedStoreId;

    final effectiveUserId = userId ?? state.userId;
    final effectiveEmail = email ?? state.email;
    final effectiveTenantName = tenantName ?? state.tenantName;
    final effectiveStoreName =
        storeName ?? (effectiveStoreId == null ? 'Matriz' : state.storeName);
    final effectiveRole = role ?? state.role;

    if (prefs != null) {
      if (effectiveUserId != null && effectiveUserId.isNotEmpty) {
        await prefs.setString('session_userId', effectiveUserId);
      }
      if (effectiveEmail != null && effectiveEmail.isNotEmpty) {
        await prefs.setString('session_email', effectiveEmail);
      }
      await prefs.setString('session_tenantId', tenantId);
      if (effectiveTenantName != null && effectiveTenantName.isNotEmpty) {
        await prefs.setString('session_tenantName', effectiveTenantName);
      }

      if (effectiveStoreId == null) {
        await prefs.remove('session_storeId');
      } else {
        await prefs.setString('session_storeId', effectiveStoreId);
      }
      if (effectiveStoreName != null && effectiveStoreName.isNotEmpty) {
        await prefs.setString('session_storeName', effectiveStoreName);
      }
      if (effectiveRole != null && effectiveRole.isNotEmpty) {
        await prefs.setString('session_role', effectiveRole);
      }
    }

    state = ActiveSessionState(
      userId: effectiveUserId,
      email: effectiveEmail,
      tenantId: tenantId,
      tenantName: effectiveTenantName,
      storeId: effectiveStoreId,
      storeName: effectiveStoreName,
      role: effectiveRole,
      isReady: true,
    );
    debugPrint(
      '[SESSION] ActiveSessionState atualizado (Tenant ativo: $tenantId)',
    );
  }

  Future<void> logout() async {
    final prefs = await SharedPreferencesService.getInstanceSafe();
    if (prefs != null) {
      await prefs.remove('session_userId');
      await prefs.remove('session_email');
      await prefs.remove('session_tenantId');
      await prefs.remove('session_tenantName');
      await prefs.remove('session_storeId');
      await prefs.remove('session_storeName');
      await prefs.remove('session_role');
    }
    
    state = const ActiveSessionState(isReady: true);
    debugPrint('[SESSION] Sessão limpa (logout)');
  }
}

final activeSessionProvider = StateNotifierProvider<ActiveSessionNotifier, ActiveSessionState>((ref) {
  return ActiveSessionNotifier();
});
