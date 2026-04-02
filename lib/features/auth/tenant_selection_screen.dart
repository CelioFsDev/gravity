import 'package:catalogo_ja/ui/theme/app_tokens.dart';
import 'package:catalogo_ja/viewmodels/auth_viewmodel.dart';
import 'package:catalogo_ja/core/auth/user_role.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TenantSelectionScreen extends ConsumerStatefulWidget {
  const TenantSelectionScreen({super.key});

  @override
  ConsumerState<TenantSelectionScreen> createState() => _TenantSelectionScreenState();
}

class _TenantSelectionScreenState extends ConsumerState<TenantSelectionScreen> {
  bool _isLoading = false;
  String _loadingMessage = 'Carregando...';

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authViewModelProvider);
    final user = authState.valueOrNull;

    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final isSuperAdmin = UserRole.superAdminEmails.contains(user.email!.toLowerCase().trim());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Catálogo SaaS - Acesso'),
        actions: [
          IconButton(
            onPressed: () => ref.read(authViewModelProvider.notifier).signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      floatingActionButton: isSuperAdmin ? FloatingActionButton.extended(
        onPressed: _syncWithCloud,
        backgroundColor: AppTokens.accentOrange,
        icon: const Icon(Icons.cloud_sync, color: Colors.white),
        label: const Text('SINCRONIZAR COM A NUVEM', 
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ) : null,
      body: Stack(
        children: [
          FutureBuilder<Map<String, dynamic>?>(
            future: _fetchUserAndTenants(user.email!.toLowerCase().trim()),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final data = snapshot.data;
              final List<String> tenantIds = List<String>.from(data?['tenantIds'] ?? []);
              final bool isSuperAdminRaw = data?['isSuperAdmin'] ?? false;

              if (tenantIds.isEmpty && !isSuperAdminRaw) {
                return _buildNoTenantView();
              }

              return StreamBuilder<QuerySnapshot>(
                stream: isSuperAdminRaw 
                  ? FirebaseFirestore.instance.collection('tenants').orderBy('name').snapshots()
                  : FirebaseFirestore.instance.collection('tenants')
                      .where(FieldPath.documentId, whereIn: tenantIds.isEmpty ? ['_placeholder'] : tenantIds)
                      .snapshots(),
                builder: (context, tenantSnapshot) {
                  if (tenantSnapshot.hasError) return Center(child: Text('Erro: ${tenantSnapshot.error}'));
                  if (!tenantSnapshot.hasData) return const Center(child: CircularProgressIndicator());
                  
                  final docs = tenantSnapshot.data!.docs;
                  
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          isSuperAdminRaw ? 'Painel Super Admin - Todas as Empresas' : 'Suas Empresas Vinculadas', 
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppTokens.accentBlue)),
                      ),
                      Expanded(
                        child: docs.isEmpty 
                          ? const Center(child: Text('Nenhuma empresa encontrada.'))
                          : ListView.builder(
                              padding: const EdgeInsets.all(AppTokens.space16),
                              itemCount: docs.length,
                              itemBuilder: (context, index) {
                                final id = docs[index].id;
                                return _TenantTile(tenantId: id, onSelected: () => _selectTenant(id));
                              },
                            ),
                      ),
                      if (docs.isEmpty && isSuperAdminRaw) Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: FilledButton.icon(
                          onPressed: () => _selectAndLinkTenant('vitoriana_fabrica'),
                          icon: const Icon(Icons.add_business),
                          label: const Text('CRIAR PRIMEIRA EMPRESA (VITORIANA)'),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: Center(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 24),
                        Text(_loadingMessage, style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        const Text('Isso pode levar alguns segundos...', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<Map<String, dynamic>?> _fetchUserAndTenants(String email) async {
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(email).get();
    final userData = userDoc.data();
    final isSuperAdmin = UserRole.superAdminEmails.contains(email);
    final List<dynamic> tenantIds = userData?['tenantIds'] ?? (userData?['tenantId'] != null ? [userData!['tenantId']] : []);

    return {
      'isSuperAdmin': isSuperAdmin,
      'tenantIds': tenantIds,
    };
  }

  Widget _buildNoTenantView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.space24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 64, color: AppTokens.accentBlue),
            const SizedBox(height: 16),
            const Text('Aguardando Sincronização.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const Text('Para baixar os produtos da sua empresa, clique no botão de Sincronização ou digite o código manual.',
              textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _showJoinByCodeDialog,
                icon: const Icon(Icons.vpn_key_outlined),
                label: const Text('DIGITAR CÓDIGO DA EMPRESA'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _syncWithCloud,
                icon: const Icon(Icons.cloud_sync_outlined),
                label: const Text('SINCRONIZAR COM A NUVEM ☁️'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _syncWithCloud() async {
    setState(() {
      _isLoading = true;
      _loadingMessage = 'Sincronizando com a Nuvem...';
    });
    
    try {
      final email = ref.read(authViewModelProvider).valueOrNull?.email;
      if (email == null) return;

      // Busca qualquer produto para identificar a empresa legado
      final query = await FirebaseFirestore.instance.collection('products').limit(1).get();
      
      if (query.docs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Nenhum dado encontrado na nuvem para sincronizar.')),
          );
        }
        return;
      }

      final foundTenantId = query.docs.first.data()['tenantId'] as String?;
      
      if (foundTenantId != null && mounted) {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Sincronização Cloud'),
            content: Text('Encontramos seu catálogo sob o código: "$foundTenantId".\nDeseja baixar todos os produtos e vincular sua conta agora?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCELAR')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('SIM, SINCRONIZAR')),
            ],
          ),
        );

        if (confirm == true) {
          setState(() => _loadingMessage = 'Puxando 1000+ produtos... 📥');
          await _selectAndLinkTenant(foundTenantId);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro na sincronização: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showJoinByCodeDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Vincular Código'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Código da Empresa', border: OutlineInputBorder()),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCELAR')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('VINCULAR')),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      _selectAndLinkTenant(result);
    }
  }

  Future<void> _selectAndLinkTenant(String tenantId) async {
    setState(() => _isLoading = true);
    try {
      final userEmail = ref.read(authViewModelProvider).value?.email;
      if (userEmail == null) return;
      final isSuperAdmin = UserRole.superAdminEmails.contains(userEmail.toLowerCase().trim());
      
      var tenantDoc = await FirebaseFirestore.instance.collection('tenants').doc(tenantId).get();
      
      if (!tenantDoc.exists && isSuperAdmin) {
        await FirebaseFirestore.instance.collection('tenants').doc(tenantId).set({
          'name': tenantId == 'vitoriana_fabrica' ? 'Empresa Vitoriana' : 'Empresa Sincronizada ($tenantId)',
          'id': tenantId,
          'createdAt': FieldValue.serverTimestamp(),
        });
        tenantDoc = await FirebaseFirestore.instance.collection('tenants').doc(tenantId).get();
      } else if (!tenantDoc.exists) {
        throw Exception('O código de empresa "$tenantId" não existe.');
      }

      final List<dynamic> stores = tenantDoc.data()?['stores'] ?? [];
      String? selectedStore;

      if (stores.isNotEmpty && mounted) {
        selectedStore = await showModalBottomSheet<String>(
          context: context,
          builder: (context) => Container(
            padding: const EdgeInsets.all(AppTokens.space16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Escolha a Unidade', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                ...stores.map((s) => ListTile(
                  leading: const Icon(Icons.store),
                  title: Text(s.toString()),
                  onTap: () => Navigator.pop(context, s.toString()),
                )),
              ],
            ),
          ),
        );
        if (selectedStore == null) return;
      }

      await FirebaseFirestore.instance.collection('users').doc(userEmail.toLowerCase().trim()).update({
        'tenantId': tenantId,
        'tenantIds': FieldValue.arrayUnion([tenantId]),
        'currentStoreId': selectedStore,
      });
      
      if (mounted) context.go('/admin/dashboard');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _selectTenant(String tenantId) async {
    setState(() => _isLoading = true);
    try {
      final userEmail = ref.read(authViewModelProvider).value?.email;
      if (userEmail == null) return;
      final tenantSnap = await FirebaseFirestore.instance.collection('tenants').doc(tenantId).get();
      final List<dynamic> stores = tenantSnap.data()?['stores'] ?? [];
      String? selectedStore;
      
      if (stores.isNotEmpty && mounted) {
        selectedStore = await showModalBottomSheet<String>(
          context: context,
          builder: (context) => Container(
            padding: const EdgeInsets.all(AppTokens.space16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Escolha a Unidade', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ...stores.map((s) => ListTile(
                  leading: const Icon(Icons.store),
                  title: Text(s.toString()),
                  onTap: () => Navigator.pop(context, s.toString()),
                )),
              ],
            ),
          ),
        );
        if (selectedStore == null) return;
      }

      await FirebaseFirestore.instance.collection('users').doc(userEmail.toLowerCase().trim()).update({
        'tenantId': tenantId,
        'currentStoreId': selectedStore,
      });
      if (mounted) context.go('/admin/dashboard');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

class _TenantTile extends StatelessWidget {
  final String tenantId;
  final VoidCallback onSelected;
  const _TenantTile({required this.tenantId, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('tenants').doc(tenantId).get(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() as Map<String, dynamic>?;
        final name = data?['name'] ?? 'Empresa Desconhecida';
        return Card(
          margin: const EdgeInsets.all(AppTokens.space8),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: AppTokens.accentBlue,
              child: Icon(Icons.business, color: Colors.white),
            ),
            title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('ID: $tenantId', style: const TextStyle(fontSize: 11)),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: onSelected,
          ),
        );
      },
    );
  }
}
