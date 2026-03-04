import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
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
  static const superAdminEmails = {
    'ti.vitoriana@gmail.com',
    'celiofs.dev@gmail.com',
  };
}

@riverpod
class CurrentRole extends _$CurrentRole {
  String? _lastFetchedEmail;
  UserRole _cachedRole = UserRole.viewer;

  @override
  UserRole build() {
    final authUser = ref.watch(authViewModelProvider).valueOrNull;
    final email = _normalizeEmail(authUser?.email);

    if (email.isEmpty) {
      _lastFetchedEmail = null;
      _cachedRole = UserRole.viewer;
      return UserRole.viewer;
    }

    // Super admins have immediate access
    if (UserRole.superAdminEmails.contains(email)) {
      _cachedRole = UserRole.admin;
    }

    // Only re-fetch if the user email changed
    if (_lastFetchedEmail != email) {
      _lastFetchedEmail = email;
      _fetchUserRole(email);
    }

    return _cachedRole;
  }

  Future<void> _fetchUserRole(String email) async {
    if (email.isEmpty) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(email)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        final roleStr = data['role'] as String? ?? 'viewer';

        final role = UserRole.values.firstWhere(
          (item) => item.name == roleStr,
          orElse: () => UserRole.viewer,
        );

        _cachedRole = role;
        state = role;
      } else {
        // Auto-create doc for super admins if missing
        if (UserRole.superAdminEmails.contains(email)) {
          await ref
              .read(userRepositoryProvider)
              .setUserRole(email, UserRole.admin);
        }
      }
    } catch (e) {
      debugPrint('Error fetching user role for $email: $e');
    }
  }

  void setRole(UserRole role) {
    _cachedRole = role;
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
  bool get canShareCatalog => true;

  /// Actually as per user: Seller can share.
  bool get canShare => this != UserRole.viewer;

  /// Import and export operations
  bool get canImportData => this == UserRole.admin;

  /// Sensitive settings (Public Link, Store Info)
  bool get canEditSettings => this == UserRole.admin;

  /// Full User Management (Limited to specific Super Admin emails)
  bool canManageUsers(String? email) => this == UserRole.admin;

  /// Global access to Admin Panel screens
  bool get canAccessAdmin => this != UserRole.viewer;
}

/// Provider to check if the current user is disabled/suspended
@riverpod
Stream<bool> currentUserStatus(ref) {
  // Use a generic ProviderRef to avoid generator issues if not running
  final user = ref.watch(authViewModelProvider).valueOrNull;
  if (user == null || user.email == null) return Stream.value(false);

  final email = _normalizeEmail(user.email);
  return FirebaseFirestore.instance
      .collection('users')
      .doc(email)
      .snapshots()
      .map((doc) => doc.data()?['disabled'] as bool? ?? false);
}
