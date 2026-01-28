import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gravity/core/config/data_backend.dart';

import 'auth_user.dart';

abstract class AuthRepositoryContract {
  Stream<AuthUser?> authStateChanges();
  Future<AuthUser> register({required String email, required String password});
  Future<AuthUser> signIn({required String email, required String password});
  Future<void> signOut();
  Future<AuthUser?> getCurrentUser();
}

class FirebaseAuthRepository implements AuthRepositoryContract {
  FirebaseAuthRepository({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  @override
  Stream<AuthUser?> authStateChanges() {
    return _auth.authStateChanges().asyncMap((firebaseUser) async {
      if (firebaseUser == null) return null;
      return _ensureAndFetch(firebaseUser);
    });
  }

  @override
  Future<AuthUser> register({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = credential.user;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'NO_USER',
        message: 'Registro concluído sem usuário.',
      );
    }
    await _ensureUserDoc(user, role: 'user', overwriteRole: true);
    return _ensureAndFetch(user);
  }

  @override
  Future<AuthUser> signIn({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = credential.user;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'NO_USER',
        message: 'Usuário não encontrado após login.',
      );
    }
    return _ensureAndFetch(user);
  }

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Future<AuthUser?> getCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    return _ensureAndFetch(user);
  }

  Future<AuthUser> _ensureAndFetch(User user) async {
    await _ensureUserDoc(user);
    final doc = await _users.doc(user.uid).get();
    return AuthUser.fromMap(user.uid, doc.data());
  }

  Future<void> _ensureUserDoc(
    User user, {
    String role = 'user',
    bool overwriteRole = false,
  }) async {
    final docRef = _users.doc(user.uid);
    final snapshot = await docRef.get();
    final existingRole = snapshot.data()?['role'] as String?;
    final targetRole = overwriteRole ? role : (existingRole ?? role);
    final payload = <String, dynamic>{
      'email': user.email ?? '',
      'role': targetRole,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (!snapshot.exists) {
      payload['createdAt'] = FieldValue.serverTimestamp();
    }

    await docRef.set(payload, SetOptions(merge: true));
  }
}

class LocalAuthRepository implements AuthRepositoryContract {
  // Mock 'Admin' user for offline mode
  final _mockUser = const AuthUser(
    uid: 'local_admin_1',
    email: 'admin@offline.local',
    role: 'admin',
    createdAt: null,
  );

  bool _isLoggedIn = false;

  @override
  Stream<AuthUser?> authStateChanges() async* {
    // Emita o estado atual imediatamente
    yield _isLoggedIn ? _mockUser : null;
    // Em um app real, aqui ouviríamos um StreamController
  }

  @override
  Future<AuthUser?> getCurrentUser() async {
    return _isLoggedIn ? _mockUser : null;
  }

  @override
  Future<AuthUser> register({
    required String email,
    required String password,
  }) async {
    _isLoggedIn = true;
    return _mockUser;
  }

  @override
  Future<AuthUser> signIn({
    required String email,
    required String password,
  }) async {
    _isLoggedIn = true;
    return _mockUser;
  }

  @override
  Future<void> signOut() async {
    _isLoggedIn = false;
  }
}

// Provider Factory
final authRepositoryProvider = Provider<AuthRepositoryContract>((ref) {
  final backend = ref.watch(dataBackendProvider);

  if (backend == DataBackend.firestore || backend == DataBackend.hybrid) {
    // Check if Firebase is actually initialized to avoid crash
    if (FirebaseAuth.instance.app.options.apiKey == 'REPLACE') {
      return LocalAuthRepository();
    }
    return FirebaseAuthRepository();
  }

  return LocalAuthRepository();
});
