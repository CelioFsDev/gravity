import 'package:catalogo_ja/ui/theme/app_tokens.dart';
import 'package:catalogo_ja/ui/theme/app_icons.dart';
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
        return 'Login por email e senha nao esta habilitado no Firebase.';
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
      backgroundColor: isDark ? AppTokens.deepNavy : const Color(0xFFF5F8FC),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 820;
          final panel = _LoginPanel(
            authState: authState,
            formKey: _formKey,
            emailController: _emailController,
            passwordController: _passwordController,
            obscurePassword: _obscurePassword,
            isDark: isDark,
            errorMessage: authState.hasError
                ? _authErrorMessage(authState.error!)
                : null,
            onTogglePassword: () =>
                setState(() => _obscurePassword = !_obscurePassword),
            onSubmit: _handleEmailPasswordLogin,
            onRegister: () => context.push('/register'),
          );

          if (isWide) {
            return Row(
              children: [
                const Expanded(child: _LoginBrandPane()),
                Expanded(
                  child: SafeArea(
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(48),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 430),
                          child: panel,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          }

          return Stack(
            children: [
              const Positioned.fill(child: _LoginBrandPane(compact: true)),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        (isDark ? AppTokens.deepNavy : Colors.white)
                            .withOpacity(0.94),
                      ],
                      stops: const [0.18, 0.68],
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 188, 24, 24),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 430),
                      child: panel,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LoginBrandPane extends StatelessWidget {
  const _LoginBrandPane({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          AppAssets.loginBgPremium,
          fit: BoxFit.cover,
          alignment: compact ? Alignment.topCenter : Alignment.center,
          errorBuilder: (_, __, ___) => Image.asset(
            AppAssets.navLoginBg,
            fit: BoxFit.cover,
            alignment: compact ? Alignment.topCenter : Alignment.center,
            errorBuilder: (_, __, ___) => const ColoredBox(color: AppTokens.deepNavy),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppTokens.deepNavy.withOpacity(compact ? 0.04 : 0.1),
                AppTokens.deepNavy.withOpacity(compact ? 0.54 : 0.22),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _LoginPanel extends StatelessWidget {
  const _LoginPanel({
    required this.authState,
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.obscurePassword,
    required this.isDark,
    required this.onTogglePassword,
    required this.onSubmit,
    required this.onRegister,
    this.errorMessage,
  });

  final AsyncValue<User?> authState;
  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final bool isDark;
  final VoidCallback onTogglePassword;
  final VoidCallback onSubmit;
  final VoidCallback onRegister;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final surfaceColor = isDark ? const Color(0xFF081226) : Colors.white;
    final borderColor = isDark ? Colors.white10 : const Color(0xFFE1E8F0);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
            blurRadius: 28,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 30, 28, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Hero(
                tag: 'app_logo',
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppTokens.deepNavy,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                    child: Image.asset(
                      'assets/branding/icons/catalogoja_icons_glass_1024x1024.png',
                      width: 80,
                      height: 80,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'Entrar',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : const Color(0xFF101827),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Acesse sua conta para gerenciar seu catalogo.',
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: isDark ? Colors.white60 : const Color(0xFF687385),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            authState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : _EmailPasswordForm(
                    formKey: formKey,
                    emailController: emailController,
                    passwordController: passwordController,
                    obscurePassword: obscurePassword,
                    isDark: isDark,
                    onTogglePassword: onTogglePassword,
                    onSubmit: onSubmit,
                  ),
            if (errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                errorMessage!,
                style: const TextStyle(
                  color: AppTokens.accentRed,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 24),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Nao possui conta?',
                  style: TextStyle(
                    color: isDark ? Colors.white54 : const Color(0xFF687385),
                    fontSize: 13,
                  ),
                ),
                TextButton(
                  onPressed: onRegister,
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
            validator: (value) => (value == null || !value.contains('@'))
                ? 'E-mail invalido'
                : null,
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
                color: isDark ? Colors.white54 : const Color(0xFF687385),
              ),
            ),
            validator: (value) =>
                (value == null || value.isEmpty) ? 'Informe a senha' : null,
            onSubmitted: (_) => onSubmit(),
          ),
          const SizedBox(height: 28),
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
        color: isDark ? Colors.white : const Color(0xFF101827),
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: isDark ? Colors.white60 : const Color(0xFF687385),
          fontSize: 14,
        ),
        prefixIcon: Icon(
          icon,
          size: 18,
          color: isDark ? AppTokens.vibrantCyan : AppTokens.electricBlue,
        ),
        suffixIcon: suffix,
        filled: true,
        fillColor: isDark
            ? Colors.white.withOpacity(0.06)
            : const Color(0xFFF3F7FB),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: isDark ? Colors.white10 : const Color(0xFFE1E8F0),
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
