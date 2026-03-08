import 'package:catalogo_ja/ui/theme/app_tokens.dart';
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
  bool _useEmailPassword = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleGoogleLogin() {
    ref.read(authViewModelProvider.notifier).signInWithGoogle();
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

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/branding/login/catalogoja_login_premium_1080x1920.png',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.28),
                    Colors.black.withValues(alpha: 0.82),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTokens.space32,
                  vertical: AppTokens.space24,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Column(
                          children: [
                            Image.asset(
                              'assets/branding/logo/catalogoja_logo_master_2048x2048.png',
                              width: MediaQuery.of(context).size.width * 0.65,
                              fit: BoxFit.contain,
                            ),
                            const SizedBox(height: AppTokens.space12),
                            Text(
                              'Seu catalogo profissional em minutos',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white.withValues(alpha: 0.84),
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.4,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppTokens.space32),
                      Container(
                        padding: const EdgeInsets.all(AppTokens.space32),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(32),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 30,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Acesse sua conta',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: AppTokens.textPrimary,
                                letterSpacing: -0.4,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: AppTokens.space8),
                            Text(
                              _useEmailPassword
                                  ? 'Entre com email e senha cadastrados pelo administrador.'
                                  : 'Entre com sua conta Google para gerenciar produtos e catalogos.',
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppTokens.textSecondary,
                                height: 1.4,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: AppTokens.space24),
                            SegmentedButton<bool>(
                              segments: const [
                                ButtonSegment<bool>(
                                  value: false,
                                  label: Text('Google'),
                                  icon: Icon(Icons.g_mobiledata),
                                ),
                                ButtonSegment<bool>(
                                  value: true,
                                  label: Text('Email'),
                                  icon: Icon(Icons.alternate_email_outlined),
                                ),
                              ],
                              selected: {_useEmailPassword},
                              onSelectionChanged: (selection) {
                                setState(() {
                                  _useEmailPassword = selection.first;
                                });
                              },
                            ),
                            const SizedBox(height: AppTokens.space24),
                            authState.when(
                              data: (_) => _useEmailPassword
                                  ? _EmailPasswordForm(
                                      formKey: _formKey,
                                      emailController: _emailController,
                                      passwordController: _passwordController,
                                      obscurePassword: _obscurePassword,
                                      onTogglePassword: () {
                                        setState(() {
                                          _obscurePassword = !_obscurePassword;
                                        });
                                      },
                                      onSubmit: _handleEmailPasswordLogin,
                                    )
                                  : _GoogleButton(
                                      onPressed: _handleGoogleLogin,
                                    ),
                              loading: () => const Center(
                                child: CircularProgressIndicator(),
                              ),
                              error: (error, _) => Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    _authErrorMessage(error),
                                    style: const TextStyle(
                                      color: AppTokens.accentRed,
                                      fontSize: 12,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 16),
                                  _useEmailPassword
                                      ? _EmailPasswordForm(
                                          formKey: _formKey,
                                          emailController: _emailController,
                                          passwordController:
                                              _passwordController,
                                          obscurePassword: _obscurePassword,
                                          onTogglePassword: () {
                                            setState(() {
                                              _obscurePassword =
                                                  !_obscurePassword;
                                            });
                                          },
                                          onSubmit: _handleEmailPasswordLogin,
                                        )
                                      : _GoogleButton(
                                          onPressed: _handleGoogleLogin,
                                        ),
                                ],
                              ),
                            ),
                            const SizedBox(height: AppTokens.space12),
                            TextButton(
                              onPressed: () => context.push('/register'),
                              child: const Text(
                                'Não tem uma conta? Registre-se agora',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppTokens.accentBlue,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppTokens.space24),
                      Text(
                        _useEmailPassword
                            ? 'O cadastro por email e senha e criado apenas pelo super admin.'
                            : 'Ao entrar, voce concorda com nossos Termos de Uso e Politica de Privacidade.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.64),
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
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
}

class _GoogleButton extends StatelessWidget {
  const _GoogleButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        side: const BorderSide(color: Color(0xFFE5E7EB)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.white,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset('assets/images/google_logo.png', height: 24, width: 24),
          const SizedBox(width: 12),
          const Text(
            'Entrar com Google',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF374151),
            ),
          ),
        ],
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
    required this.onTogglePassword,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final VoidCallback onTogglePassword;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            validator: (value) {
              final email = value?.trim().toLowerCase() ?? '';
              if (email.isEmpty || !email.contains('@')) {
                return 'Informe um email valido.';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: passwordController,
            obscureText: obscurePassword,
            decoration: InputDecoration(
              labelText: 'Senha',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                onPressed: onTogglePassword,
                icon: Icon(
                  obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
            validator: (value) {
              if ((value ?? '').isEmpty) {
                return 'Informe sua senha.';
              }
              return null;
            },
            onFieldSubmitted: (_) => onSubmit(),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onSubmit,
            icon: const Icon(Icons.login_outlined),
            label: const Text('Entrar com email e senha'),
          ),
        ],
      ),
    );
  }
}
