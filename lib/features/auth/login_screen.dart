import 'dart:ui';
import 'package:catalogo_ja/ui/theme/app_icons.dart';
import 'package:catalogo_ja/ui/theme/app_tokens.dart';
import 'package:catalogo_ja/ui/widgets/app_gradient_button.dart';
import 'package:catalogo_ja/ui/widgets/app_primary_button.dart';
import 'package:catalogo_ja/viewmodels/auth_viewmodel.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleEmailPasswordLogin() {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    ref
        .read(authViewModelProvider.notifier)
        .signInWithEmailAndPassword(
          _emailController.text.trim().toLowerCase(),
          _passwordController.text,
        );
  }

  String _authErrorMessage(Object error) {
    if (error is! FirebaseAuthException) {
      return 'Falha ao entrar. Tente novamente.';
    }

    switch (error.code) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'Email ou senha invalidos.';
      case 'invalid-email':
        return 'O email informado e invalido.';
      case 'operation-not-allowed':
        return 'Login por email e senha nao esta habilitado no Firebase Authentication.';
      case 'too-many-requests':
        return 'Muitas tentativas. Aguarde alguns minutos e tente novamente.';
      case 'network-request-failed':
        return 'Falha de rede ao tentar entrar.';
      default:
        return error.message ?? 'Falha ao entrar com email e senha.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authViewModelProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          // Background Image
          Positioned.fill(
            child: Image.asset(
              AppIcons.loginBackground,
              fit: BoxFit.cover,
            ),
          ),
          
          // Gradient Overlay to ensure readability
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    isDark ? Colors.black.withOpacity(0.4) : Colors.white.withOpacity(0.1),
                    isDark ? AppTokens.deepNavy.withOpacity(0.95) : Colors.white.withOpacity(0.9),
                  ],
                ),
              ),
            ),
          ),

          // Floating Blobs for a modern feel
          if (isDark) ...[
            Positioned(
              top: -100,
              right: -50,
              child: _buildBlob(300, AppTokens.electricBlue.withOpacity(0.1)),
            ),
            Positioned(
              bottom: -50,
              left: -50,
              child: _buildBlob(250, AppTokens.softPurple.withOpacity(0.1)),
            ),
          ],

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Logo
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
                              width: 140,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),

                      Text(
                        'Seja bem-vindo',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : Colors.black87,
                          letterSpacing: -1,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Acesse sua conta para gerenciar seu catálogo.',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.white54 : Colors.black45,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 48),

                      // Form
                      authState.when(
                        data: (_) => _EmailPasswordForm(
                          formKey: _formKey,
                          emailController: _emailController,
                          passwordController: _passwordController,
                          obscurePassword: _obscurePassword,
                          isDark: isDark,
                          onTogglePassword: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                          onSubmit: _handleEmailPasswordLogin,
                        ),
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (e, _) => Column(
                          children: [
                            _EmailPasswordForm(
                              formKey: _formKey,
                              emailController: _emailController,
                              passwordController: _passwordController,
                              obscurePassword: _obscurePassword,
                              isDark: isDark,
                              onTogglePassword: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                              onSubmit: _handleEmailPasswordLogin,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _authErrorMessage(e),
                              style: const TextStyle(
                                color: AppTokens.accentRed,
                                fontSize: 13,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Footer
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Não possui conta?',
                            style: TextStyle(
                              color: isDark ? Colors.white38 : Colors.black38,
                              fontSize: 13,
                            ),
                          ),
                          TextButton(
                            onPressed: () => context.push('/register'),
                            child: Text(
                              'Criar uma agora',
                              style: TextStyle(
                                color: isDark
                                    ? AppTokens.vibrantCyan
                                    : AppTokens.electricBlue,
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
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
}

class _EmailPasswordForm extends StatelessWidget {
  const _EmailPasswordForm({
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.obscurePassword,
    required this.isDark,
    required this.onTogglePassword,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final bool isDark;
  final VoidCallback onTogglePassword;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        children: [
          _buildInput(
            controller: emailController,
            label: 'E-mail',
            icon: Icons.alternate_email_rounded,
            isDark: isDark,
            validator: (v) =>
                (v == null || !v.contains('@')) ? 'E-mail inválido' : null,
          ),
          const SizedBox(height: 16),
          _buildInput(
            controller: passwordController,
            label: 'Senha',
            icon: Icons.lock_outline_rounded,
            isDark: isDark,
            obscure: obscurePassword,
            suffix: IconButton(
              onPressed: onTogglePassword,
              icon: Icon(
                obscurePassword
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                size: 18,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ),
            validator: (v) =>
                (v == null || v.isEmpty) ? 'Informe a senha' : null,
            onSubmitted: (_) => onSubmit(),
          ),
          const SizedBox(height: 32),
          AppPrimaryButton(
            label: 'ENTRAR',
            icon: Icons.login_rounded,
            onPressed: onSubmit,
          ),
        ],
      ),
    );
  }

  Widget _buildInput({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isDark,
    bool obscure = false,
    Widget? suffix,
    String? Function(String?)? validator,
    void Function(String)? onSubmitted,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      validator: validator,
      onFieldSubmitted: onSubmitted,
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
        suffixIcon: suffix,
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
