import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:catalogo_ja/ui/widgets/app_scaffold.dart';
import 'package:catalogo_ja/ui/theme/app_tokens.dart';
import '../../../viewmodels/storage_migration_viewmodel.dart';
import 'package:intl/intl.dart';

class StorageMigrationScreen extends ConsumerWidget {
  const StorageMigrationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(storageMigrationViewModelProvider);
    final viewModel = ref.read(storageMigrationViewModelProvider.notifier);

    return AppScaffold(
      title: 'Migra\u00e7\u00e3o de Storage',
      body: Padding(
        padding: const EdgeInsets.all(AppTokens.space24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoCard(context),
            const SizedBox(height: AppTokens.space24),
            _buildProgressCard(context, state, viewModel),
            const SizedBox(height: AppTokens.space24),
            const Text(
              'Logs de Migração',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: AppTokens.space8),
            Expanded(child: _buildLogsList(state)),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTokens.space16),
      decoration: BoxDecoration(
        color: AppTokens.accentBlue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        border: Border.all(color: AppTokens.accentBlue.withOpacity(0.2)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: AppTokens.accentBlue),
          SizedBox(width: AppTokens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Como funciona?',
                  style: TextStyle(fontWeight: FontWeight.bold, color: AppTokens.accentBlue),
                ),
                SizedBox(height: 4),
                Text(
                  'Este processo varre todos os seus produtos, categorias e catálogos procurando por imagens salvas no Firebase. Ele baixa cada uma e as reenvia para o seu novo servidor MinIO, atualizando os links automaticamente.',
                  style: TextStyle(fontSize: 13, height: 1.4),
                ),
                SizedBox(height: 8),
                Text(
                  'IMPORTANTE: O seu servidor MinIO deve estar ligado e acessível.',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard(BuildContext context, MigrationState state, StorageMigrationViewModel viewModel) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.space20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Status do Processo', style: TextStyle(color: Colors.grey, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text(
                      state.isRunning ? 'EM EXECU\u00c7\u00c3O...' : (state.processedItems > 0 ? 'CONCLU\u00cdDO' : 'AGUARDANDO'),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: state.isRunning ? AppTokens.accentBlue : Colors.grey,
                      ),
                    ),
                  ],
                ),
                if (state.totalItems > 0)
                  Text(
                    '${state.processedItems} / ${state.totalItems}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
              ],
            ),
            const SizedBox(height: AppTokens.space24),
            LinearProgressIndicator(
              value: state.progress,
              backgroundColor: Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
              minHeight: 8,
            ),
            const SizedBox(height: AppTokens.space12),
            if (state.currentItem != null)
              Text(
                'Processando: ${state.currentItem}',
                style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: AppTokens.space24),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: state.isRunning ? null : () => viewModel.startMigration(),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('INICIAR MIGRA\u00c7\u00c3O'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: AppTokens.accentBlue,
                    ),
                  ),
                ),
                if (state.isRunning) ...[
                  const SizedBox(width: AppTokens.space12),
                  IconButton.filledTonal(
                    onPressed: () => viewModel.stop(),
                    icon: const Icon(Icons.stop, color: Colors.red),
                    style: IconButton.styleFrom(padding: const EdgeInsets.all(16)),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogsList(MigrationState state) {
    if (state.logs.isEmpty) {
      return Center(
        child: Text(
          'Nenhum log disponível',
          style: TextStyle(color: Colors.grey.withOpacity(0.5)),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.02),
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: ListView.separated(
        padding: const EdgeInsets.all(AppTokens.space12),
        itemCount: state.logs.length,
        separatorBuilder: (_, __) => const Divider(height: 12, color: Colors.transparent),
        itemBuilder: (context, index) {
          final log = state.logs[index];
          final timeStr = DateFormat('HH:mm:ss').format(log.timestamp);
          
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('[$timeStr]', style: const TextStyle(color: Colors.grey, fontSize: 10, fontFamily: 'monospace')),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  log.message,
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                    color: log.isError ? Colors.red : null,
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
