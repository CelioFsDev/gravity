import 'package:catalogo_ja/core/auth/user_role.dart';
import 'package:catalogo_ja/firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CreatedUserAccount {
  const CreatedUserAccount({
    required this.email,
    required this.role,
    required this.uid,
  });

  factory CreatedUserAccount.fromMap(Map<Object?, Object?> map) {
    return CreatedUserAccount(
      email: map['email'] as String? ?? '',
      role: map['role'] as String? ?? 'viewer',
      uid: map['uid'] as String? ?? '',
    );
  }

  final String email;
  final String role;
  final String uid;
}

class AdminUserAccountRepository {
  AdminUserAccountRepository({
    FirebaseFunctions? functions,
    FirebaseFirestore? firestore,
  }) : _functions = functions ?? FirebaseFunctions.instance,
       _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFunctions _functions;
  final FirebaseFirestore _firestore;

  Future<CreatedUserAccount> createEmailPasswordUser({
    required String email,
    required String password,
    required String role,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    try {
      final callable = _functions.httpsCallable('createEmailPasswordUser');
      final response = await callable.call<Map<String, dynamic>>({
        'email': normalizedEmail,
        'password': password,
        'role': role,
      });

      return CreatedUserAccount.fromMap(response.data.cast<Object?, Object?>());
    } on FirebaseFunctionsException catch (error) {
      if (!_shouldUseLocalFallback(error)) rethrow;
      return _createEmailPasswordUserLocally(
        email: normalizedEmail,
        password: password,
        role: role,
      );
    }
  }

  Future<void> updateUserAccess({
    required String email,
    required String role,
    required bool disabled,
    String displayName = '',
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    try {
      final callable = _functions.httpsCallable('updateUserAccess');
      await callable.call<Map<String, dynamic>>({
        'email': normalizedEmail,
        'role': role,
        'disabled': disabled,
        'displayName': displayName.trim(),
      });
    } on FirebaseFunctionsException catch (error) {
      if (!_shouldUseLocalFallback(error)) rethrow;
      await _firestore.collection('users').doc(normalizedEmail).set({
        'disabled': disabled,
        'displayName': displayName.trim(),
        'email': normalizedEmail,
        'role': role,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  Future<void> deleteUserAccount(String email) async {
    final normalizedEmail = email.trim().toLowerCase();
    try {
      final callable = _functions.httpsCallable('deleteUserAccount');
      await callable.call<Map<String, dynamic>>({'email': normalizedEmail});
    } on FirebaseFunctionsException catch (error) {
      if (!_shouldUseLocalFallback(error)) rethrow;
      await _firestore.collection('users').doc(normalizedEmail).delete();
    }
  }

  bool _shouldUseLocalFallback(FirebaseFunctionsException error) {
    return error.code == 'internal' ||
        error.code == 'not-found' ||
        error.code == 'unavailable';
  }

  Future<CreatedUserAccount> _createEmailPasswordUserLocally({
    required String email,
    required String password,
    required String role,
  }) async {
    final tempAppName =
        'admin-user-${DateTime.now().microsecondsSinceEpoch.toString()}';
    FirebaseApp? tempApp;

    try {
      tempApp = await Firebase.initializeApp(
        name: tempAppName,
        options: DefaultFirebaseOptions.currentPlatform,
      );

      final tempAuth = FirebaseAuth.instanceFor(app: tempApp);
      final credential = await tempAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final uid = credential.user?.uid;
      if (uid == null) {
        throw FirebaseAuthException(
          code: 'internal-error',
          message: 'Nao foi possivel obter o uid do usuario criado.',
        );
      }

      await _firestore.collection('users').doc(email).set({
        'authUid': uid,
        'createdAt': FieldValue.serverTimestamp(),
        'disabled': false,
        'displayName': '',
        'email': email,
        'lastRefreshAt': FieldValue.serverTimestamp(),
        'photoURL': '',
        'providerIds': const ['password'],
        'role': UserRole.values.any((item) => item.name == role)
            ? role
            : UserRole.viewer.name,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return CreatedUserAccount(email: email, role: role, uid: uid);
    } finally {
      await tempApp?.delete();
    }
  }
}

final adminUserAccountRepositoryProvider = Provider<AdminUserAccountRepository>(
  (ref) {
    return AdminUserAccountRepository();
  },
);
