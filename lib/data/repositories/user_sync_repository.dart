import 'package:catalogo_ja/core/auth/user_role.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class UserSyncResult {
  const UserSyncResult({
    required this.created,
    required this.processed,
    required this.skipped,
    required this.updated,
  });

  factory UserSyncResult.fromMap(Map<Object?, Object?> map) {
    int readInt(String key) => (map[key] as num?)?.toInt() ?? 0;

    return UserSyncResult(
      created: readInt('created'),
      processed: readInt('processed'),
      skipped: readInt('skipped'),
      updated: readInt('updated'),
    );
  }

  final int created;
  final int processed;
  final int skipped;
  final int updated;
}

class UserSyncRepository {
  UserSyncRepository({
    FirebaseFunctions? functions,
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  }) : _functions = functions ?? FirebaseFunctions.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFunctions _functions;
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  Future<UserSyncResult> syncAuthUsers() async {
    try {
      final callable = _functions.httpsCallable('syncAuthUsers');
      final response = await callable.call<Map<String, dynamic>>();
      return UserSyncResult.fromMap(response.data.cast<Object?, Object?>());
    } on FirebaseFunctionsException catch (error) {
      if (!_shouldUseLocalFallback(error)) rethrow;
      return _syncCurrentUserLocally();
    } on FirebaseException {
      return _syncCurrentUserLocally();
    } catch (_) {
      return _syncCurrentUserLocally();
    }
  }

  bool _shouldUseLocalFallback(FirebaseFunctionsException error) {
    return error.code == 'internal' ||
        error.code == 'not-found' ||
        error.code == 'unavailable';
  }

  Future<UserSyncResult> _syncCurrentUserLocally() async {
    final user = _auth.currentUser;
    final email = user?.email?.trim().toLowerCase() ?? '';
    if (user == null || email.isEmpty) {
      throw FirebaseFunctionsException(
        code: 'unauthenticated',
        message: 'Nao ha usuario autenticado para sincronizar.',
      );
    }

    final docRef = _firestore.collection('users').doc(email);
    final snapshot = await docRef.get();
    final data = snapshot.data() ?? <String, dynamic>{};
    final role =
        data['role'] as String? ??
        (UserRole.superAdminEmails.contains(email)
            ? UserRole.admin.name
            : UserRole.viewer.name);

    await docRef.set({
      'authUid': user.uid,
      'createdAt': data['createdAt'] ?? FieldValue.serverTimestamp(),
      'disabled': data['disabled'] ?? false,
      'displayName': user.displayName ?? (data['displayName'] as String? ?? ''),
      'email': email,
      'lastRefreshAt': FieldValue.serverTimestamp(),
      'photoURL': user.photoURL ?? (data['photoURL'] as String? ?? ''),
      'providerIds': user.providerData
          .map((provider) => provider.providerId)
          .whereType<String>()
          .toList(),
      'role': role,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return UserSyncResult(
      created: snapshot.exists ? 0 : 1,
      processed: 1,
      skipped: 0,
      updated: snapshot.exists ? 1 : 0,
    );
  }
}

final userSyncRepositoryProvider = Provider<UserSyncRepository>((ref) {
  return UserSyncRepository();
});
