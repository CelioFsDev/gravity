import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:catalogo_ja/viewmodels/tenant_viewmodel.dart';
import 'package:catalogo_ja/data/repositories/user_repository.dart';
import 'package:catalogo_ja/viewmodels/auth_viewmodel.dart';
import 'package:go_router/go_router.dart';

class TenantPickerPage extends ConsumerWidget {
  const TenantPickerPage({super.key});

  Future<void> _selectTenant(BuildContext context, WidgetRef ref, String tenantId) async {
    final user = ref.read(authViewModelProvider).value;
    if (user == null || user.email == null) return;
    
    // Atualiza o documento do user para setar o tenant atual que ele escolheu
    await ref.read(userRepositoryProvider).updateUserData(user.email!, {
      'tenantId': tenantId,
    });
    
    // Limpa o cache para forçar recarregamento na home
    ref.read(tenantRepositoryProvider).clearTenantCache();
    
    if (context.mounted) {
      context.go('/dashboard');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantsAsync = ref.watch(userTenantsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Selecione uma Empresa'),
        centerTitle: true,
      ),
      body: tenantsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Erro ao carregar empresas: $err')),
        data: (tenants) {
          if (tenants.isEmpty) {
            return Center(
              child: ElevatedButton(
                onPressed: () => context.go('/onboarding'), 
                child: const Text('Criar Nova Empresa')
              )
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
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                    child: Text(tenant.name.substring(0, 1).toUpperCase()),
                  ),
                  title: Text(tenant.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${tenant.stores.length} loja(s) vinculada(s)'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _selectTenant(context, ref, tenant.id),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
