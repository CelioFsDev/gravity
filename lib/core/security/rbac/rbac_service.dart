import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:catalogo_ja/core/security/rbac/permissions.dart';
import 'package:catalogo_ja/core/security/rbac/roles.dart';

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

/// Provider do RBAC
/// 
/// O ideal é que o 'role' do usuário venha do JWT (Custom Claim) decodificado
/// ou de um documento TenantUser armazenado no Riverpod.
/// Por padrão, deixamos como admin na inicialização até plugar com auth.
final rbacServiceProvider = Provider<RbacService>((ref) {
  // TODO: Aqui vamos ler o state do usuário ativo, ex:
  // final roleString = ref.watch(authViewModelProvider).value?.claims?['role'] ?? 'seller';
  // final role = _parseRole(roleString);

  // Por hora (fallback ou dev)
  const currentRole = AppRole.admin; 
  return RbacService(currentRole);
});
