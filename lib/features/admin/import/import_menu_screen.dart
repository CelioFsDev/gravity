import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:catalogo_ja/ui/widgets/app_scaffold.dart';
import 'package:catalogo_ja/ui/theme/app_tokens.dart';
import 'package:catalogo_ja/viewmodels/product_export_viewmodel.dart';

class ImportMenuScreen extends ConsumerWidget {
  const ImportMenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppScaffold(
      title: 'Importa\u00e7\u00f5es e Estoque',
      body: ListView(
        padding: const EdgeInsets.all(AppTokens.space24),
        children: [
          _buildItem(
            context,
            icon: Icons.inventory_2_outlined,
            title: 'Atualizar Estoque (PDF)',
            subtitle: 'Colar texto de relat\u00f3rio para atualizar quantidades.',
            route: '/admin/imports/stock-update',
          ),
          const SizedBox(height: AppTokens.space16),
          _buildItem(
            context,
            icon: Icons.cloud_download_outlined,
            title: 'Importar Nuvemshop',
            subtitle: 'Sincronizar produtos da Nuvemshop via CSV.',
            route: '/admin/imports/nuvemshop',
          ),
          const SizedBox(height: AppTokens.space16),
          _buildItem(
            context,
            icon: Icons.settings_backup_restore,
            title: 'Importar Backup CatalogoJa',
            subtitle: 'Restaurar dados de um arquivo .zip ou .json.',
            route: '/admin/imports/backup',
          ),
          const SizedBox(height: AppTokens.space16),
          _buildActionItem(
            context,
            icon: Icons.archive_outlined,
            title: 'Backup Completo do Aplicativo',
            subtitle: 'Gerar um arquivo .zip com dados, cat\u00e1logos e fotos.',
            onTap: () {
              ref.read(productExportViewModelProvider.notifier).exportPackage();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Gerando backup completo em segundo plano...'),
                  backgroundColor: AppTokens.accentBlue,
                ),
              );
            },
          ),
        ],
      ),
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
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
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
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
