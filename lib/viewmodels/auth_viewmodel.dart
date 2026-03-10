import 'package:firebase_auth/firebase_auth.dart';
import 'package:catalogo_ja/data/repositories/auth_repository.dart';
import 'package:catalogo_ja/core/services/app_logger.dart';
import 'package:catalogo_ja/data/repositories/user_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AuthViewModel extends StreamNotifier<User?> {
  late AuthRepository _repository;
  late AppLogger _logger;
  late UserRepository _userRepository;

  @override
  Stream<User?> build() {
    _repository = ref.watch(authRepositoryProvider);
    _logger = ref.watch(appLoggerProvider.notifier);
    _userRepository = ref.watch(userRepositoryProvider);
    return _repository.authStateChanges.asyncMap((user) async {
      if (user?.email != null) {
        try {
          await _syncUserProfile(user!);
        } catch (e, stack) {
          _logger.logError(
            'Erro ao sincronizar perfil do usuario no Firestore',
            error: e,
            stackTrace: stack,
          );
        }
      }
      return user;
    });
  }

  Future<void> _syncUserProfile(User user) {
    return _userRepository.ensureUserProfileFromAuth(user);
  }

  Future<void> signInWithGoogle() async {
    state = const AsyncValue.loading();
    try {
      final credential = await _repository.signInWithGoogle();
      final user = credential.user;

      if (user != null) {
        await _syncUserProfile(user);
        _logger.log(
          AppEvent.login,
          parameters: {'uid': user.uid, 'email': user.email},
        );
      }

      // Riverpod will automatically update state from authStateChanges stream
    } catch (e, stack) {
      _logger.logError('Erro no login com Google', error: e, stackTrace: stack);
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> signInWithEmailAndPassword(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      final credential = await _repository.signInWithEmailAndPassword(
        email,
        password,
      );
      final user = credential.user;

      if (user != null) {
        await _syncUserProfile(user);
        _logger.log(
          AppEvent.login,
          parameters: {
            'uid': user.uid,
            'email': user.email,
            'provider': 'password',
          },
        );
      }
    } catch (e, stack) {
      _logger.logError(
        'Erro no login com email e senha',
        error: e,
        stackTrace: stack,
      );
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> signUpWithEmailAndPassword(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      final credential = await _repository.signUpWithEmailAndPassword(
        email,
        password,
      );
      final user = credential.user;

      if (user != null) {
        try {
          await _syncUserProfile(user);
        } catch (e, stack) {
          _logger.logError(
            'Erro ao criar perfil do usuario no Firestore apos cadastro',
            error: e,
            stackTrace: stack,
          );
          await _repository.signOut();
          state = AsyncValue.error(e, stack);
          rethrow;
        }

        _logger.log(
          AppEvent.registration,
          parameters: {
            'uid': user.uid,
            'email': user.email,
            'provider': 'password',
          },
        );
      }
    } catch (e, stack) {
      _logger.logError(
        'Erro no cadastro com email e senha',
        error: e,
        stackTrace: stack,
      );
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      await _repository.signOut();
      _logger.log(AppEvent.logout);
    } catch (e, stack) {
      _logger.logError('Erro ao deslogar', error: e, stackTrace: stack);
    }
  }
}

final authViewModelProvider = StreamNotifierProvider<AuthViewModel, User?>(() {
  return AuthViewModel();
});
