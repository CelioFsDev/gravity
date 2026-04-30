import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:catalogo_ja/core/auth/user_role.dart';
import 'package:catalogo_ja/data/repositories/admin_user_account_repository.dart';
import 'package:catalogo_ja/ui/theme/app_tokens.dart';
import 'package:catalogo_ja/ui/widgets/app_scaffold.dart';
import 'package:catalogo_ja/ui/widgets/section_card.dart';
import 'package:catalogo_ja/viewmodels/auth_viewmodel.dart';
import 'package:catalogo_ja/viewmodels/tenant_viewmodel.dart';

class CreateEmailPasswordUserScreen extends ConsumerStatefulWidget {
  const CreateEmailPasswordUserScreen({super.key});

  @override
  ConsumerState<CreateEmailPasswordUserScreen> createState() =>
      _CreateEmailPasswordUserScreenState();
}

class _CreateEmailPasswordUserScreenState
    extends ConsumerState<CreateEmailPasswordUserScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  UserRole _selectedRole = UserRole.seller;
  bool _isSubmitting = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;
    final selectedRole = _safeSelectedRole();

    setState(() => _isSubmitting = true);

    try {
      final result = await ref
          .read(adminUserAccountRepositoryProvider)
          .createEmailPasswordUser(
            email: _emailController.text.trim().toLowerCase(),
            password: _passwordController.text,
            role: selectedRole.name,
            tenantId: ref.read(currentTenantProvider).valueOrNull?.id,
            storeId: ref.read(currentStoreIdProvider).valueOrNull,
          );

      _emailController.clear();
      _passwordController.clear();
      _confirmPasswordController.clear();
      setState(() => _selectedRole = UserRole.seller);

      if (!mounted) return;

      _showSuccessDialog(result.email, result.role);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_functionErrorMessage(error)),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showSuccessDialog(String email, String role) {
    final roleLabel = _labelForRole(role);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Usuário Criado'),
          ],
        ),
        content: Text(
          'O acesso para $email foi configurado com sucesso como $roleLabel.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(); // Volta para a tela anterior
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  String _labelForRole(String role) {
    return UserRole.values
        .firstWhere((item) => item.name == role, orElse: () => UserRole.viewer)
        .label;
  }

  bool _canAssignAdmin() {
    final currentEmail =
        ref.read(authViewModelProvider).valueOrNull?.email?.trim().toLowerCase();
    return UserRole.superAdminEmails.contains(currentEmail);
  }

  List<UserRole> _assignableRoles() {
    final canAssignAdmin = _canAssignAdmin();
    return UserRole.values
        .where((role) => canAssignAdmin || role != UserRole.admin)
        .toList();
  }

  UserRole _safeSelectedRole() {
    final assignableRoles = _assignableRoles();
    if (assignableRoles.contains(_selectedRole)) return _selectedRole;
    return assignableRoles.contains(UserRole.operator)
        ? UserRole.operator
        : UserRole.seller;
  }

  String _functionErrorMessage(Object error) {
    if (error is FirebaseFunctionsException) {
      switch (error.code) {
        case 'already-exists':
          return 'Já existe um login com esse email.';
        case 'invalid-argument':
          return error.message ?? 'Dados inválidos para criar o usuário.';
        case 'permission-denied':
          return 'Você não tem permissão para criar este usuário.';
        case 'unauthenticated':
          return 'Sua sessão expirou. Entre novamente.';
        default:
          return error.message ?? 'Erro ao criar usuário.';
      }
    }

    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'email-already-in-use':
          return 'J\u00e1 existe um login com esse email.';
        case 'invalid-email':
          return 'O formato do e-mail é inv\u00e1lido.';
        case 'weak-password':
          return 'A senha fornecida é muito fraca.';
        default:
          return error.message ?? 'Erro na autentica\u00e7\u00e3o.';
      }
    }

    if (error is FirebaseException) {
      if (error.code == 'permission-denied') {
        return 'Voc\u00ea não tem permiss\u00e3o para criar este usu\u00e1rio.';
      }
      return error.message ?? 'Erro no banco de dados.';
    }

    return 'Falha ao criar o usu\u00e1rio. Tente novamente.';
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(authViewModelProvider);
    final assignableRoles = _assignableRoles();
    final selectedRole = assignableRoles.contains(_selectedRole)
        ? _selectedRole
        : UserRole.seller;

    return AppScaffold(
      title: 'Novo Acesso',
      subtitle: 'Cadastrar usuário com email e senha',
      maxWidth: 600,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTokens.space24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionCard(
                title: 'Dados de Acesso',
                child: Column(
                  children: [
                    const Text(
                      'Este processo cria uma conta oficial no sistema. O usuário poderá logar imediatamente com as credenciais abaixo.',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    _buildTextField(
                      controller: _emailController,
                      label: 'E-mail',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        final email = value?.trim().toLowerCase() ?? '';
                        if (email.isEmpty || !email.contains('@')) {
                          return 'Informe um email válido.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<UserRole>(
                      initialValue: selectedRole,
                      decoration: InputDecoration(
                        labelText: 'Perfil de Acesso',
                        prefixIcon: const Icon(
                          Icons.admin_panel_settings_outlined,
                        ),
                        filled: true,
                        fillColor: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      items: assignableRoles.map((role) {
                        return DropdownMenuItem(
                          value: role,
                          child: Text(role.label),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _selectedRole = value);
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SectionCard(
                title: 'Segurança',
                child: Column(
                  children: [
                    _buildTextField(
                      controller: _passwordController,
                      label: 'Senha Temporária',
                      icon: Icons.lock_outline,
                      obscureText: _obscurePassword,
                      suffixIcon: IconButton(
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                      validator: (value) {
                        if ((value ?? '').length < 6) {
                          return 'A senha deve ter pelo menos 6 caracteres.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _confirmPasswordController,
                      label: 'Confirmar Senha',
                      icon: Icons.lock_reset_outlined,
                      obscureText: _obscureConfirmPassword,
                      suffixIcon: IconButton(
                        onPressed: () => setState(
                          () => _obscureConfirmPassword =
                              !_obscureConfirmPassword,
                        ),
                        icon: Icon(
                          _obscureConfirmPassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                      validator: (value) {
                        if (value != _passwordController.text) {
                          return 'As senhas não coincidem.';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                height: 56,
                child: FilledButton.icon(
                  onPressed: _isSubmitting ? null : _submit,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.person_add_alt_1_outlined),
                  label: Text(
                    _isSubmitting
                        ? 'CRIANDO CONTA...'
                        : 'CRIAR ACESSO DO USUÁRIO',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 2,
          ),
        ),
      ),
    );
  }
}
