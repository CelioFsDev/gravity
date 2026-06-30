import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:catalogo_ja/viewmodels/tenant_viewmodel.dart';
import 'package:catalogo_ja/data/repositories/user_repository.dart';
import 'package:catalogo_ja/viewmodels/auth_viewmodel.dart';
import 'package:go_router/go_router.dart';

class StorePickerPage extends ConsumerWidget {
  const StorePickerPage({super.key});

  Future<void> _selectStore(
    BuildContext context,
    WidgetRef ref,
    String storeId,
  ) async {
    final user = ref.read(authViewModelProvider).value;
    if (user == null || user.email == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Selecionando loja...')),
    );

    await ref.read(userRepositoryProvider).updateUserData(user.email!, {
      'currentStoreId': storeId,
    });

    try {
      await Future.doWhile(() async {
        await Future.delayed(const Duration(milliseconds: 50));
        final currentStore = ref.read(currentStoreIdProvider).asData?.value;
        return currentStore != storeId;
      }).timeout(const Duration(seconds: 3));
    } catch (_) {}

    if (context.mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      context.go('/admin/dashboard');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantAsync = ref.watch(currentTenantProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Selecione uma Loja'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/picker'),
        ),
      ),
      body: tenantAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) =>
            Center(child: Text('Erro ao carregar dados: $err')),
        data: (tenant) {
          if (tenant == null) {
            return Center(
              child: ElevatedButton(
                onPressed: () => context.go('/picker'),
                child: const Text('Voltar para seleção de empresa'),
              ),
            );
          }

          if (tenant.stores.isEmpty) {
            return Center(
              child: Text(
                'Nenhuma loja encontrada para ${tenant.name}.',
                style: const TextStyle(fontSize: 16),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: tenant.stores.length,
            itemBuilder: (context, index) {
              final storeId = tenant.stores[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                elevation: 2,
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(
                      context,
                    ).primaryColor.withValues(alpha: 0.1),
                    child: const Icon(Icons.storefront),
                  ),
                  title: Text(
                    storeId,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _selectStore(context, ref, storeId),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
