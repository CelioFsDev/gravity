import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:catalogo_ja/core/auth/user_role.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class UserRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 🔑 Guard: garante que ensureUserProfile só executa 1x por sessão ativa.
  // authStateChanges pode emitir múltiplas vezes (token refresh), este flag
  // evita leituras/escritas duplicadas no Firestore.
  static bool _profileSyncedThisSession = false;

  /// Reseta o guard. Deve ser chamado no signOut().
  static void resetSession() => _profileSyncedThisSession = false;

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
    final existingTenantIds = List<String>.from(data['tenantIds'] ?? []);
    
    // Se o user tinha um tenantId mas não estava na lista, a gente adiciona (migração retroativa)
    if (existingTenantId != null && !existingTenantIds.contains(existingTenantId)) {
      existingTenantIds.add(existingTenantId);
    }
    
    // Atualizamos o payload
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
      'tenantId': existingTenantId, // Não forçamos mais um falso
      'tenantIds': existingTenantIds, // Nova estrutura de array
      'whatsappNumber': data['whatsappNumber'] ?? '',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> ensureUserProfileFromAuth(User user) async {
    // 🔑 Guard de sessão: só executa 1x por sessão ativa.
    // authStateChanges emite múltiplas vezes (token refresh, re-auth).
    // Cada execução = 1 read + 1 write no Firestore — evitamos isso.
    if (_profileSyncedThisSession) return;
    _profileSyncedThisSession = true;

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

  Stream<List<Map<String, dynamic>>> getUsersForTenantAndStoreStream({
    required String tenantId,
    required String storeId,
  }) {
    final normalizedTenantId = tenantId.trim();
    final normalizedStoreId = storeId.trim();

    if (normalizedTenantId.isEmpty) {
      return Stream.value(const []);
    }

    // Busca todos os usuários do tenant e filtra client-side:
    // - Usuários novos: têm currentStoreId igual à loja atual ✅
    // - Usuários antigos (legado): não têm currentStoreId definido ✅
    // - Usuários de OUTRA loja da mesma empresa: são excluídos ✅
    return _firestore
        .collection('users')
        .where('tenantIds', arrayContains: normalizedTenantId)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => doc.data())
              .where((user) {
                final userStoreId = user['currentStoreId'] as String?;
                // Inclui se pertence à loja atual OU se é legado (sem loja definida)
                if (normalizedStoreId.isEmpty) return true;
                return userStoreId == null ||
                    userStoreId.trim().isEmpty ||
                    userStoreId.trim() == normalizedStoreId;
              })
              .toList();
        });
  }

  Stream<List<Map<String, dynamic>>> getUsersForTenantStream({
    required String tenantId,
  }) {
    final normalizedTenantId = tenantId.trim();

    if (normalizedTenantId.isEmpty) {
      return Stream.value(const []);
    }

    return _firestore
        .collection('users')
        .where('tenantIds', arrayContains: normalizedTenantId)
        .orderBy('email')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
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
