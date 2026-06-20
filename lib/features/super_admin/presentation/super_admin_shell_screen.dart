import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:catalogo_ja/features/super_admin/data/super_admin_repository.dart';
import 'package:catalogo_ja/models/tenant.dart';
import 'package:go_router/go_router.dart';
import 'package:catalogo_ja/viewmodels/tenant_viewmodel.dart';
import 'package:catalogo_ja/data/repositories/tenant_repository.dart';
import 'package:catalogo_ja/data/repositories/user_repository.dart';
import 'package:catalogo_ja/viewmodels/auth_viewmodel.dart';

final adminTenantsProvider = StreamProvider<List<Tenant>>((ref) {
  return ref.watch(superAdminRepositoryProvider).getAllTenantsStream();
});

final adminUsersProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(superAdminRepositoryProvider).getAllUsersStream();
});

class SuperAdminShellScreen extends StatefulWidget {
  const SuperAdminShellScreen({super.key});

  @override
  State<SuperAdminShellScreen> createState() => _SuperAdminShellScreenState();
}

class _SuperAdminShellScreenState extends State<SuperAdminShellScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          _DashboardTab(),
          _TenantsTab(),
          _UsersTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard), label: 'Resumo'),
          NavigationDestination(icon: Icon(Icons.business), label: 'Empresas'),
          NavigationDestination(icon: Icon(Icons.people), label: 'Usuários'),
        ],
      ),
    );
  }
}

class _DashboardTab extends ConsumerWidget {
  const _DashboardTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantsAsync = ref.watch(adminTenantsProvider);
    final usersAsync = ref.watch(adminUsersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Painel Global (Super Admin)'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
      ),
      body: tenantsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Erro: $e')),
        data: (tenants) {
          final totalTenants = tenants.length;
          final blockedTenants = tenants.where((t) => t.metadata['isBlocked'] == true).length;
          final activeTenants = totalTenants - blockedTenants;

          return usersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Center(child: Text('Erro usuários: $e')),
            data: (users) {
              final totalUsers = users.length;
              final blockedUsers = users.where((u) => u['disabled'] == true).length;

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildMetricCard('Empresas (Tenants)', totalTenants.toString(), Colors.blue),
                  _buildMetricCard('Empresas Ativas', activeTenants.toString(), Colors.green),
                  _buildMetricCard('Empresas Bloqueadas', blockedTenants.toString(), Colors.red),
                  _buildMetricCard('Total de Usuários', totalUsers.toString(), Colors.purple),
                  _buildMetricCard('Usuários Bloqueados', blockedUsers.toString(), Colors.orange),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, Color color) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: color, radius: 8),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        trailing: Text(value, style: TextStyle(fontSize: 24, color: color, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class _TenantsTab extends ConsumerWidget {
  const _TenantsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantsAsync = ref.watch(adminTenantsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Gerenciar Empresas')),
      body: tenantsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Erro: $e')),
        data: (tenants) {
          if (tenants.isEmpty) return const Center(child: Text('Nenhuma empresa encontrada.'));
          return ListView.builder(
            itemCount: tenants.length,
            itemBuilder: (context, index) {
              final tenant = tenants[index];
              final isBlocked = tenant.metadata['isBlocked'] == true;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text(tenant.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('ID: ${tenant.id} | Lojas: ${tenant.stores.length}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.login),
                        tooltip: 'Acessar Empresa',
                        onPressed: () async {
                          // Impersonate
                          final user = ref.read(authViewModelProvider).valueOrNull;
                          final email = user?.email ?? 'celiodev@gmail.com';
                          final storeId = tenant.stores.isNotEmpty ? tenant.stores.first : '';
                          
                          await ref.read(userRepositoryProvider).updateUserData(
                            email,
                            {'tenantId': tenant.id, 'currentStoreId': storeId}
                          );
                          ref.invalidate(currentTenantProvider);
                          ref.read(tenantRepositoryProvider).clearTenantCache();
                          if (context.mounted) {
                             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Acessando empresa...')));
                             context.go('/');
                          }
                        },
                      ),
                      Switch(
                        value: !isBlocked,
                        activeColor: Colors.green,
                        inactiveThumbColor: Colors.red,
                        onChanged: (val) {
                          ref.read(superAdminRepositoryProvider).toggleTenantBlock(tenant.id, !val);
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _UsersTab extends ConsumerStatefulWidget {
  const _UsersTab();
  @override
  ConsumerState<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends ConsumerState<_UsersTab> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(adminUsersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gerenciar Usuários'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Filtrar por email, nome ou empresa...',
                filled: true,
                fillColor: Theme.of(context).cardColor,
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
            ),
          ),
        ),
      ),
      body: usersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Erro: $e')),
        data: (users) {
          final filtered = users.where((u) {
            final email = (u['email'] as String? ?? '').toLowerCase();
            final name = (u['displayName'] as String? ?? '').toLowerCase();
            final tenantIds = (u['tenantIds'] as List<dynamic>? ?? []).join(' ').toLowerCase();
            return email.contains(_searchQuery) || name.contains(_searchQuery) || tenantIds.contains(_searchQuery);
          }).toList();

          if (filtered.isEmpty) return const Center(child: Text('Nenhum usuário encontrado.'));

          return ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final user = filtered[index];
              final email = user['email'] as String? ?? 'Sem email';
              final isBlocked = user['disabled'] == true;
              final role = user['role'] as String? ?? 'viewer';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text(email, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Role: $role | Empresa Atual: ${user['tenantId'] ?? 'Nenhuma'}'),
                  trailing: Switch(
                    value: !isBlocked,
                    activeColor: Colors.green,
                    inactiveThumbColor: Colors.red,
                    onChanged: (val) {
                      ref.read(superAdminRepositoryProvider).toggleUserBlock(email, !val);
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
