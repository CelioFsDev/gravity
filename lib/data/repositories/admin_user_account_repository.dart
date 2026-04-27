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
    String? tenantId,
    String? storeId,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    _throwIfProtectedAccount(normalizedEmail);
    try {
      final callable = _functions.httpsCallable('createEmailPasswordUser');
      final response = await callable.call<Map<String, dynamic>>({
        'email': normalizedEmail,
        'password': password,
        'role': role,
        'tenantId': tenantId?.trim(),
        'storeId': storeId?.trim(),
      });
      // Cloud Function succeeded — also ensure the Firestore doc exists locally
      final result = CreatedUserAccount.fromMap(response.data.cast<Object?, Object?>());
      await _ensureFirestoreUserDoc(
        email: normalizedEmail,
        uid: result.uid,
        role: role,
        tenantId: tenantId,
        storeId: storeId,
      );
      return result;
    } on FirebaseFunctionsException catch (error) {
      if (!_shouldUseLocalFallback(error)) rethrow;
      return _createEmailPasswordUserLocally(
        email: normalizedEmail,
        password: password,
        role: role,
        tenantId: tenantId,
        storeId: storeId,
      );
    }
  }

  /// Garante que o documento do usuário existe no Firestore.
  /// Não sobrescreve campos existentes.
  Future<void> _ensureFirestoreUserDoc({
    required String email,
    required String uid,
    required String role,
    String? tenantId,
    String? storeId,
  }) async {
    final validRole =
        UserRole.values.any((r) => r.name == role) ? role : UserRole.viewer.name;
    await _firestore.collection('users').doc(email).set({
      'authUid': uid,
      'createdAt': FieldValue.serverTimestamp(),
      'disabled': false,
      'displayName': '',
      'email': email,
      'lastRefreshAt': FieldValue.serverTimestamp(),
      'photoURL': '',
      'providerIds': const ['password'],
      'role': validRole,
      if (tenantId != null && tenantId.trim().isNotEmpty) ...{
        'tenantId': tenantId.trim(),
        'tenantIds': FieldValue.arrayUnion([tenantId.trim()]),
        'rolesByTenant.${tenantId.trim()}':
            storeId != null && storeId.trim().isNotEmpty ? 'seller' : validRole,
      },
      if (storeId != null && storeId.trim().isNotEmpty)
        'currentStoreId': storeId.trim(),
      if (tenantId != null &&
          tenantId.trim().isNotEmpty &&
          storeId != null &&
          storeId.trim().isNotEmpty)
        'rolesByStore.${tenantId.trim()}.${storeId.trim()}': validRole,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> updateUserAccess({
    required String email,
    required String role,
    required bool disabled,
    String displayName = '',
    String? tenantId,
    String? storeId,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    _throwIfProtectedAccount(normalizedEmail);
    try {
      final callable = _functions.httpsCallable('updateUserAccess');
      await callable.call<Map<String, dynamic>>({
        'email': normalizedEmail,
        'role': role,
        'disabled': disabled,
        'displayName': displayName.trim(),
        'tenantId': tenantId?.trim(),
        'storeId': storeId?.trim(),
      });
    } on FirebaseFunctionsException catch (error) {
      if (!_shouldUseLocalFallback(error)) rethrow;
      await _firestore.collection('users').doc(normalizedEmail).set({
        'disabled': disabled,
        'displayName': displayName.trim(),
        'email': normalizedEmail,
        'role': role,
        if (tenantId != null && tenantId.trim().isNotEmpty)
          'tenantId': tenantId.trim(),
        if (tenantId != null && tenantId.trim().isNotEmpty)
          'tenantIds': FieldValue.arrayUnion([tenantId.trim()]),
        if (tenantId != null && tenantId.trim().isNotEmpty)
          'rolesByTenant.${tenantId.trim()}':
              storeId != null && storeId.trim().isNotEmpty ? 'seller' : role,
        if (storeId != null && storeId.trim().isNotEmpty)
          'currentStoreId': storeId.trim(),
        if (tenantId != null &&
            tenantId.trim().isNotEmpty &&
            storeId != null &&
            storeId.trim().isNotEmpty)
          'rolesByStore.${tenantId.trim()}.${storeId.trim()}': role,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  Future<void> deleteUserAccount(
    String email, {
    String? tenantId,
    String? storeId,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    _throwIfProtectedAccount(normalizedEmail);
    try {
      final callable = _functions.httpsCallable('deleteUserAccount');
      await callable.call<Map<String, dynamic>>({
        'email': normalizedEmail,
        'tenantId': tenantId?.trim(),
        'storeId': storeId?.trim(),
      });
    } on FirebaseFunctionsException catch (error) {
      if (!_shouldUseLocalFallback(error)) rethrow;
      final updates = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final normalizedTenantId = tenantId?.trim() ?? '';
      final normalizedStoreId = storeId?.trim() ?? '';

      if (normalizedTenantId.isNotEmpty && normalizedStoreId.isNotEmpty) {
        updates['rolesByStore.$normalizedTenantId.$normalizedStoreId'] =
            FieldValue.delete();
      } else if (normalizedTenantId.isNotEmpty) {
        updates['rolesByTenant.$normalizedTenantId'] = FieldValue.delete();
        updates['tenantIds'] = FieldValue.arrayRemove([normalizedTenantId]);
      } else {
        updates['disabled'] = true;
      }

      await _firestore.collection('users').doc(normalizedEmail).set(
            updates,
            SetOptions(merge: true),
          );
    }
  }

  bool _shouldUseLocalFallback(FirebaseFunctionsException error) {
    return error.code == 'internal' ||
        error.code == 'not-found' ||
        error.code == 'unavailable';
  }

  void _throwIfProtectedAccount(String email) {
    if (!UserRole.superAdminEmails.contains(email)) return;
    throw FirebaseException(
      plugin: 'admin-user-account',
      code: 'permission-denied',
      message: 'Conta protegida. Nao e permitido alterar ou remover este acesso.',
    );
  }

  Future<CreatedUserAccount> _createEmailPasswordUserLocally({
    required String email,
    required String password,
    required String role,
    String? tenantId,
    String? storeId,
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

      final validRole = UserRole.values.any((item) => item.name == role)
          ? role
          : UserRole.viewer.name;

      await _firestore.collection('users').doc(email).set({
        'authUid': uid,
        'createdAt': FieldValue.serverTimestamp(),
        'disabled': false,
        'displayName': '',
        'email': email,
        'lastRefreshAt': FieldValue.serverTimestamp(),
        'photoURL': '',
        'providerIds': const ['password'],
        'role': validRole,
        if (tenantId != null && tenantId.trim().isNotEmpty) ...{
          'tenantId': tenantId.trim(),
          'tenantIds': FieldValue.arrayUnion([tenantId.trim()]),
          'rolesByTenant.${tenantId.trim()}':
              storeId != null && storeId.trim().isNotEmpty
                  ? 'seller'
                  : validRole,
        },
        if (storeId != null && storeId.trim().isNotEmpty)
          'currentStoreId': storeId.trim(),
        if (tenantId != null &&
            tenantId.trim().isNotEmpty &&
            storeId != null &&
            storeId.trim().isNotEmpty)
          'rolesByStore.${tenantId.trim()}.${storeId.trim()}': validRole,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return CreatedUserAccount(email: email, role: validRole, uid: uid);
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
