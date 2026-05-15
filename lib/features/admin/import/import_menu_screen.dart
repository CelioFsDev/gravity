import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:catalogo_ja/ui/widgets/app_scaffold.dart';
import 'package:catalogo_ja/ui/theme/app_tokens.dart';
import 'package:catalogo_ja/viewmodels/product_export_viewmodel.dart';
import 'package:catalogo_ja/viewmodels/settings_viewmodel.dart';

const bool _showStockUpdatePdf = false;

class ImportMenuScreen extends ConsumerWidget {
  const ImportMenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exportState = ref.watch(productExportViewModelProvider);
    final settings = ref.watch(settingsViewModelProvider);
    final lastBackupLabel = _formatLastBackup(settings.lastFullBackupAt);

    return AppScaffold(
      title: 'Backup e Importações',
      body: ListView(
        padding: const EdgeInsets.all(AppTokens.space24),
        children: [
          _buildSection(
            context,
            title: 'Backup do aplicativo',
            description:
                'Gere uma cópia completa dos dados do aplicativo para guardar em local seguro. Use antes de trocar de aparelho, reinstalar o app ou fazer grandes alterações.',
            child: _buildActionItem(
              context,
              icon: Icons.archive_outlined,
              title: 'Backup Completo do Aplicativo',
              subtitle: exportState.isLoading
                  ? 'Gerando backup... aguarde.'
                  : 'Salva produtos, catálogos, categorias e fotos em um arquivo .zip. $lastBackupLabel',
              isBusy: exportState.isLoading,
              onTap: () {
                if (exportState.isLoading) return;

                ref
                    .read(productExportViewModelProvider.notifier)
                    .exportPackage();

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Gerando backup completo em segundo plano...',
                    ),
                    backgroundColor: AppTokens.accentBlue,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: AppTokens.space24),

          if (_showStockUpdatePdf) ...[
            _buildSection(
              context,
              title: 'Atualizar estoque',
              description:
                  'Use esta opção para colar o texto de um relatório e atualizar quantidades automaticamente.',
              child: _buildItem(
                context,
                icon: Icons.inventory_2_outlined,
                title: 'Atualizar Estoque (PDF)',
                subtitle:
                    'Colar texto de relatório para atualizar quantidades.',
                route: '/admin/imports/stock-update',
              ),
            ),
            const SizedBox(height: AppTokens.space24),
          ],

          _buildSection(
            context,
            title: 'Restaurar backup completo',
            description:
                'Use esta opção para recuperar os dados salvos em um backup do Catálogo Já. Ela é indicada quando você está configurando um aparelho novo ou precisa trazer dados antigos de volta.',
            child: _buildItem(
              context,
              icon: Icons.settings_backup_restore,
              title: 'Restaurar Backup Completo',
              subtitle:
                  'Importa produtos, catálogos, categorias e fotos de um arquivo .zip ou .json.',
              route: '/admin/imports/backup',
            ),
          ),
          const SizedBox(height: AppTokens.space24),

          _buildSection(
            context,
            title: 'Criar catálogo por pedido',
            description:
                'Importe um PDF de pedido gerado por CRM para montar um catálogo somente com as referências encontradas.',
            child: _buildItem(
              context,
              icon: Icons.picture_as_pdf_outlined,
              title: 'Importar pedido PDF',
              subtitle:
                  'Extrai referências do PDF e cria um catálogo com os produtos cadastrados.',
              route: '/admin/import-order-pdf',
            ),
          ),
          const SizedBox(height: AppTokens.space24),

          _buildSection(
            context,
            title: 'Importar produtos',
            description:
                'Traga produtos cadastrados em outras plataformas para dentro do aplicativo. A importação da Nuvemshop usa uma planilha CSV exportada da sua loja.',
            child: _buildItem(
              context,
              icon: Icons.cloud_download_outlined,
              title: 'Importar Nuvemshop',
              subtitle:
                  'Importa produtos da Nuvemshop por CSV e ajuda a iniciar o catálogo sem cadastrar tudo manualmente.',
              route: '/admin/imports/nuvemshop',
            ),
          ),
        ],
      ),
    );
  }

  String _formatLastBackup(DateTime? value) {
    if (value == null) return 'Nenhum backup gerado ainda.';

    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final year = value.year.toString();
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');

    return 'Último backup: $day/$month/$year às $hour:$minute.';
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required String description,
    required Widget child,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : AppTokens.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          description,
          style: TextStyle(
            fontSize: 13,
            height: 1.35,
            color: isDark ? Colors.white70 : AppTokens.textSecondary,
          ),
        ),
        const SizedBox(height: AppTokens.space12),
        child,
      ],
    );
  }

  Widget _buildItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required String route,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppTokens.space16,
          vertical: AppTokens.space8,
        ),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTokens.accentBlue.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppTokens.accentBlue),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.go(route),
      ),
    );
  }

  Widget _buildActionItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isBusy = false,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppTokens.space16,
          vertical: AppTokens.space8,
        ),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTokens.accentBlue.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: isBusy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(icon, color: AppTokens.accentBlue),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 12),
        ),
        trailing: isBusy
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.chevron_right),
        onTap: isBusy ? null : onTap,
      ),
    );
  }
}
