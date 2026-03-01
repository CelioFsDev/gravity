import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:catalogo_ja/core/auth/user_role.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class UserRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Fetches a user's role by their email.
  /// If the user doesn't exist in the 'users' collection, returns [UserRole.viewer]
  /// or [UserRole.admin] if it's the first time and they are the owner.
  Future<UserRole> getUserRole(String email) async {
    try {
      final doc = await _firestore.collection('users').doc(email).get();
      if (!doc.exists) {
        // If the collection is empty, the first one to log in is Admin
        final allUsers = await _firestore.collection('users').limit(1).get();
        if (allUsers.docs.isEmpty) {
          await setUserRole(email, UserRole.admin);
          return UserRole.admin;
        }
        return UserRole.viewer;
      }

      final roleStr = doc.data()?['role'] as String?;
      return UserRole.values.firstWhere(
        (e) => e.name == roleStr,
        orElse: () => UserRole.viewer,
      );
    } catch (e) {
      return UserRole.viewer;
    }
  }

  /// Sets or updates a user's role by email.
  Future<void> setUserRole(String email, UserRole role) async {
    await _firestore.collection('users').doc(email).set({
      'role': role.name,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Streams the list of all users with their roles.
  Stream<List<Map<String, dynamic>>> getUsersStream() {
    return _firestore.collection('users').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return {'email': doc.id, 'role': doc.data()['role']};
      }).toList();
    });
  }
}

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository();
});
