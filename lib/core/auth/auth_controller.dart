import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_repository.dart';
import 'auth_user.dart';

// Providers are now in auth_repository.dart or global config

final authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<AuthUser?>>(
      (ref) => AuthController(ref),
    );

final currentUserProvider = Provider<AuthUser?>(
  (ref) => ref.watch(authControllerProvider).value,
);

class AuthController extends StateNotifier<AsyncValue<AuthUser?>> {
  AuthController(this._ref) : super(const AsyncValue.loading()) {
    _listenToAuth();
  }

  final Ref _ref;
  StreamSubscription<AuthUser?>? _subscription;

  void _listenToAuth() {
    _subscription = _ref
        .read(authRepositoryProvider)
        .authStateChanges()
        .listen((user) => state = AsyncValue.data(user));
  }

  Future<void> signIn({required String email, required String password}) async {
    state = const AsyncValue.loading();
    try {
      final user = await _ref
          .read(authRepositoryProvider)
          .signIn(email: email, password: password);
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> register({
    required String email,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    try {
      final user = await _ref
          .read(authRepositoryProvider)
          .register(email: email, password: password);
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _ref.read(authRepositoryProvider).signOut();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
