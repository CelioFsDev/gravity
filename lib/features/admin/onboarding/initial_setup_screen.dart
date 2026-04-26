import 'dart:io' as io;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:catalogo_ja/ui/theme/app_tokens.dart';
import 'package:catalogo_ja/viewmodels/global_sync_viewmodel.dart';
import 'package:catalogo_ja/data/repositories/settings_repository.dart';
import 'package:catalogo_ja/core/services/system_backup_service.dart';
import 'package:catalogo_ja/ui/widgets/sync_progress_overlay.dart';
import 'package:catalogo_ja/viewmodels/auth_viewmodel.dart';

class InitialSetupScreen extends ConsumerStatefulWidget {
  const InitialSetupScreen({super.key});

  @override
  ConsumerState<InitialSetupScreen> createState() => _InitialSetupScreenState();
}

class _InitialSetupScreenState extends ConsumerState<InitialSetupScreen>
    with TickerProviderStateMixin {
  late AnimationController _entranceController;
  late AnimationController _floatController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  late Animation<double> _floatAnim;

  int _currentStep = 0;
  static const _totalSteps = 3;

  @override
  void initState() {
    super.initState();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOut,
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutCubic,
    ));

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _floatAnim = Tween<double>(begin: -8, end: 8).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );

    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      setState(() => _currentStep++);
      _entranceController.reset();
      _entranceController.forward();
    }
  }

  void _markAsCompletedAndProceed() async {
    final repo = ref.read(settingsRepositoryProvider);
    final settings = repo.getSettings();
    await repo.saveSettings(settings.copyWith(isInitialSyncCompleted: true));
    if (mounted) {
      context.go('/admin/dashboard');
    }
  }

  Future<void> _importZip() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip', 'cja'],
    );

    if (result != null && result.files.single.path != null) {
      final file = io.File(result.files.single.path!);
      try {
        ref
            .read(syncProgressProvider.notifier)
            .startSync('Preparando ambiente offline...');
        await ref.read(systemBackupServiceProvider).restoreFullBackup(
          file,
          onProgress: (p, msg) =>
              ref.read(syncProgressProvider.notifier).updateProgress(p, msg),
        );
        ref.read(syncProgressProvider.notifier).stopSync();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 10),
                  Text(
                    'Catálogo restaurado com sucesso!',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              backgroundColor: AppTokens.accentGreen,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
          _markAsCompletedAndProceed();
        }
      } catch (e) {
        ref.read(syncProgressProvider.notifier).stopSync();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao restaurar: $e'),
              backgroundColor: AppTokens.accentRed,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final syncProgress = ref.watch(syncProgressProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        Scaffold(
          backgroundColor: isDark ? AppTokens.deepNavy : AppTokens.bg,
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            actions: [
              TextButton(
                onPressed: () {
                  ref.read(authViewModelProvider.notifier).signOut();
                },
                child: Text(
                  'Sair',
                  style: TextStyle(
                    color: isDark ? Colors.white38 : Colors.black38,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: Stack(
            fit: StackFit.expand,
            children: [
              // Background glow
              if (isDark) ...[
                Positioned(
                  top: -100,
                  right: -80,
                  child: Container(
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppTokens.electricBlue.withOpacity(0.12),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -60,
                  left: -60,
                  child: Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppTokens.softPurple.withOpacity(0.1),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ],

              // Main content
              SafeArea(
                child: Column(
                  children: [
                    // Progress indicator
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                      child: _StepProgressBar(
                        current: _currentStep,
                        total: _totalSteps,
                        isDark: isDark,
                      ),
                    ),

                    Expanded(
                      child: FadeTransition(
                        opacity: _fadeAnim,
                        child: SlideTransition(
                          position: _slideAnim,
                          child: _buildStep(
                            context,
                            isDark: isDark,
                            syncProgress: syncProgress,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (syncProgress.isSyncing)
          SyncProgressOverlay(
            progress: syncProgress.progress,
            message: syncProgress.message,
          ),
      ],
    );
  }

  Widget _buildStep(
    BuildContext context, {
    required bool isDark,
    required dynamic syncProgress,
  }) {
    return switch (_currentStep) {
      0 => _WelcomeStep(
          isDark: isDark,
          floatAnim: _floatAnim,
          onNext: _nextStep,
        ),
      1 => _FeaturesStep(
          isDark: isDark,
          onNext: _nextStep,
        ),
      2 => _SetupStep(
          isDark: isDark,
          syncProgress: syncProgress,
          onImport: _importZip,
          onSkip: _markAsCompletedAndProceed,
        ),
      _ => const SizedBox.shrink(),
    };
  }
}

/// ─── Step 1: Welcome ───────────────────────────────────────────────────────
class _WelcomeStep extends StatelessWidget {
  const _WelcomeStep({
    required this.isDark,
    required this.floatAnim,
    required this.onNext,
  });

  final bool isDark;
  final Animation<double> floatAnim;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          const SizedBox(height: 16),
          // Floating logo
          AnimatedBuilder(
            animation: floatAnim,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, floatAnim.value),
                child: child,
              );
            },
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Glow
                Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppTokens.electricBlue.withOpacity(0.2),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
                // Icon container
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1A3A6B), Color(0xFF0A1F44)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                      color: AppTokens.electricBlue.withOpacity(0.35),
                      width: 1.5,
                    ),
                    boxShadow: [AppTokens.glowBlue],
                  ),
                  child: Image.asset(
                    'assets/branding/icons/catalogoja_icons_glass_1024x1024.png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.auto_awesome_rounded,
                      color: Colors.white,
                      size: 48,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 36),

          // Headline
          ShaderMask(
            shaderCallback: (b) => AppTokens.primaryGradient.createShader(b),
            child: const Text(
              'Bem-vindo ao\nCatálogo Já!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: -1.2,
                height: 1.15,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'O sistema de gestão de catálogos mais poderoso do mercado. '
            'Crie catálogos profissionais e compartilhe com seus clientes em segundos.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              height: 1.6,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),

          const SizedBox(height: 40),

          // Key benefits chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _BenefitChip(
                icon: Icons.offline_bolt_rounded,
                label: 'Offline-First',
                isDark: isDark,
                color: AppTokens.accentGreen,
              ),
              _BenefitChip(
                icon: Icons.speed_rounded,
                label: 'Ultra Rápido',
                isDark: isDark,
                color: AppTokens.electricBlue,
              ),
              _BenefitChip(
                icon: Icons.picture_as_pdf_rounded,
                label: 'PDF Profissional',
                isDark: isDark,
                color: AppTokens.accentRed,
              ),
              _BenefitChip(
                icon: Icons.share_rounded,
                label: 'Fácil Compartilhar',
                isDark: isDark,
                color: AppTokens.softPurple,
              ),
            ],
          ),

          const SizedBox(height: 48),

          // CTA
          _GradientButton(
            label: 'Começar',
            icon: Icons.arrow_forward_rounded,
            onTap: onNext,
          ),
        ],
      ),
    );
  }
}

/// ─── Step 2: Features ──────────────────────────────────────────────────────
class _FeaturesStep extends StatelessWidget {
  const _FeaturesStep({required this.isDark, required this.onNext});

  final bool isDark;
  final VoidCallback onNext;

  static const _features = [
    _FeatureItem(
      icon: Icons.inventory_2_outlined,
      color: AppTokens.electricBlue,
      title: 'Gestão Completa de Produtos',
      description:
          'Cadastre produtos com fotos, variantes, preços e muito mais. '
          'Organize por categorias e coleções personalizadas.',
    ),
    _FeatureItem(
      icon: Icons.picture_as_pdf_rounded,
      color: AppTokens.accentRed,
      title: 'Catálogos PDF Premium',
      description:
          'Gere catálogos com capa profissional, preços e QR code. '
          'Impressione seus clientes com material de vendas de alto nível.',
    ),
    _FeatureItem(
      icon: Icons.cloud_sync_rounded,
      color: AppTokens.accentGreen,
      title: 'Sincronização em Nuvem',
      description:
          'Seus dados seguros no Firebase. Acesse de qualquer '
          'dispositivo com sincronização em tempo real.',
    ),
    _FeatureItem(
      icon: Icons.group_outlined,
      color: AppTokens.softPurple,
      title: 'Multi-Usuário e Multi-Loja',
      description:
          'Gerencie múltiplas lojas e equipes. Controle de acesso '
          'granular por perfil (Admin, Vendedor, Visualizador).',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          // Header
          Text(
            'Tudo que você\nprecisa para vender',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : AppTokens.textPrimary,
              letterSpacing: -0.8,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Funcionalidades pensadas para representantes e lojistas.',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white54 : Colors.black45,
            ),
          ),
          const SizedBox(height: 28),

          // Feature cards
          ..._features.map(
            (f) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _FeatureCard(feature: f, isDark: isDark),
            ),
          ),

          const SizedBox(height: 32),

          _GradientButton(
            label: 'Próximo',
            icon: Icons.arrow_forward_rounded,
            onTap: onNext,
          ),
        ],
      ),
    );
  }
}

