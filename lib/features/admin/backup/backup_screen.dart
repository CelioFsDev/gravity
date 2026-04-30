import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:catalogo_ja/ui/theme/app_tokens.dart';
import 'package:catalogo_ja/ui/widgets/app_scaffold.dart';
import 'package:catalogo_ja/viewmodels/product_export_viewmodel.dart';

class BackupScreen extends ConsumerWidget {
  const BackupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exportState = ref.watch(productExportViewModelProvider);

    return AppScaffold(
      title: 'Backup',
      subtitle: 'Proteja seus dados e restaure o app quando precisar',
      body: ListView(
        padding: const EdgeInsets.all(AppTokens.space24),
        children: [
          _InfoPanel(
            title: 'Backup completo do app',
            description:
                'Crie um arquivo ZIP com produtos, categorias, coleções, catálogos e fotos. Use esse arquivo para guardar uma cópia segura ou migrar para outro aparelho.',
            icon: Icons.verified_user_outlined,
            color: AppTokens.accentBlue,
          ),
          const SizedBox(height: AppTokens.space16),
          _BackupAction(
            icon: Icons.archive_outlined,
            title: 'Criar backup completo',
            description:
                'Gera um ZIP completo com todos os dados locais do aplicativo e abre o compartilhamento para enviar ou salvar o arquivo.',
            details: const [
              'Inclui produtos, fotos, categorias, coleções e catálogos.',
              'Recomendado antes de trocar de aparelho ou fazer mudanças grandes.',
              'Guarde o arquivo em um local seguro, como Drive, WhatsApp ou computador.',
            ],
            buttonLabel: exportState.isLoading
                ? 'Gerando backup...'
                : 'Criar backup agora',
            buttonIcon: exportState.isLoading
                ? Icons.hourglass_top_rounded
                : Icons.backup_outlined,
            color: AppTokens.accentBlue,
            isLoading: exportState.isLoading,
            progress: exportState.progress,
            progressMessage: exportState.message,
            onPressed: exportState.isLoading
                ? null
                : () async {
                    await ref
                        .read(productExportViewModelProvider.notifier)
                        .exportPackage();
                    if (!context.mounted) return;

                    final state = ref.read(productExportViewModelProvider);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          state.errorMessage ??
                              'Backup completo gerado com sucesso.',
                        ),
                        backgroundColor: state.errorMessage == null
                            ? AppTokens.accentBlue
                            : Theme.of(context).colorScheme.error,
                      ),
                    );
                  },
          ),
          const SizedBox(height: AppTokens.space16),
          _BackupAction(
            icon: Icons.restore_page_outlined,
            title: 'Restaurar backup completo',
            description:
                'Importa um arquivo de backup ZIP ou JSON. Você pode mesclar os dados ou substituir tudo durante a restauração.',
            details: const [
              'Use o ZIP para restaurar também as fotos.',
              'Confira o resumo do arquivo antes de confirmar.',
              'A opção "Substituir Tudo" apaga os dados locais atuais antes de importar.',
            ],
            buttonLabel: 'Restaurar backup',
            buttonIcon: Icons.settings_backup_restore_rounded,
            color: AppTokens.accentOrange,
            onPressed: () => context.go('/admin/imports/backup'),
          ),
          const SizedBox(height: AppTokens.space16),
          _InfoPanel(
            title: 'Quando fazer backup?',
            description:
                'Faça um backup antes de importar muitos produtos, editar preços em massa, trocar de celular ou limpar dados do app. Para empresas com muita movimentação, o ideal é manter uma cópia recente sempre salva fora do aparelho.',
            icon: Icons.info_outline_rounded,
            color: AppTokens.accentGreen,
          ),
        ],
      ),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });

  final String title;
  final String description;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTokens.space16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: AppTokens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppTokens.space8),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.35,
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

class _BackupAction extends StatelessWidget {
  const _BackupAction({
    required this.icon,
    required this.title,
    required this.description,
    required this.details,
    required this.buttonLabel,
    required this.buttonIcon,
    required this.color,
    required this.onPressed,
    this.isLoading = false,
    this.progress = 0,
    this.progressMessage,
  });

  final IconData icon;
  final String title;
  final String description;
  final List<String> details;
  final String buttonLabel;
  final IconData buttonIcon;
  final Color color;
  final VoidCallback? onPressed;
  final bool isLoading;
  final double progress;
  final String? progressMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppTokens.space20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        border: Border.all(color: theme.dividerColor),
        boxShadow: const [AppTokens.shadowSm],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: AppTokens.space12),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.space16),
          Text(
            description,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
          const SizedBox(height: AppTokens.space12),
          ...details.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: AppTokens.space8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_circle_outline, size: 16, color: color),
                  const SizedBox(width: AppTokens.space8),
                  Expanded(
                    child: Text(item, style: theme.textTheme.bodySmall),
                  ),
                ],
              ),
            ),
          ),
          if (isLoading) ...[
            const SizedBox(height: AppTokens.space12),
            LinearProgressIndicator(value: progress <= 0 ? null : progress),
            if (progressMessage != null) ...[
              const SizedBox(height: AppTokens.space8),
              Text(progressMessage!, style: theme.textTheme.bodySmall),
            ],
          ],
          const SizedBox(height: AppTokens.space16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onPressed,
              icon: Icon(buttonIcon),
              label: Text(buttonLabel),
              style: FilledButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
