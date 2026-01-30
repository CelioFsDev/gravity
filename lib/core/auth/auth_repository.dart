import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_user.dart';

abstract class AuthRepositoryContract {
  Stream<AuthUser?> authStateChanges();
  Future<AuthUser> register({required String email, required String password});
  Future<AuthUser> signIn({required String email, required String password});
  Future<void> signOut();
  Future<AuthUser?> getCurrentUser();
}

class FirebaseAuthRepository implements AuthRepositoryContract {
  FirebaseAuthRepository({FirebaseAuth? auth, GoogleSignIn? googleSignIn})
    : _auth = auth ?? FirebaseAuth.instance,
      _googleSignIn = googleSignIn ?? GoogleSignIn();

  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;

  @override
  Stream<AuthUser?> authStateChanges() {
    return _auth.authStateChanges().map((firebaseUser) {
      if (firebaseUser == null) return null;
      return _userFromFirebase(firebaseUser);
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
    return _userFromFirebase(user);
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
    return _userFromFirebase(user);
  }

  Future<AuthUser> signInWithGoogle() async {
    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
    if (googleUser == null) {
      // User canceled the sign-in flow
      throw FirebaseAuthException(
        code: 'ABORTED',
        message: 'Login cancelado pelo usuário.',
      );
    }

    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;

    final AuthCredential credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final UserCredential userCredential = await _auth.signInWithCredential(
      credential,
    );
    final user = userCredential.user;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'NO_USER',
        message: 'Falha ao obter usuário Google.',
      );
    }
    return _userFromFirebase(user);
  }

  @override
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  @override
  Future<AuthUser?> getCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    return _userFromFirebase(user);
  }

  AuthUser _userFromFirebase(User user) {
    // Without Firestore, we default to 'admin' or 'user' based on local rules.
    // For now, allow everyone as admin to avoid lockout in this standalone app.
    return AuthUser(
      uid: user.uid,
      email: user.email ?? '',
      role: 'admin', // Defaulting to admin for offline/standalone usage
      createdAt: user.metadata.creationTime,
    );
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
  return FirebaseAuthRepository();
});