/// ─── Step 3: Setup ─────────────────────────────────────────────────────────
class _SetupStep extends StatelessWidget {
  const _SetupStep({
    required this.isDark,
    required this.syncProgress,
    required this.onImport,
    required this.onSkip,
  });

  final bool isDark;
  final dynamic syncProgress;
  final VoidCallback onImport;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 8),

          // Icon
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: AppTokens.primaryGradient,
              boxShadow: [AppTokens.glowBlue],
            ),
            child: const Icon(
              Icons.rocket_launch_rounded,
              color: Colors.white,
              size: 38,
            ),
          ),

          const SizedBox(height: 24),

          Text(
            'Prepare seu catálogo',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : AppTokens.textPrimary,
              letterSpacing: -0.8,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'O Catálogo Já funciona offline. Para começar com seus dados '
            'já existentes, importe seu arquivo de backup.',
            style: TextStyle(
              fontSize: 14,
              height: 1.6,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 32),

          // Step list
          _InstructionRow(
            step: 1,
            icon: Icons.folder_zip_outlined,
            title: 'Selecione o arquivo .zip ou .cja',
            subtitle:
                'Exportado do seu dispositivo anterior ou pelo portal web.',
            isDark: isDark,
          ),
          const SizedBox(height: 16),
          _InstructionRow(
            step: 2,
            icon: Icons.bolt_rounded,
            title: 'Importação ultra rápida',
            subtitle:
                'Produtos e fotos estarão disponíveis instantaneamente offline.',
            isDark: isDark,
          ),
          const SizedBox(height: 16),
          _InstructionRow(
            step: 3,
            icon: Icons.verified_rounded,
            title: 'Pronto para vender!',
            subtitle: 'Crie catálogos em PDF e compartilhe com clientes.',
            isDark: isDark,
          ),

          const SizedBox(height: 36),

          // Import button
          _GradientButton(
            label: 'Importar Arquivo (.zip / .cja)',
            icon: Icons.upload_file_rounded,
            onTap: syncProgress.isSyncing ? null : onImport,
          ),

          const SizedBox(height: 14),

          // Skip
          TextButton(
            onPressed: syncProgress.isSyncing ? null : onSkip,
            child: Text(
              'Começar do zero (catálogo vazio)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Shared sub-widgets ───────────────────────────────────────────────────────

class _StepProgressBar extends StatelessWidget {
  const _StepProgressBar({
    required this.current,
    required this.total,
    required this.isDark,
  });

  final int current;
  final int total;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total, (i) {
        final isActive = i <= current;
        return Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: EdgeInsets.only(right: i < total - 1 ? 6 : 0),
            height: 4,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTokens.radiusFull),
              gradient: isActive ? AppTokens.primaryGradient : null,
              color: isActive
                  ? null
                  : (isDark ? Colors.white12 : Colors.black12),
            ),
          ),
        );
      }),
    );
  }
}

