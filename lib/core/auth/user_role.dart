import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:catalogo_ja/data/repositories/user_repository.dart';
import 'package:catalogo_ja/viewmodels/auth_viewmodel.dart';

part 'user_role.g.dart';

String _normalizeEmail(String? email) => email?.trim().toLowerCase() ?? '';

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

  /// Emails that have Super Admin privileges (can manage users)
  static const superAdminEmails = {'ti.vitoriana@gmail.com'};
}

@riverpod
class CurrentRole extends _$CurrentRole {
  @override
  UserRole build() {
    final authUser = ref.watch(authViewModelProvider).valueOrNull;
    final email = _normalizeEmail(authUser?.email);
    if (email.isEmpty) return UserRole.viewer;

    // Trigger async fetch
    _fetchUserRole(email);

    // If it's the super admin email, we can trust it's an admin if configured
    if (UserRole.superAdminEmails.contains(email)) {
      return UserRole.admin;
    }

    return UserRole.viewer;
  }

  Future<void> _fetchUserRole(String email) async {
    if (email.isEmpty) return;
    try {
      final role = await ref.read(userRepositoryProvider).getUserRole(email);
      state = role;
    } catch (_) {
      // Default to viewer if fetching fails.
      state = UserRole.viewer;
    }
  }

  void setRole(UserRole role) {
    state = role;
  }
}

extension UserRoleGuards on UserRole {
  /// Registrations management (Products, Categories, Collections)
  bool get canManageRegistrations =>
      this == UserRole.admin || this == UserRole.operator;

  /// Critical product management actions (delete, batch edit)
  bool get canDeleteProduct =>
      this == UserRole.admin || this == UserRole.operator;

  /// Creating/Editing products
  bool get canEditProduct =>
      this == UserRole.admin || this == UserRole.operator;

  /// Catalog creation and editing
  bool get canEditCatalog =>
      this == UserRole.admin ||
      this == UserRole.operator ||
      this == UserRole.seller;

  /// Sharing and viewing reports
  bool get canShareCatalog =>
      true; // Everyone including Viewer can share? No, usually not viewer.
  // Actually as per user: Seller can share.
  bool get canShare => this != UserRole.viewer;

  /// Import and export operations
  bool get canImportData => this == UserRole.admin;

  /// Sensitive settings (Public Link, Store Info)
  bool get canEditSettings => this == UserRole.admin;

  /// Full User Management (Limited to specific Super Admin emails)
  bool canManageUsers(String? email) =>
      this == UserRole.admin &&
      UserRole.superAdminEmails.contains(_normalizeEmail(email));

  /// Global access to Admin Panel screens
  bool get canAccessAdmin => this != UserRole.viewer;
}
