import 'package:catalogo_ja/ui/theme/app_tokens.dart';
import 'package:catalogo_ja/viewmodels/auth_viewmodel.dart';
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

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authViewModelProvider);
    final user = authState.valueOrNull;

    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Selecione a Empresa'),
        actions: [
          IconButton(
            onPressed: () => ref.read(authViewModelProvider.notifier).signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('users').doc(user.email!.toLowerCase().trim()).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting || _isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data?.data() as Map<String, dynamic>?;
          // Se o usuário já tiver uma lista de empresas, usamos ela. Caso contrário, mostramos a atual.
          final List<dynamic> tenantIds = data?['tenantIds'] ?? (data?['tenantId'] != null ? [data!['tenantId']] : []);

          if (tenantIds.isEmpty) {
            return _buildNoTenantView();
          }

          return ListView.builder(
            padding: const EdgeInsets.all(AppTokens.space16),
            itemCount: tenantIds.length,
            itemBuilder: (context, index) {
              final id = tenantIds[index];
              return _TenantTile(tenantId: id, onSelected: () => _selectTenant(id));
            },
          );
        },
      ),
    );
  }

  Widget _buildNoTenantView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.space24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.business_outlined, size: 64, color: AppTokens.accentBlue),
            const SizedBox(height: 16),
            const Text(
              'Nenhum catálogo vinculado.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Para visualizar seus produtos e fotos, insira o Código da Empresa fornecido pelo administrador.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _showJoinByCodeDialog,
                icon: const Icon(Icons.vpn_key_outlined),
                label: const Text('ENTRAR COM CÓDIGO DA EMPRESA'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showJoinByCodeDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Vincular Empresa'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Código da Empresa',
            hintText: 'ex: vitoriana_fabrica',
            border: OutlineInputBorder(),
          ),
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
      if (userEmail != null) {
        final emailDoc = userEmail.toLowerCase().trim();
        
        // Verifica se a empresa existe antes de vincular
        final tenantDoc = await FirebaseFirestore.instance.collection('tenants').doc(tenantId).get();
        if (!tenantDoc.exists) {
          throw Exception('A empresa com o código "$tenantId" não foi encontrada.');
        }

        // Adiciona à lista de tenantIds e define como ativa
        await FirebaseFirestore.instance.collection('users').doc(emailDoc).update({
          'tenantId': tenantId,
          'tenantIds': FieldValue.arrayUnion([tenantId]),
        });
        
        if (mounted) context.go('/admin/dashboard');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _selectTenant(String tenantId) async {
    setState(() => _isLoading = true);
    try {
      final userEmail = ref.read(authViewModelProvider).value?.email;
      if (userEmail != null) {
        await FirebaseFirestore.instance.collection('users').doc(userEmail.toLowerCase().trim()).update({
          'tenantId': tenantId,
        });
        
        if (mounted) context.go('/admin/dashboard');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao selecionar empresa: $e')),
        );
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
        final subtitle = data?['subtitle'] ?? tenantId;

        return Card(
          margin: const EdgeInsets.only(bottom: AppTokens.space12),
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.business)),
            title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(subtitle),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: onSelected,
          ),
        );
      },
    );
  }
}
