enum AppPermission {
  viewProducts,
  editProducts,
  deleteProducts,
  publishCatalog,
  viewWholesalePrices,
  importBackup,
  manageUsers,
  editCompanySettings,
  viewAuditLogs,
}

extension AppPermissionExtension on AppPermission {
  String get description {
    switch (this) {
      case AppPermission.viewProducts:
        return 'Ver Produtos';
      case AppPermission.editProducts:
        return 'Criar/Editar Produtos';
      case AppPermission.deleteProducts:
        return 'Excluir Produtos';
      case AppPermission.publishCatalog:
        return 'Publicar e Compartilhar Catálogos';
      case AppPermission.viewWholesalePrices:
        return 'Ver Preços de Atacado';
      case AppPermission.importBackup:
        return 'Importar Backups e Restaurar Dados';
      case AppPermission.manageUsers:
        return 'Gerenciar Usuários e Vendedores';
      case AppPermission.editCompanySettings:
        return 'Alterar Configurações da Empresa';
      case AppPermission.viewAuditLogs:
        return 'Visualizar Trilha de Auditoria';
    }
  }
}
