import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:catalogo_ja/core/auth/user_role.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class UserRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _normalizeEmail(String email) => email.trim().toLowerCase();

  /// Fetches a user's role by their email.
  /// If the user doesn't exist in the 'users' collection, returns
  /// [UserRole.viewer] or [UserRole.admin] if the email is a super admin.
  Future<UserRole> getUserRole(String email) async {
    final normalizedEmail = _normalizeEmail(email);

    try {
      final doc = await _firestore
          .collection('users')
          .doc(normalizedEmail)
          .get();

      if (doc.exists) {
        final roleStr = doc.data()?['role'] as String?;
        return UserRole.values.firstWhere(
          (role) => role.name == roleStr,
          orElse: () => UserRole.viewer,
        );
      }

      final assignedRole = UserRole.superAdminEmails.contains(normalizedEmail)
          ? UserRole.admin
          : UserRole.viewer;

      await setUserRole(normalizedEmail, assignedRole);
      return assignedRole;
    } catch (_) {
      return UserRole.viewer;
    }
  }

  /// Sets or updates a user's role by email.
  Future<void> setUserRole(String email, UserRole role) async {
    await updateUserData(email, {'role': role.name});
  }

  Future<void> ensureUserProfile({
    required String email,
    String displayName = '',
    String photoURL = '',
    List<String> providerIds = const [],
    String? authUid,
    UserRole? preferredRole,
    String? tenantId,
  }) async {
    final normalizedEmail = _normalizeEmail(email);
    if (normalizedEmail.isEmpty) return;

    final docRef = _firestore.collection('users').doc(normalizedEmail);
    final snapshot = await docRef.get();
    final data = snapshot.data() ?? <String, dynamic>{};
    final currentRole = data['role'] as String?;
    final role =
        currentRole ??
        preferredRole?.name ??
        (UserRole.superAdminEmails.contains(normalizedEmail)
            ? UserRole.admin.name
            : UserRole.viewer.name);

    final existingTenantId = data['tenantId'] as String?;
    final assignedTenantId = tenantId ?? existingTenantId ?? (authUid != null ? 't_$authUid' : null);

    // ✨ SaaS Logic: Ensure every user has a tenantId. 
    // This prevents "Local Mode" which causes data loss on logout because Hive is cleared.
    if (assignedTenantId != null && existingTenantId == null) {
      // Create a default tenant if it's the first time assigning it
      await _firestore.collection('tenants').doc(assignedTenantId).set({
        'id': assignedTenantId,
        'name': 'Meu Catálogo',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    await docRef.set({
      'authUid': authUid ?? data['authUid'],
      'createdAt': data['createdAt'] ?? FieldValue.serverTimestamp(),
      'disabled': data['disabled'] ?? false,
      'displayName': displayName.isNotEmpty
          ? displayName
          : (data['displayName'] as String? ?? ''),
      'email': normalizedEmail,
      'lastRefreshAt': FieldValue.serverTimestamp(),
      'photoURL': photoURL.isNotEmpty ? photoURL : (data['photoURL'] as String? ?? ''),
      'providerIds': providerIds.isNotEmpty
          ? providerIds
          : List<String>.from(data['providerIds'] ?? const []),
      'role': role,
      'tenantId': assignedTenantId,
      'whatsappNumber': data['whatsappNumber'] ?? '',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> ensureUserProfileFromAuth(User user) {
    final email = user.email?.trim().toLowerCase() ?? '';
    return ensureUserProfile(
      email: email,
      displayName: user.displayName ?? '',
      photoURL: user.photoURL ?? '',
      providerIds: user.providerData
          .map((provider) => provider.providerId)
          .whereType<String>()
          .toList(),
      authUid: user.uid,
      preferredRole: UserRole.superAdminEmails.contains(email)
          ? UserRole.admin
          : UserRole.viewer,
    );
  }

  /// Generic update for user document
  Future<void> updateUserData(String email, Map<String, dynamic> data) async {
    final normalizedEmail = _normalizeEmail(email);
    await _firestore.collection('users').doc(normalizedEmail).set({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Delete a user document (note: this doesn't delete from Auth)
  Future<void> deleteUser(String email) async {
    final normalizedEmail = _normalizeEmail(email);
    await _firestore.collection('users').doc(normalizedEmail).delete();
  }

  /// Streams the list of all users with their roles.
  Stream<List<Map<String, dynamic>>> getUsersStream() {
    return _firestore.collection('users').orderBy('email').snapshots().map((
      snapshot,
    ) {
      return snapshot.docs.map((doc) => doc.data()).toList();
    });
  }

  Stream<Map<String, dynamic>?> getUserStream(String email) {
    final normalizedEmail = _normalizeEmail(email);
    return _firestore.collection('users').doc(normalizedEmail).snapshots().map((
      doc,
    ) {
      return doc.data();
    });
  }
}

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository();
});
