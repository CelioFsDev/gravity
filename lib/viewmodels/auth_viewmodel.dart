import 'package:firebase_auth/firebase_auth.dart';
import 'package:catalogo_ja/data/repositories/auth_repository.dart';
import 'package:catalogo_ja/core/services/app_logger.dart';
import 'package:catalogo_ja/data/repositories/user_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:catalogo_ja/viewmodels/tenant_viewmodel.dart';
import 'package:catalogo_ja/data/repositories/tenant_repository.dart';
import 'package:catalogo_ja/viewmodels/categories_viewmodel.dart';
import 'package:catalogo_ja/viewmodels/catalogs_viewmodel.dart';
import 'package:catalogo_ja/viewmodels/products_viewmodel.dart';
import 'package:hive_flutter/hive_flutter.dart';

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

  Future<bool> _shouldSync(
    String key, {
    Duration maxAge = const Duration(hours: 4),
  }) async {
    final box = await Hive.openBox('sync_meta');
    final lastSyncMs = box.get('last_sync_$key') as int?;
    if (lastSyncMs == null) return true;
    final lastSync = DateTime.fromMillisecondsSinceEpoch(lastSyncMs);
    return DateTime.now().difference(lastSync) > maxAge;
  }

  void _triggerInitialDataDownload() async {
    try {
      if (kDebugMode) {
        debugPrint(
          '🚀 [AppLogger] Checando necessidades de sync de dados após login...',
        );
      }

      await Future.delayed(const Duration(seconds: 1));

      var tenant = await ref.read(currentTenantProvider.future);

      if (tenant == null) {
        if (kDebugMode) {
          debugPrint(
            '⚠️ [AppLogger] Tenant não encontrado no primeiro segundo. Tentando novamente...',
          );
        }
        await Future.delayed(const Duration(seconds: 2));
        tenant = await ref.read(currentTenantProvider.future);
      }

      if (tenant != null) {
        final shouldSyncCategories = await _shouldSync('categories');
        final shouldSyncProducts = await _shouldSync('products');
        final shouldSyncCatalogs = await _shouldSync('catalogs');

        if (kDebugMode) {
          debugPrint(
            '🚀 [AppLogger] Empresa (Tenant) identificada: ${tenant.id}. Sync pendente: Cat:$shouldSyncCategories Prod:$shouldSyncProducts Cata:$shouldSyncCatalogs',
          );
        }

        await Future.wait([
          if (shouldSyncCategories)
            ref.read(categoriesViewModelProvider.notifier).syncFromCloud(),
          if (shouldSyncProducts)
            ref.read(productsViewModelProvider.notifier).syncFromCloud(),
          if (shouldSyncCatalogs)
            ref.read(catalogsViewModelProvider.notifier).syncFromCloud(),
        ]);
      } else {
        _logger.logError(
          'Não foi possível identificar a empresa vinculada a este usuário após o login.',
        );
      }
    } catch (e) {
      _logger.logError('Erro crítico no disparo do download inicial', error: e);
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
      // ✨ LOCAL-FIRST: Dados mantidos no cache (Local) para evitar re-downloads.
      // O filtro de segurança por TenantId será feito nos próprios Repositórios Locais.

      // 🔑 Reseta o guard de sessão para que o próximo login execute normalmente
      UserRepository.resetSession();

      // 🔑 Limpa o cache do TenantId para evitar conflito se outro user logar
      ref.read(tenantRepositoryProvider).clearTenantCache();

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