class _BenefitChip extends StatelessWidget {
  const _BenefitChip({
    required this.icon,
    required this.label,
    required this.isDark,
    required this.color,
  });

  final IconData icon;
  final String label;
  final bool isDark;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTokens.radiusFull),
        color: color.withOpacity(0.1),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  const _GradientButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppTokens.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
            gradient: onTap != null
                ? AppTokens.primaryGradient
                : null,
            color: onTap == null ? Colors.grey.shade300 : null,
            boxShadow: onTap != null ? [AppTokens.glowBlue] : null,
          ),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(width: 10),
                Icon(icon, color: Colors.white, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureItem {
  final IconData icon;
  final Color color;
  final String title;
  final String description;

  const _FeatureItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
  });
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({required this.feature, required this.isDark});

  final _FeatureItem feature;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        color: isDark ? AppTokens.cardDark : Colors.white,
        border: Border.all(
          color: isDark ? AppTokens.borderDark : AppTokens.borderLight,
        ),
        boxShadow: isDark ? [] : [AppTokens.shadowSm],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: feature.color.withOpacity(0.1),
            ),
            child: Icon(feature.icon, color: feature.color, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  feature.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: isDark ? Colors.white : AppTokens.textPrimary,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  feature.description,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InstructionRow extends StatelessWidget {
  const _InstructionRow({
    required this.step,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isDark,
  });

  final int step;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Step number badge
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppTokens.primaryGradient,
          ),
          child: Center(
            child: Text(
              step.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    icon,
                    size: 16,
                    color: isDark ? Colors.white60 : AppTokens.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: isDark ? Colors.white : AppTokens.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: isDark ? Colors.white45 : Colors.black45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
