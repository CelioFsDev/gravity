import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:catalogo_ja/data/repositories/tenant_repository.dart';
import 'package:catalogo_ja/viewmodels/auth_viewmodel.dart';
import 'package:go_router/go_router.dart';

class TenantOnboardingPage extends ConsumerStatefulWidget {
  const TenantOnboardingPage({super.key});

  @override
  ConsumerState<TenantOnboardingPage> createState() => _TenantOnboardingPageState();
}

class _TenantOnboardingPageState extends ConsumerState<TenantOnboardingPage> {
  final _formKey = GlobalKey<FormState>();
  final _companyController = TextEditingController();
  final _storeController = TextEditingController();
  bool _isLoading = false;

  Future<void> _createCompany() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = ref.read(authViewModelProvider).value;
      if (user == null || user.email == null) throw Exception("Usuário não logado");

      final repo = ref.read(tenantRepositoryProvider);
      await repo.createTenantWithStore(
        companyName: _companyController.text,
        storeName: _storeController.text,
        adminEmail: user.email!,
      );

      if (mounted) {
        context.go('/admin/dashboard'); // Ajuste de acordo com a sua rota principal
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao criar empresa: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bem-vindo ao Catálogo Já'),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.storefront, size: 80, color: Colors.blue),
              const SizedBox(height: 24),
              const Text(
                'Parece que você ainda não pertence a nenhuma empresa no sistema.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 32),
              
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Crie sua nova Empresa',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _companyController,
                          decoration: const InputDecoration(
                            labelText: 'Nome da Empresa',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.business),
                          ),
                          validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _storeController,
                          decoration: const InputDecoration(
                            labelText: 'Nome da Loja / Unidade',
                            hintText: 'Ex: Matriz, Filial Centro',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.store),
                          ),
                          validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _isLoading ? null : _createCompany,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: _isLoading 
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text('Criar Minha Empresa', style: TextStyle(fontSize: 16)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              const Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('OU'),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 24),
              
              OutlinedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) {
                      final joinController = TextEditingController();
                      bool isJoining = false;
                      
                      return StatefulBuilder(
                        builder: (context, setDialogState) {
                          return AlertDialog(
                            title: const Text('Entrar em uma Empresa'),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'Solicite ao administrador da sua loja o "ID da Empresa" e digite abaixo.',
                                  style: TextStyle(fontSize: 14),
                                ),
                                const SizedBox(height: 16),
                                TextField(
                                  controller: joinController,
                                  decoration: const InputDecoration(
                                    labelText: 'ID da Empresa',
                                    hintText: 'Ex: minha-loja-123',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: isJoining ? null : () => Navigator.pop(ctx),
                                child: const Text('Cancelar'),
                              ),
                              ElevatedButton(
                                onPressed: isJoining ? null : () async {
                                  final tid = joinController.text.trim();
                                  if (tid.isEmpty) return;

                                  setDialogState(() => isJoining = true);
                                  
                                  try {
                                    final user = ref.read(authViewModelProvider).value;
                                    if (user == null || user.email == null) throw Exception("Não logado");
                                    
                                    await ref.read(tenantRepositoryProvider).joinTenant(
                                      tenantId: tid,
                                      email: user.email!,
                                    );
                                    
                                    if (ctx.mounted) {
                                      Navigator.pop(ctx);
                                      context.go('/admin/dashboard');
                                    }
                                  } catch (e) {
                                    if (ctx.mounted) {
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                        SnackBar(content: Text('Erro: $e')),
                                      );
                                    }
                                    setDialogState(() => isJoining = false);
                                  }
                                },
                                child: isJoining 
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Text('Entrar'),
                              ),
                            ],
                          );
                        }
                      );
                    }
                  );
                },
                icon: const Icon(Icons.group_add),
                label: const Text('Entrar em empresa existente (Usar ID)'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
