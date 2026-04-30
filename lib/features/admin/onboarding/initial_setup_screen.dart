import 'dart:io' as io;
import 'package:catalogo_ja/viewmodels/products_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:catalogo_ja/ui/theme/app_tokens.dart';
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
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
          ),
        );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
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
        await ref
            .read(systemBackupServiceProvider)
            .restoreFullBackup(
              file,
              onProgress: (p, msg) => ref
                  .read(syncProgressProvider.notifier)
                  .updateProgress(p, msg),
            );
        ref.read(syncProgressProvider.notifier).stopSync();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🎉 Catálogo restaurado com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
          _markAsCompletedAndProceed();
        }
      } catch (e) {
        ref.read(syncProgressProvider.notifier).stopSync();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('⚠️ Erro ao restaurar: $e'),
              backgroundColor: Colors.red.shade800,
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
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            actions: [
              TextButton.icon(
                onPressed: () {
                  ref.read(authViewModelProvider.notifier).signOut();
                },
                icon: const Icon(Icons.logout, color: Colors.grey),
                label: const Text('Sair', style: TextStyle(color: Colors.grey)),
              ),
              const SizedBox(width: 16),
            ],
          ),
          body: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        AppTokens.bgDark,
                        const Color(0xFF1A1F2C), // slightly lighter dark blue
                        AppTokens.bgDark,
                      ]
                    : [
                        AppTokens.bg,
                        Colors.blue.shade50.withOpacity(0.5),
                        AppTokens.bg,
                      ],
              ),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: AnimatedBuilder(
                    animation: _animationController,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _fadeAnimation.value,
                        child: SlideTransition(
                          position: _slideAnimation,
                          child: child,
                        ),
                      );
                    },
                    child: Card(
                      elevation: isDark ? 0 : 12,
                      shadowColor: isDark ? Colors.transparent : Colors.black12,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                        side: isDark
                            ? BorderSide(color: Colors.white.withOpacity(0.05))
                            : BorderSide.none,
                      ),
                      color: isDark ? const Color(0xFF1E2330) : Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Icon(
                              Icons.rocket_launch_rounded,
                              size: 80,
                              color: AppTokens.accentBlue,
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'Prepare seu Catálogo',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'O Catálogo Já usa tecnologia Offline-First. Isso significa velocidade extrema e economia de dados. Para iniciar sem gastar internet, importe seu último arquivo de backup.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.black54,
                                    height: 1.5,
                                  ),
                            ),
                            const SizedBox(height: 48),
                            _buildInstructionStep(
                              context,
                              number: '1',
                              title: 'Selecione o arquivo .zip ou .cja',
                              subtitle:
                                  'Geralmente gerado pelo seu aparelho anterior ou portal web.',
                              icon: Icons.folder_zip_outlined,
                            ),
                            const SizedBox(height: 24),
                            _buildInstructionStep(
                              context,
                              number: '2',
                              title: 'Importação ultra rápida',
                              subtitle:
                                  'Suas fotos e produtos ficarão disponíveis instantaneamente offline.',
                              icon: Icons.bolt_rounded,
                            ),
                            const SizedBox(height: 48),
                            FilledButton.icon(
                              onPressed: syncProgress.isSyncing
                                  ? null
                                  : _importZip,
                              icon: const Icon(Icons.upload_file),
                              label: const Text(
                                'Importar Arquivo (.zip / .cja)',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 20,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            TextButton(
                              onPressed: syncProgress.isSyncing
                                  ? null
                                  : _markAsCompletedAndProceed,
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                foregroundColor: isDark
                                    ? Colors.white54
                                    : Colors.black54,
                              ),
                              child: const Text(
                                'Começar do Zero (Catálogo Vazio)',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
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

  Widget _buildInstructionStep(
    BuildContext context, {
    required String number,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = AppTokens.accentBlue;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: primaryColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: TextStyle(
                color: primaryColor,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white54 : Colors.black54,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        Icon(icon, color: primaryColor.withOpacity(0.5), size: 28),
      ],
    );
  }
}
