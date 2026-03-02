import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract class AuthRepository {
  Stream<User?> get authStateChanges;
  User? get currentUser;
  Future<UserCredential> signInWithGoogle();
  Future<void> signOut();
}

class FirebaseAuthRepository implements AuthRepository {
  static const String _serverClientId =
      '866110171338-oduvj84jpmdlgdmsglh23tjj5ctce9jv.apps.googleusercontent.com';

  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _initialized = false;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;

    await GoogleSignIn.instance.initialize(
      serverClientId: _serverClientId,
    );
    _initialized = true;
  }

  @override
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  @override
  User? get currentUser => _auth.currentUser;

  @override
  Future<UserCredential> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        final provider = GoogleAuthProvider();
        provider.addScope('email');
        provider.addScope('profile');
        return await _auth.signInWithPopup(provider);
      }

      await _ensureInitialized();

      final googleUser = await GoogleSignIn.instance.authenticate();
      final googleAuth = googleUser.authentication;
      final idToken = googleAuth.idToken;

      if (idToken == null) {
        throw StateError('Google Sign-In nao retornou um ID token valido.');
      }

      final credential = GoogleAuthProvider.credential(idToken: idToken);
      return _auth.signInWithCredential(credential);
    } catch (e) {
      debugPrint('ERRO NO GOOGLE SIGN-IN: $e');
      rethrow;
    }
  }

  @override
  Future<void> signOut() async {
    if (!kIsWeb) {
      await GoogleSignIn.instance.signOut();
    }
    await _auth.signOut();
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return FirebaseAuthRepository();
});
