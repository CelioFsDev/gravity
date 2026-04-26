import 'package:catalogo_ja/core/security/rbac/permissions.dart';

enum AppRole {
  admin,
  manager,
  seller,
  catalogOperator, // operador de cadastro
}

extension AppRoleExtension on AppRole {
  String get displayName {
    switch (this) {
      case AppRole.admin:
        return 'Administrador';
      case AppRole.manager:
        return 'Gerente';
      case AppRole.seller:
        return 'Vendedor';
      case AppRole.catalogOperator:
        return 'Operador de Cadastro';
    }
  }

  Set<AppPermission> get permissions => rolePermissionsMap[this] ?? {};
}

const Map<AppRole, Set<AppPermission>> rolePermissionsMap = {
  AppRole.admin: {
    AppPermission.viewProducts,
    AppPermission.editProducts,
    AppPermission.deleteProducts,
    AppPermission.publishCatalog,
    AppPermission.viewWholesalePrices,
    AppPermission.importBackup,
    AppPermission.manageUsers,
    AppPermission.editCompanySettings,
    AppPermission.viewAuditLogs,
  },
  
  AppRole.manager: {
    AppPermission.viewProducts,
    AppPermission.editProducts,
    AppPermission.publishCatalog,
    AppPermission.viewWholesalePrices,
    AppPermission.viewAuditLogs,
  },
  
  AppRole.catalogOperator: {
    AppPermission.viewProducts,
    AppPermission.editProducts,
    AppPermission.deleteProducts,
    // Note: Não tem permissão de ver preço de atacado nem publicar catálogo.
  },

  AppRole.seller: {
    AppPermission.publishCatalog,
    // Vendedor padrão não edita produtos, apenas compartilha o catálogo montado.
  },
};
