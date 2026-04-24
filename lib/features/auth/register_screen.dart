import 'dart:ui';
import 'package:catalogo_ja/ui/theme/app_tokens.dart';
import 'package:catalogo_ja/ui/widgets/app_gradient_button.dart';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [AppTokens.deepNavy, const Color(0xFF0A1128)]
                    : [const Color(0xFFF8FAFC), const Color(0xFFEFF6FF)],
              ),
            ),
          ),

          // Blobs
          if (isDark) ...[
            Positioned(
              top: -50,
              left: -100,
              child: _buildBlob(300, AppTokens.vibrantCyan.withOpacity(0.1)),
            ),
          ],

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Header
                        Center(
                          child: Hero(
                            tag: 'app_logo',
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withOpacity(0.03)
                                    : Colors.black.withOpacity(0.02),
                                shape: BoxShape.circle,
                              ),
                              child: Image.asset(
                                'assets/branding/logo/catalogoja_logo_master_2048x2048.png',
                                width: 120,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),

                        Text(
                          'Crie sua conta',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white : Colors.black87,
                            letterSpacing: -1,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Junte-se à plataforma mais moderna.',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? Colors.white54 : Colors.black45,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 40),

                        // Form Fields
                        _buildTextField(
                          controller: _emailController,
                          label: 'E-mail profissional',
                          icon: Icons.email_outlined,
                          isDark: isDark,
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
                          isDark: isDark,
                          obscureText: _obscurePassword,
                          suffixIcon: IconButton(
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                              size: 18,
                              color: isDark ? Colors.white38 : Colors.black38,
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
                          isDark: isDark,
                          obscureText: _obscureConfirmPassword,
                          suffixIcon: IconButton(
                            onPressed: () => setState(
                              () => _obscureConfirmPassword =
                                  !_obscureConfirmPassword,
                            ),
                            icon: Icon(
                              _obscureConfirmPassword
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                              size: 18,
                              color: isDark ? Colors.white38 : Colors.black38,
                            ),
                          ),
                          validator: (value) {
                            if (value != _passwordController.text) {
                              return 'As senhas não coincidem.';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 40),

                        AppGradientButton(
                          onPressed: _isSubmitting ? null : _submit,
                          isLoading: _isSubmitting,
                          label: 'FINALIZAR CADASTRO',
                          icon: Icons.person_add_alt_1_rounded,
                        ),

                        const SizedBox(height: 24),

                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(
                            'Já tenho uma conta. Voltar.',
                            style: TextStyle(
                              color: isDark ? Colors.white38 : Colors.black38,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlob(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
        child: Container(color: Colors.transparent),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isDark,
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
      style: TextStyle(
        color: isDark ? Colors.white : Colors.black87,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: isDark ? Colors.white38 : Colors.black38,
          fontSize: 14,
        ),
        prefixIcon: Icon(
          icon,
          size: 18,
          color: isDark ? AppTokens.vibrantCyan : AppTokens.electricBlue,
        ),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: (isDark ? Colors.white : Colors.black).withOpacity(0.04),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppTokens.electricBlue, width: 2),
        ),
      ),
    );
  }
}
