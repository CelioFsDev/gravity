import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:catalogo_ja/core/auth/user_role.dart';
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
    final normalizedEmail = _normalizeEmail(email);

    await _firestore.collection('users').doc(normalizedEmail).set({
      'email': normalizedEmail,
      'role': role.name,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Streams the list of all users with their roles.
  Stream<List<Map<String, dynamic>>> getUsersStream() {
    return _firestore.collection('users').orderBy('email').snapshots().map((
      snapshot,
    ) {
      return snapshot.docs.map((doc) {
        return {
          'email': (doc.data()['email'] as String?) ?? doc.id,
          'role': doc.data()['role'],
        };
      }).toList();
    });
  }
}

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository();
});
