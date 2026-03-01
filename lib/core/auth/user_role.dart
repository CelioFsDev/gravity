import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'user_role.g.dart';

enum UserRole {
  /// God Mode: Full access to everything
  admin('Administrador'),

  /// Operation: Can manage products and catalogs, but not critical settings
  operator('Operador'),

  /// Seller: Can view everything and share but not edit
  seller('Vendedor'),

  /// Viewer: Just viewing (client/restricted)
  viewer('Visualizador');

  final String label;
  const UserRole(this.label);
}

@riverpod
class CurrentRole extends _$CurrentRole {
  @override
  UserRole build() {
    // Today, only 'admin' exists.
    // In future versions, this would be fetched from auth storage or API.
    return UserRole.admin;
  }

  void setRole(UserRole role) {
    state = role;
  }
}

extension UserRoleGuards on UserRole {
  /// Critical product management actions (delete, batch edit)
  bool get canDeleteProduct =>
      this == UserRole.admin || this == UserRole.operator;

  /// Creating/Editing products
  bool get canEditProduct =>
      this == UserRole.admin || this == UserRole.operator;

  /// Catalog creation and editing
  bool get canEditCatalog =>
      this == UserRole.admin || this == UserRole.operator;

  /// Sharing and viewing reports
  bool get canShareCatalog => true; // Everyone for now

  /// Import and export operations
  bool get canImportData => this == UserRole.admin;

  /// Sensitive settings (Public Link, Store Info)
  bool get canEditSettings => this == UserRole.admin;

  /// Global access to Admin Panel screens
  bool get canAccessAdmin => this != UserRole.viewer;
}
