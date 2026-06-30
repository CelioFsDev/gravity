import 'dart:async';

import 'package:catalogo_ja/data/repositories/tenant_repository.dart';
import 'package:catalogo_ja/data/repositories/user_repository.dart';
import 'package:catalogo_ja/models/tenant.dart';
import 'package:catalogo_ja/viewmodels/active_session_viewmodel.dart';
import 'package:catalogo_ja/viewmodels/auth_viewmodel.dart';
import 'package:catalogo_ja/viewmodels/tenant_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class TenantPickerPage extends ConsumerStatefulWidget {
  const TenantPickerPage({super.key});

  @override
  ConsumerState<TenantPickerPage> createState() => _TenantPickerPageState();
}

class _TenantPickerPageState extends ConsumerState<TenantPickerPage> {
  static const _pickerStepTimeout = Duration(seconds: 3);

  bool _isSelecting = false;
  Tenant? _lastTenant;
  String? _openErrorMessage;

  Future<void> _selectTenantAndContinue(
    Tenant tenant, {
    required bool testMode,
  }) async {
    if (_isSelecting) return;

    setState(() {
      _isSelecting = true;
      _lastTenant = tenant;
      _openErrorMessage = null;
    });

    var didNavigate = false;
    final messenger = ScaffoldMessenger.of(context);

    try {
      if (testMode) {
        debugPrint('[TESTE 1] botão modo teste clicado');
        debugPrint('[TESTE 2] usuário atual encontrado');
        debugPrint('[TESTE 3] tenantId usado: ${tenant.id}');
      } else {
        debugPrint('[1 PICKER] clique na empresa');
        debugPrint('[2 PICKER] tenantId recebido: ${tenant.id}');
      }

      final user = ref.read(authViewModelProvider).asData?.value;
      final email = user?.email?.trim().toLowerCase();
      if (user == null || email == null || email.isEmpty) {
        throw Exception('Usuario nao autenticado.');
      }

      messenger.showSnackBar(
        const SnackBar(content: Text('Selecionando empresa...')),
      );

      final sessionController = ref.read(activeSessionProvider.notifier);

      if (testMode) debugPrint('[TESTE 4] salvando tenant na sessão central');
      await sessionController
          .setActiveTenant(
            userId: user.uid,
            email: email,
            tenantId: tenant.id,
            tenantName: tenant.name,
            storeId: null,
            storeName: 'Matriz',
          )
          .timeout(_pickerStepTimeout);
      if (testMode) debugPrint('[TESTE 5] tenant salvo');
      if (testMode) debugPrint('[TESTE 6] salvando store como null/matriz');
      if (testMode) debugPrint('[TESTE 7] sessão pronta');

      if (!testMode) {
        _saveTenantRemotely(email: email, tenant: tenant);
      }

      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      if (testMode) {
        debugPrint("[TESTE 8] chamando context.go('/admin/dashboard')");
      }
      didNavigate = true;
      context.go('/admin/dashboard');
    } catch (error, stackTrace) {
      if (testMode) {
        debugPrint('[TESTE ERRO] exception: $error');
        debugPrint('[TESTE ERRO] stack: $stackTrace');
      }
      debugPrint('[PICKER] Erro ao abrir dashboard: $error');
      debugPrint(stackTrace.toString());
      if (mounted) {
        setState(() {
          _openErrorMessage = 'Erro ao abrir painel: $error\nStack trace (resumo): ${stackTrace.toString().split('\n').take(3).join('\n')}';
        });
      }
    } finally {
      if (mounted && !didNavigate) {
        messenger.hideCurrentSnackBar();
        setState(() {
          _isSelecting = false;
        });
      }
    }
  }

  void _saveTenantRemotely({
    required String email,
    required Tenant tenant,
  }) {
    final updates = <String, dynamic>{
      'tenantId': tenant.id,
      'currentStoreId': null,
    };

    unawaited(
      ref
          .read(userRepositoryProvider)
          .updateUserData(email, updates)
          .timeout(_pickerStepTimeout)
          .then<void>((_) {
            debugPrint('[PICKER] Tenant salvo remotamente em background');
            ref.read(tenantRepositoryProvider).clearTenantCache();
          })
          .catchError((Object error) {
            debugPrint(
              '[PICKER] Erro ao salvar remotamente; sess\u00e3o local mantida: $error',
            );
          }),
    );
  }

  Future<void> _signOut() async {
    await ref.read(authViewModelProvider.notifier).signOut();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final tenantsAsync = ref.watch(userTenantsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Selecione uma Empresa'),
        centerTitle: true,
      ),
      body: tenantsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) =>
            Center(child: Text('Erro ao carregar empresas: $err')),
        data: (tenants) {
          if (_openErrorMessage != null) {
            return _PickerOpenErrorView(
              message: _openErrorMessage!,
              canRetry: _lastTenant != null && !_isSelecting,
              isLoading: _isSelecting,
              onRetry: _lastTenant == null
                  ? null
                  : () => _selectTenantAndContinue(
                        _lastTenant!,
                        testMode: false,
                      ),
              onTestMode: _lastTenant == null
                  ? null
                  : () => _selectTenantAndContinue(
                        _lastTenant!,
                        testMode: true,
                      ),
              onSignOut: _signOut,
            );
          }

          if (tenants.isEmpty) {
            return Center(
              child: ElevatedButton(
                onPressed: () => context.go('/onboarding'),
                child: const Text('Criar Nova Empresa'),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: tenants.length,
            itemBuilder: (context, index) {
              final tenant = tenants[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                elevation: 2,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(
                          context,
                        ).primaryColor.withValues(alpha: 0.1),
                        child: Text(tenant.name.substring(0, 1).toUpperCase()),
                      ),
                      title: Text(
                        tenant.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '${tenant.stores.length} loja(s) vinculada(s)',
                      ),
                      trailing: _isSelecting
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.chevron_right),
                      onTap: _isSelecting
                          ? null
                          : () => _selectTenantAndContinue(
                                tenant,
                                testMode: false,
                              ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _isSelecting
                              ? null
                              : () => _selectTenantAndContinue(
                                    tenant,
                                    testMode: true,
                                  ),
                          icon: const Icon(Icons.bolt_outlined),
                          label: const Text('Entrar modo teste'),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _PickerOpenErrorView extends StatelessWidget {
  const _PickerOpenErrorView({
    required this.message,
    required this.canRetry,
    required this.isLoading,
    required this.onRetry,
    required this.onTestMode,
    required this.onSignOut,
  });

  final String message;
  final bool canRetry;
  final bool isLoading;
  final VoidCallback? onRetry;
  final VoidCallback? onTestMode;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: canRetry ? onRetry : null,
              child: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Tentar novamente'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: canRetry ? onTestMode : null,
              child: const Text('Entrar modo teste'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: isLoading ? null : onSignOut,
              child: const Text('Sair'),
            ),
          ],
        ),
      ),
    );
  }
}
