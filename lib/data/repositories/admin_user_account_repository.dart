import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:catalogo_ja/firebase_options.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

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
  AdminUserAccountRepository();

  Future<CreatedUserAccount> createEmailPasswordUser({
    required String email,
    required String password,
    required String role,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final tempAppName = 'TempApp-${const Uuid().v4()}';

    FirebaseApp? tempApp;
    try {
      // 1. Initialize a secondary Firebase app to create the user without logging out the current admin
      tempApp = await Firebase.initializeApp(
        name: tempAppName,
        options: DefaultFirebaseOptions.currentPlatform,
      );

      final tempAuth = FirebaseAuth.instanceFor(app: tempApp);

      // 2. Create the Auth account
      final userCredential = await tempAuth.createUserWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );

      final uid = userCredential.user?.uid;
      if (uid == null) {
        throw Exception('Falha ao obter UID do novo usu\u00e1rio');
      }

      // 3. Create the Firestore document (Admin has permission for this)
      await FirebaseFirestore.instance
          .collection('users')
          .doc(normalizedEmail)
          .set({
            'email': normalizedEmail,
            'role': role,
            'uid': uid,
            'createdAt': FieldValue.serverTimestamp(),
            'disabled': false,
            'displayName': '',
            'photoURL': '',
          });

      // 4. Cleanup in background (don't await here to avoid UI hanging)
      final appToCleanup = tempApp;
      tempApp = null;
      _cleanupSecondaryApp(appToCleanup);

      return CreatedUserAccount(email: normalizedEmail, role: role, uid: uid);
    } catch (e) {
      if (tempApp != null) {
        _cleanupSecondaryApp(tempApp);
      }
      rethrow;
    }
  }

  void _cleanupSecondaryApp(FirebaseApp app) {
    app.delete().catchError((e) => debugPrint('Erro na limpeza do app: $e'));
  }
}

final adminUserAccountRepositoryProvider = Provider<AdminUserAccountRepository>(
  (ref) {
    return AdminUserAccountRepository();
  },
);
