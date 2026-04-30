import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:catalogo_ja/core/services/export_import_service.dart';
import 'package:catalogo_ja/viewmodels/catalogo_ja_import_viewmodel.dart';
import 'package:catalogo_ja/ui/theme/app_tokens.dart';
import 'package:catalogo_ja/viewmodels/settings_viewmodel.dart';
import 'package:catalogo_ja/core/utils/user_friendly_error.dart';

class CatalogoJaImportScreen extends ConsumerStatefulWidget {
  const CatalogoJaImportScreen({super.key});

  @override
  ConsumerState<CatalogoJaImportScreen> createState() =>
      _CatalogoJaImportScreenState();
}
class _CatalogoJaImportScreenState
    extends ConsumerState<CatalogoJaImportScreen> {
  bool _markedDone = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(catalogoJaImportViewModelProvider);
    final viewModel = ref.read(catalogoJaImportViewModelProvider.notifier);

    // Auto-marca isInitialSyncCompleted quando importação conclui com sucesso
    if (state.step == 2 &&
        state.result != null &&
        state.result!.successCount > 0 &&
        !_markedDone) {
      _markedDone = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref
            .read(settingsViewModelProvider.notifier)
            .updateSettings(isInitialSyncCompleted: true);
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Restaurar Backup'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            viewModel.reset();
            if (context.canPop()) context.pop();
          },
        ),
      ),
      body: _buildBody(context, state, viewModel),
    );
  }

  Widget _buildBody(
    BuildContext context,
    CatalogoJaImportState state,
    CatalogoJaImportViewModel viewModel,
  ) {
    if (state.isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 20),
              Text(
                'Processando backup...',
                style: TextStyle(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                'Isso pode levar alguns minutos. Mantenha o aplicativo aberto.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
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
                softWrap: true,
                overflow: TextOverflow.visible,
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
    CatalogoJaImportViewModel viewModel,
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
              'Selecione o backup para restaurar',
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
    CatalogoJaImportState state,
    CatalogoJaImportViewModel viewModel,
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
            'Resumo do Conte\u00fado',
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
          _buildStatRow('Cole\u00e7\u00f5es', '${preview.totalCollectionsInFile}'),

          const Divider(height: 32),

          Text(
            'Modo de Importa\u00e7\u00e3o',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 16),

          _buildModeOption(
            context,
            mode: ImportMode.merge,
            title: 'Mesclar (Padr\u00e3o)',
            description:
                'Atualiza produtos existentes (pelo REF) e cria novos. Mant\u00e9m IDs locais e restaura fotos se dispon\u00edveis.',
            groupValue: state.selectedMode,
            onChanged: (v) => viewModel.setMode(v!),
          ),
          _buildModeOption(
            context,
            mode: ImportMode.onlyNew,
            title: 'Somente Novos',
            description:
                'Ignora produtos que j\u00e1 existem (pelo REF). Importa apenas os novos.',
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
                    ? 'CONFIRMAR SUBSTITUI\u00c7\u00c3O TOTAL'
                    : 'Confirmar Importa\u00e7\u00e3o',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultStep(
    BuildContext context,
    CatalogoJaImportState state,
    CatalogoJaImportViewModel viewModel,
  ) {
    final result = state.result!;
    final hasSuccess = result.successCount > 0;
    final hasErrors = result.errorCount > 0 || result.errors.isNotEmpty;
    final title = hasSuccess
        ? (hasErrors
              ? 'Importa\u00e7\u00e3o conclu\u00edda com avisos'
              : 'Importa\u00e7\u00e3o conclu\u00edda')
        : (hasErrors ? 'Importa\u00e7\u00e3o n\u00e3o conclu\u00edda' : 'Nenhum item importado');
    final icon = hasSuccess
        ? (hasErrors ? Icons.warning_amber_rounded : Icons.check_circle)
        : Icons.error_outline;
    final iconColor = hasSuccess
        ? (hasErrors ? Colors.orange : Colors.green)
        : Colors.red;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: iconColor,
              size: 80,
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
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
                    ...result.errors.take(3).map(
                          (e) => Text(
                            UserFriendlyError.message(
                              e,
                              fallback:
                                  'Um item n\u00e3o p\u00f4de ser importado. Revise o backup e tente novamente.',
                            ),
                            style: const TextStyle(fontSize: 12),
                            softWrap: true,
                            overflow: TextOverflow.visible,
                          ),
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
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/admin/imports');
                }
              },
              child: const Text('Concluir'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                viewModel.reset();
                context.go('/admin/dashboard');
              },
              child: const Text('Ir para o Início'),
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
