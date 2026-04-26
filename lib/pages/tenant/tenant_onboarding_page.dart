import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:catalogo_ja/data/repositories/tenant_repository.dart';
import 'package:catalogo_ja/viewmodels/auth_viewmodel.dart';
import 'package:catalogo_ja/ui/theme/app_tokens.dart';
import 'package:go_router/go_router.dart';

class TenantOnboardingPage extends ConsumerStatefulWidget {
  const TenantOnboardingPage({super.key});

  @override
  ConsumerState<TenantOnboardingPage> createState() =>
      _TenantOnboardingPageState();
}

class _TenantOnboardingPageState extends ConsumerState<TenantOnboardingPage>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _companyController = TextEditingController();
  final _storeController = TextEditingController();
  bool _isLoading = false;

  late AnimationController _entranceController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    _fadeAnim = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOut,
    );
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _entranceController,
            curve: Curves.easeOutCubic,
          ),
        );
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _companyController.dispose();
    _storeController.dispose();
    super.dispose();
  }

  Future<void> _createCompany() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final user = ref.read(authViewModelProvider).value;
      if (user == null || user.email == null) {
        throw Exception('Usuário não logado');
      }
      final repo = ref.read(tenantRepositoryProvider);
      await repo.createTenantWithStore(
        companyName: _companyController.text.trim(),
        storeName: _storeController.text.trim(),
        adminEmail: user.email!,
      );
      if (mounted) context.go('/admin/dashboard');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao criar empresa: $e'),
            backgroundColor: AppTokens.accentRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showJoinDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _JoinCompanySheet(
        onJoin: (tenantId) async {
          final user = ref.read(authViewModelProvider).value;
          if (user == null || user.email == null) {
            throw Exception('Não logado');
          }
          await ref
              .read(tenantRepositoryProvider)
              .joinTenant(tenantId: tenantId, email: user.email!);
          if (context.mounted) {
            Navigator.pop(ctx);
            context.go('/admin/dashboard');
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTokens.deepNavy : AppTokens.bg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background glows
          Positioned(
            top: -120,
            right: -100,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTokens.electricBlue.withOpacity(isDark ? 0.1 : 0.06),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 16),

                      // Logo / Icon
                      Center(
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(22),
                            gradient: AppTokens.primaryGradient,
                            boxShadow: [AppTokens.glowBlue],
                          ),
                          child: const Icon(
                            Icons.storefront_rounded,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                      ),

                      const SizedBox(height: 28),

                      // Title
                      Text(
                        'Configure sua empresa',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : AppTokens.textPrimary,
                          letterSpacing: -0.8,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Você ainda não pertence a uma empresa. '
                        'Crie a sua ou entre em uma existente.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.6,
                          color: isDark ? Colors.white54 : Colors.black45,
                        ),
                      ),

                      const SizedBox(height: 36),

                      // Create company card
                      _PremiumCard(
                        isDark: isDark,
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                      color: AppTokens.electricBlue.withOpacity(
                                        0.1,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.business_rounded,
                                      color: AppTokens.electricBlue,
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Nova Empresa',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: isDark
                                          ? Colors.white
                                          : AppTokens.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              _buildField(
                                controller: _companyController,
                                label: 'Nome da Empresa',
                                icon: Icons.business_outlined,
                                isDark: isDark,
                                validator: (v) => (v?.isEmpty ?? true)
                                    ? 'Campo obrigatório'
                                    : null,
                              ),
                              const SizedBox(height: 14),
                              _buildField(
                                controller: _storeController,
                                label: 'Nome da Loja / Unidade',
                                hint: 'Ex: Matriz, Filial Centro',
                                icon: Icons.store_outlined,
                                isDark: isDark,
                                validator: (v) => (v?.isEmpty ?? true)
                                    ? 'Campo obrigatório'
                                    : null,
                              ),
                              const SizedBox(height: 24),
                              _GradientActionButton(
                                label: 'Criar Minha Empresa',
                                icon: Icons.rocket_launch_rounded,
                                isLoading: _isLoading,
                                onTap: _createCompany,
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Divider
                      Row(
                        children: [
                          Expanded(
                            child: Divider(
                              color: isDark ? Colors.white12 : Colors.black12,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'ou',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.white38 : Colors.black38,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Divider(
                              color: isDark ? Colors.white12 : Colors.black12,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Join existing
                      _OutlineActionButton(
                        label: 'Entrar em empresa existente',
                        icon: Icons.group_add_rounded,
                        isDark: isDark,
                        onTap: _showJoinDialog,
                      ),

                      const SizedBox(height: 32),
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

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isDark,
    String? hint,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      style: TextStyle(
        color: isDark ? Colors.white : AppTokens.textPrimary,
        fontWeight: FontWeight.w500,
        fontSize: 14,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 18),
        filled: true,
        fillColor: isDark
            ? Colors.white.withOpacity(0.05)
            : const Color(0xFFF3F7FB),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          borderSide: BorderSide(
            color: isDark ? Colors.white10 : AppTokens.borderLight,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          borderSide: const BorderSide(color: AppTokens.electricBlue, width: 2),
        ),
      ),
    );
  }
}

// ─── Join Company Bottom Sheet ────────────────────────────────────────────────
class _JoinCompanySheet extends StatefulWidget {
  const _JoinCompanySheet({required this.onJoin});

  final Future<void> Function(String tenantId) onJoin;

  @override
  State<_JoinCompanySheet> createState() => _JoinCompanySheetState();
}

class _JoinCompanySheetState extends State<_JoinCompanySheet> {
  final _idController = TextEditingController();
  bool _isJoining = false;

  @override
  void dispose() {
    _idController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppTokens.cardDark : Colors.white,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppTokens.radiusXl),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppTokens.radiusFull),
                    color: isDark ? Colors.white70 : Colors.black12,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Icon + title
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: AppTokens.softPurple.withOpacity(0.1),
                    ),
                    child: const Icon(
                      Icons.group_add_rounded,
                      color: AppTokens.softPurple,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Entrar em uma empresa',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : AppTokens.textPrimary,
                        ),
                      ),
                      Text(
                        'Peça o ID ao administrador',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white : Colors.black38,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Info box
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                  color: AppTokens.accentGold.withOpacity(0.08),
                  border: Border.all(
                    color: AppTokens.accentGold.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 16,
                      color: AppTokens.accentGold,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'O administrador da loja encontra o ID em '
                        'Ajustes → Empresa → ID da Empresa.',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.5,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              TextField(
                controller: _idController,
                autofocus: true,
                style: TextStyle(
                  color: isDark ? Colors.white : AppTokens.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  labelText: 'ID da Empresa',
                  hintText: 'Ex: minha-loja-abc123',
                  prefixIcon: const Icon(Icons.tag_rounded, size: 18),
                  filled: true,
                  fillColor: isDark
                      ? Colors.white.withOpacity(0.05)
                      : const Color(0xFFF3F7FB),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                    borderSide: BorderSide(
                      color: isDark ? Colors.white10 : AppTokens.borderLight,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                    borderSide: const BorderSide(
                      color: AppTokens.softPurple,
                      width: 2,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: _isJoining
                          ? null
                          : () => Navigator.pop(context),
                      child: Text(
                        'Cancelar',
                        style: TextStyle(
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: _GradientActionButton(
                      label: 'Entrar',
                      icon: Icons.login_rounded,
                      isLoading: _isJoining,
                      gradient: AppTokens.accentGradient,
                      onTap: () async {
                        final tid = _idController.text.trim();
                        if (tid.isEmpty) return;
                        setState(() => _isJoining = true);
                        try {
                          await widget.onJoin(tid);
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Erro: $e'),
                                backgroundColor: AppTokens.accentRed,
                              ),
                            );
                          }
                        } finally {
                          if (mounted) setState(() => _isJoining = false);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Shared widgets ───────────────────────────────────────────────────────────

class _PremiumCard extends StatelessWidget {
  const _PremiumCard({required this.child, required this.isDark});

  final Widget child;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTokens.radiusXl),
        color: isDark ? AppTokens.cardDark : Colors.white,
        border: Border.all(
          color: isDark ? AppTokens.borderDark : AppTokens.borderLight,
        ),
        boxShadow: isDark
            ? [
                BoxShadow(
                  color: AppTokens.electricBlue.withOpacity(0.06),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ]
            : [AppTokens.shadowMd],
      ),
      child: child,
    );
  }
}

class _GradientActionButton extends StatelessWidget {
  const _GradientActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.isLoading = false,
    this.gradient,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isLoading;
  final LinearGradient? gradient;

  @override
  Widget build(BuildContext context) {
    final grad = gradient ?? AppTokens.primaryGradient;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppTokens.radiusMd),
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
            gradient: isLoading ? null : grad,
            color: isLoading ? Colors.grey.shade300 : null,
          ),
          child: SizedBox(
            height: 52,
            child: isLoading
                ? const Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, color: Colors.white, size: 18),
                      const SizedBox(width: 10),
                      Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _OutlineActionButton extends StatelessWidget {
  const _OutlineActionButton({
    required this.label,
    required this.icon,
    required this.isDark,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppTokens.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
            border: Border.all(
              color: isDark ? Colors.white24 : AppTokens.borderLight,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isDark ? Colors.white60 : AppTokens.textSecondary,
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : AppTokens.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
