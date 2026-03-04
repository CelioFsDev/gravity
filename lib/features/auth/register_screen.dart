import 'package:catalogo_ja/ui/theme/app_tokens.dart';
import 'package:catalogo_ja/ui/widgets/app_scaffold.dart';
import 'package:catalogo_ja/ui/widgets/section_card.dart';
import 'package:catalogo_ja/viewmodels/auth_viewmodel.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PublicRegisterScreen extends ConsumerStatefulWidget {
  const PublicRegisterScreen({super.key});

  @override
  ConsumerState<PublicRegisterScreen> createState() =>
      _PublicRegisterScreenState();
}

class _PublicRegisterScreenState extends ConsumerState<PublicRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

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

    setState(() => _isSubmitting = true);

    try {
      await ref
          .read(authViewModelProvider.notifier)
          .signUpWithEmailAndPassword(
            _emailController.text.trim().toLowerCase(),
            _passwordController.text,
          );

      if (!mounted) return;

      // Auto-login happens via ViewModel stream, so we just wait
      // or show a brief message if needed.
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_authErrorMessage(error)),
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

  String _authErrorMessage(Object error) {
    if (error is! FirebaseAuthException) {
      return 'Falha ao criar conta. Tente novamente.';
    }

    switch (error.code) {
      case 'email-already-in-use':
        return 'Este e-mail já está em uso.';
      case 'invalid-email':
        return 'E-mail inválido.';
      case 'operation-not-allowed':
        return 'Cadastro por e-mail desativado.';
      case 'weak-password':
        return 'A senha é muito fraca.';
      default:
        return error.message ?? 'Falha ao realizar cadastro.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Criar Conta',
      subtitle: 'Cadastre seu e-mail e senha',
      maxWidth: 600,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTokens.space24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionCard(
                title: 'Dados Acadastrais',
                child: Column(
                  children: [
                    const Text(
                      'Preencha as informações abaixo para criar seu acesso ao sistema.',
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
                    _buildTextField(
                      controller: _passwordController,
                      label: 'Senha',
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
                    _isSubmitting ? 'CRIANDO CONTA...' : 'FINALIZAR CADASTRO',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Já tenho uma conta. Voltar para login.'),
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
