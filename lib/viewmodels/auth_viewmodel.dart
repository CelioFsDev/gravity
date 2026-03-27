import 'package:firebase_auth/firebase_auth.dart';
import 'package:catalogo_ja/data/repositories/auth_repository.dart';
import 'package:catalogo_ja/core/services/app_logger.dart';
import 'package:catalogo_ja/data/repositories/user_repository.dart';
import 'package:catalogo_ja/data/repositories/products_repository.dart';
import 'package:catalogo_ja/data/repositories/categories_repository.dart';
import 'package:catalogo_ja/data/repositories/catalogs_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:catalogo_ja/viewmodels/tenant_viewmodel.dart';
import 'package:catalogo_ja/viewmodels/categories_viewmodel.dart';
import 'package:catalogo_ja/viewmodels/catalogs_viewmodel.dart';
import 'package:catalogo_ja/viewmodels/products_viewmodel.dart';

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

  Future<void> _syncUserProfile(User user) async {
    await _userRepository.ensureUserProfileFromAuth(user);
    
    // ✨ SaaS Sync: Após garantir o perfil, disparamos o download dos dados da nuvem
    // Isso evita que o celular fique "zerado" depois de um logout/login.
    _triggerInitialDataDownload();
  }

  void _triggerInitialDataDownload() async {
    try {
      // Aguarda o tenant ser carregado (o que acontece logo após o ensureUserProfile sincronizar o Firestore)
      final tenant = await ref.read(currentTenantProvider.future);
      if (tenant != null) {
        // Iniciamos o download em background. 
        // Os métodos syncFromCloud já lidam com o estado de progresso se o usuário abrir as telas.
        ref.read(categoriesViewModelProvider.notifier).syncFromCloud();
        ref.read(productsViewModelProvider.notifier).syncFromCloud();
        ref.read(catalogsViewModelProvider.notifier).syncFromCloud();
      }
    } catch (e) {
      _logger.logError('Erro no disparo do download inicial', error: e);
    }
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
      // ✨ LIMPEZA SAAS: Apaga dados locais para não misturar catálogos de usuários diferentes
      final productsRepo = ref.read(productsRepositoryProvider);
      final categoriesRepo = ref.read(categoriesRepositoryProvider);
      final catalogsRepo = ref.read(catalogsRepositoryProvider);

      await productsRepo.clearAll();
      await categoriesRepo.clearAll();
      await catalogsRepo.clearAll();

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
