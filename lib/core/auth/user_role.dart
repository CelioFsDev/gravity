import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:catalogo_ja/data/repositories/user_repository.dart';
import 'package:catalogo_ja/viewmodels/auth_viewmodel.dart';

part 'user_role.g.dart';

String _normalizeEmail(String? email) => email?.trim().toLowerCase() ?? '';

String effectiveUserRoleName(
  Map<String, dynamic> data, {
  required String tenantId,
  required String storeId,
}) {
  final normalizedTenantId = tenantId.trim();
  final normalizedStoreId = storeId.trim();

  final rolesByStore = data['rolesByStore'];
  if (rolesByStore is Map &&
      normalizedTenantId.isNotEmpty &&
      normalizedStoreId.isNotEmpty) {
    final tenantStores = rolesByStore[normalizedTenantId];
    if (tenantStores is Map) {
      final storeRole = tenantStores[normalizedStoreId] as String?;
      if (storeRole != null && storeRole.isNotEmpty) return storeRole;
    }
  }

  final rolesByTenant = data['rolesByTenant'];
  if (rolesByTenant is Map && normalizedTenantId.isNotEmpty) {
    final tenantRole = rolesByTenant[normalizedTenantId] as String?;
    if (tenantRole != null && tenantRole.isNotEmpty) return tenantRole;
  }

  return data['role'] as String? ?? UserRole.viewer.name;
}

enum UserRole {
  /// God Mode: Full access to everything
  admin('Administrador'),

  /// Manager: Can edit operational data, but not critical settings or users.
  operator('Gerente'),

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
    'celio@gmail.com',
    'celioferreira.dev@gmail.com',
  };
}

@riverpod
class CurrentRole extends _$CurrentRole {
  String? _lastFetchedEmail;
  UserRole _cachedRole = UserRole.viewer;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _subscription;

  @override
  UserRole build() {
    final authUser = ref.watch(authViewModelProvider).valueOrNull;
    final email = _normalizeEmail(authUser?.email);

    if (email.isEmpty) {
      _lastFetchedEmail = null;
      _cachedRole = UserRole.viewer;
      return UserRole.viewer;
    }

    // Force super admins to be admin in memory immediately
    final isSuperAdmin = UserRole.superAdminEmails.contains(email);
    if (isSuperAdmin) {
      _cachedRole = UserRole.admin;
    }

    // Only re-fetch if the user email changed
    if (_lastFetchedEmail != email) {
      _lastFetchedEmail = email;
      _subscription?.cancel();
      _fetchUserRole(email, forceAdmin: isSuperAdmin);
      _subscription = FirebaseFirestore.instance
          .collection('users')
          .doc(email)
          .snapshots()
          .listen((doc) {
        if (!doc.exists) return;
        final data = doc.data()!;
        var role = _roleFromData(data);
        if (isSuperAdmin) role = UserRole.admin;
        _cachedRole = role;
        state = role;
      });
      ref.onDispose(() => _subscription?.cancel());
    }

    return _cachedRole;
  }

  Future<void> _fetchUserRole(String email, {bool forceAdmin = false}) async {
    if (email.isEmpty) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(email)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        var role = _roleFromData(data);

        // Even if DB says otherwise, if it's a super admin, force it
        if (forceAdmin) {
          role = UserRole.admin;
          // Sync DB if it was wrong
          if (data['role'] != 'admin') {
            await ref.read(userRepositoryProvider).setUserRole(email, role);
          }
        }

        _cachedRole = role;
        state = role;
      } else {
        // Auto-create doc for super admins if missing
        if (forceAdmin) {
          await ref
              .read(userRepositoryProvider)
              .setUserRole(email, UserRole.admin);
          state = UserRole.admin;
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

  UserRole _roleFromData(Map<String, dynamic> data) {
    final activeTenantId = data['tenantId'] as String? ?? '';
    final activeStoreId = data['currentStoreId'] as String? ?? '';
    final roleStr = effectiveUserRoleName(
      data,
      tenantId: activeTenantId,
      storeId: activeStoreId,
    );

    return UserRole.values.firstWhere(
      (item) => item.name == roleStr,
      orElse: () => UserRole.viewer,
    );
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
      this == UserRole.admin || this == UserRole.operator;

  /// Sharing and viewing reports
  bool get canShareCatalog => this != UserRole.viewer;

  /// Actually as per user: Seller can share.
  bool get canShare => this != UserRole.viewer;

  /// Import and export operations
  bool get canImportData => this == UserRole.admin;

  /// Sensitive settings (Public Link, Store Info)
  bool get canEditSettings => this == UserRole.admin;

  /// User management for the active company.
  bool canManageUsers(String? email) {
    return this == UserRole.admin;
  }

  /// Global access to Admin Panel screens
  bool get canAccessAdmin => this != UserRole.viewer;

  bool get canViewDashboard => this == UserRole.admin || this == UserRole.operator;

  bool get canViewProducts => this == UserRole.admin || this == UserRole.operator;

  bool get canViewCollections => this == UserRole.admin || this == UserRole.operator;

  bool get canViewCategories => this == UserRole.admin || this == UserRole.operator;

  bool get canViewCatalogs => this != UserRole.viewer;

  bool get canViewProfile => this == UserRole.admin || this == UserRole.operator;

  bool get canViewImports => this == UserRole.admin;

  bool get canViewSettings => this == UserRole.admin;
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
