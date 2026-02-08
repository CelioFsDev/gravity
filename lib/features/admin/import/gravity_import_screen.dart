import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gravity/core/services/export_import_service.dart';
import 'package:gravity/viewmodels/gravity_import_viewmodel.dart';
import 'package:gravity/ui/theme/app_tokens.dart';

class GravityImportScreen extends ConsumerWidget {
  const GravityImportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gravityImportViewModelProvider);
    final viewModel = ref.read(gravityImportViewModelProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Importar Backup (Gravity)'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            viewModel.reset();
            Navigator.of(context).pop();
          },
        ),
      ),
      body: _buildBody(context, ref, state, viewModel),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    GravityImportState state,
    GravityImportViewModel viewModel,
  ) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text('Erro', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                state.errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => viewModel.reset(),
                child: const Text('Tentar Novamente'),
              ),
            ],
          ),
        ),
      );
    }

    switch (state.step) {
      case 0:
        return _buildPickerStep(context, viewModel);
      case 1:
        return _buildPreviewStep(context, state, viewModel);
      case 2:
        return _buildResultStep(context, state, viewModel);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildPickerStep(
    BuildContext context,
    GravityImportViewModel viewModel,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.restore_page_outlined,
              size: 80,
              color: AppTokens.accentBlue,
            ),
            const SizedBox(height: 24),
            Text(
              'Selecione o arquivo de backup',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'O arquivo deve ser um ZIP (backup completo com fotos) ou JSON (apenas dados).',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: viewModel.pickFile,
              icon: const Icon(Icons.folder_open),
              label: const Text('Buscar Arquivo'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewStep(
    BuildContext context,
    GravityImportState state,
    GravityImportViewModel viewModel,
  ) {
    final preview = state.preview!;
    final payload = state.payload!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, color: AppTokens.accentBlue),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Arquivo carregado com sucesso!',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Exportado em: ${payload.exportedAt.split("T").first}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
          const Divider(height: 32),

          Text(
            'Resumo do Conteúdo',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 16),
          _buildStatRow('Total de Produtos', '${preview.totalProductsInFile}'),
          _buildStatRow(
            'Novos Produtos (Identificados)',
            '${preview.newProductsCount}',
            isGood: true,
          ),
          _buildStatRow(
            'Produtos Existentes (Conflito de REF)',
            '${preview.updatedProductsCount}',
            isWarning: true,
          ),
          const SizedBox(height: 8),
          _buildStatRow('Categorias', '${preview.totalCategoriesInFile}'),
          _buildStatRow('Coleções', '${preview.totalCollectionsInFile}'),

          const Divider(height: 32),

          Text(
            'Modo de Importação',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 16),

          _buildModeOption(
            context,
            mode: ImportMode.merge,
            title: 'Mesclar (Padrão)',
            description:
                'Atualiza produtos existentes (pelo REF) e cria novos. Mantém IDs locais e restaura fotos se disponíveis.',
            groupValue: state.selectedMode,
            onChanged: (v) => viewModel.setMode(v!),
          ),
          _buildModeOption(
            context,
            mode: ImportMode.onlyNew,
            title: 'Somente Novos',
            description:
                'Ignora produtos que já existem (pelo REF). Importa apenas os novos.',
            groupValue: state.selectedMode,
            onChanged: (v) => viewModel.setMode(v!),
          ),
          _buildModeOption(
            context,
            mode: ImportMode.replaceAll,
            title: 'Substituir Tudo (CUIDADO)',
            description:
                'APAGA todos os produtos e categorias locais antes de importar.',
            isDestructive: true,
            groupValue: state.selectedMode,
            onChanged: (v) => viewModel.setMode(v!),
          ),

          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: viewModel.executeImport,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: state.selectedMode == ImportMode.replaceAll
                    ? Colors.red
                    : AppTokens.accentBlue,
              ),
              child: Text(
                state.selectedMode == ImportMode.replaceAll
                    ? 'CONFIRMAR SUBSTITUIÇÃO TOTAL'
                    : 'Confirmar Importação',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultStep(
    BuildContext context,
    GravityImportState state,
    GravityImportViewModel viewModel,
  ) {
    final result = state.result!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 80),
            const SizedBox(height: 24),
            Text(
              'Importação Concluída!',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 32),
            _buildStatRow(
              'Sucesso',
              '${result.successCount}',
              isGood: true,
              center: true,
            ),
            _buildStatRow('Ignorados', '${result.skipCount}', center: true),
            _buildStatRow(
              'Erros',
              '${result.errorCount}',
              isDestructive: true,
              center: true,
            ),

            if (result.errors.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Erros:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    ...result.errors
                        .take(3)
                        .map(
                          (e) => Text(e, style: const TextStyle(fontSize: 12)),
                        ),
                    if (result.errors.length > 3) const Text('...'),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                viewModel.reset();
                Navigator.of(context).pop();
              },
              child: const Text('Voltar para Produtos'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(
    String label,
    String value, {
    bool isGood = false,
    bool isWarning = false,
    bool isDestructive = false,
    bool center = false,
  }) {
    Color color = Colors.black87;
    if (isGood) color = Colors.green;
    if (isWarning) color = Colors.orange;
    if (isDestructive) color = Colors.red;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: center
            ? MainAxisAlignment.center
            : MainAxisAlignment.start,
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildModeOption(
    BuildContext context, {
    required ImportMode mode,
    required String title,
    required String description,
    required ImportMode groupValue,
    required ValueChanged<ImportMode?> onChanged,
    bool isDestructive = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border.all(
          color: groupValue == mode
              ? (isDestructive ? Colors.red : AppTokens.accentBlue)
              : Colors.grey.shade300,
          width: groupValue == mode ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(8),
        color: groupValue == mode
            ? (isDestructive
                  ? Colors.red.withOpacity(0.05)
                  : Colors.blue.withOpacity(0.05))
            : null,
      ),
      child: RadioListTile<ImportMode>(
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDestructive ? Colors.red : null,
          ),
        ),
        subtitle: Text(description),
        value: mode,
        groupValue: groupValue,
        onChanged: onChanged,
        activeColor: isDestructive ? Colors.red : AppTokens.accentBlue,
      ),
    );
  }
}
