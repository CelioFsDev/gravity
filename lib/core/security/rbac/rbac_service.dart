import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:catalogo_ja/core/auth/user_role.dart';
import 'package:catalogo_ja/core/security/rbac/permissions.dart';
import 'package:catalogo_ja/core/security/rbac/roles.dart';
import 'package:catalogo_ja/viewmodels/auth_viewmodel.dart';
import 'package:catalogo_ja/data/repositories/user_repository.dart';

/// Uma Exception customizada para tratamento elegante na UI.
class PermissionDeniedException implements Exception {
  final AppPermission permission;
  final String message;

  PermissionDeniedException(this.permission)
      : message = 'Você não tem permissão para: ${permission.description}';

  @override
  String toString() => message;
}

/// Serviço central de RBAC
class RbacService {
  final AppRole currentRole;

  RbacService(this.currentRole);

  /// Retorna true se a role atual possuir a permissão.
  bool hasPermission(AppPermission permission) {
    return currentRole.permissions.contains(permission);
  }

  /// Trava a execução se não tiver a permissão.
  /// Ideal para ser chamado no topo de métodos de Repositório ou Controllers.
  void requirePermission(AppPermission permission) {
    if (!hasPermission(permission)) {
      throw PermissionDeniedException(permission);
    }
  }

  /// Retorna a lista de permissões que faltam para uma ação combinada.
  List<AppPermission> missingPermissions(List<AppPermission> requiredPermissions) {
    return requiredPermissions
        .where((p) => !hasPermission(p))
        .toList();
  }
}

/// Provider que escuta o usuário ativo e retorna o seu AppRole
final currentAppRoleProvider = StreamProvider<AppRole>((ref) async* {
  final user = ref.watch(authViewModelProvider).value;
  
  if (user == null || user.email == null) {
    yield AppRole.seller; // Role de fallback mais restrito
    return;
  }

  final userRepo = ref.watch(userRepositoryProvider);
  
  await for (final userData in userRepo.getUserStream(user.email!)) {
    if (userData == null) {
      yield AppRole.seller;
      continue;
    }

    final tenantId = userData['tenantId'] as String? ?? '';
    final storeId = userData['currentStoreId'] as String? ?? '';
    final roleStr = effectiveUserRoleName(
      userData,
      tenantId: tenantId,
      storeId: storeId,
    );
    
    // Mapeamento das strings vindas do banco (que usavam UserRole) para AppRole
    if (roleStr == 'admin' || roleStr == 'superAdmin') {
      yield AppRole.admin;
    } else if (roleStr == 'manager' || roleStr == 'operator') {
      yield AppRole.manager;
    } else if (roleStr == 'catalogOperator') {
      yield AppRole.catalogOperator;
    } else {
      yield AppRole.seller;
    }
  }
});

/// Provider do RBAC injetável em qualquer parte do app
final rbacServiceProvider = Provider<RbacService>((ref) {
  // Pega o valor atualizado reativamente do Stream, 
  // cai pro seller se ainda estiver carregando
  final role = ref.watch(currentAppRoleProvider).value ?? AppRole.seller;
  return RbacService(role);
});
