import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:catalogo_ja/ui/widgets/app_scaffold.dart';
import 'package:catalogo_ja/ui/theme/app_tokens.dart';

class ImportMenuScreen extends StatelessWidget {
  const ImportMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
          _buildItem(
            context,
            icon: Icons.storage_rounded,
            title: 'Migra\u00e7\u00e3o de Storage',
            subtitle: 'Mover fotos do Firebase para o servidor MinIO local.',
            route: '/admin/imports/storage-migration',
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
          child: const Icon(Icons.import_export, color: AppTokens.accentBlue),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push(route),
      ),
    );
  }
}
