import 'package:catalogo_ja/features/admin/order_import/presentation/order_pdf_import_viewmodel.dart';
import 'package:catalogo_ja/models/product.dart';
import 'package:catalogo_ja/ui/theme/app_tokens.dart';
import 'package:catalogo_ja/ui/widgets/app_primary_button.dart';
import 'package:catalogo_ja/ui/widgets/app_scaffold.dart';
import 'package:catalogo_ja/ui/widgets/section_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class OrderPdfImportPage extends ConsumerStatefulWidget {
  const OrderPdfImportPage({super.key});

  @override
  ConsumerState<OrderPdfImportPage> createState() => _OrderPdfImportPageState();
}

class _OrderPdfImportPageState extends ConsumerState<OrderPdfImportPage> {
  late final TextEditingController _catalogNameController;

  @override
  void initState() {
    super.initState();
    final initialState = ref.read(orderPdfImportViewModelProvider);
    _catalogNameController = TextEditingController(
      text: initialState.catalogName,
    );
  }

  @override
  void dispose() {
    _catalogNameController.dispose();
    super.dispose();
  }

  Future<void> _confirmAndCreate(OrderPdfImportState state) async {
    if (state.referencesNotFound.isNotEmpty) {
      final shouldContinue = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Referências não encontradas'),
          content: Text(
            '${state.referencesNotFound.length} referência(s) não foram encontradas no cadastro. '
            'O catálogo será criado somente com os produtos encontrados.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Criar catálogo'),
            ),
          ],
        ),
      );

      if (shouldContinue != true) return;
    }

    await ref.read(orderPdfImportViewModelProvider.notifier).createCatalog();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(orderPdfImportViewModelProvider);
    final notifier = ref.read(orderPdfImportViewModelProvider.notifier);

    return AppScaffold(
      title: 'Importar pedido por PDF',
      subtitle: 'Criar catálogo a partir das referências do pedido',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTokens.space24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildPdfPicker(context, state, notifier),
            const SizedBox(height: AppTokens.space24),
            _buildStatusCard(context, state),
            if (state.references.isNotEmpty) ...[
              const SizedBox(height: AppTokens.space24),
              _buildReferenceList(context, state.references),
            ],
            if (state.productsFound.isNotEmpty) ...[
              const SizedBox(height: AppTokens.space24),
              _buildProductList(context, state.productsFound),
            ],
            if (state.referencesNotFound.isNotEmpty) ...[
              const SizedBox(height: AppTokens.space24),
              _buildMissingReferences(context, state.referencesNotFound),
            ],
            if (state.productsFound.isNotEmpty) ...[
              const SizedBox(height: AppTokens.space24),
              _buildCreateCatalog(context, state),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPdfPicker(
    BuildContext context,
    OrderPdfImportState state,
    OrderPdfImportViewModel notifier,
  ) {
    final selectedFileName = state.selectedFileName;

    return SectionCard(
      title: 'PDF do pedido',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OutlinedButton.icon(
            onPressed: state.isBusy ? null : notifier.pickAndParsePdf,
            icon: state.isBusy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.picture_as_pdf_outlined),
            label: Text(
              state.isBusy ? 'Processando PDF...' : 'Selecionar PDF do pedido',
            ),
          ),
          if (selectedFileName != null) ...[
            const SizedBox(height: AppTokens.space12),
            Row(
              children: [
                const Icon(Icons.description_outlined, size: 18),
                const SizedBox(width: AppTokens.space8),
                Expanded(
                  child: Text(
                    selectedFileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                if (state.selectedFileSize != null)
                  Text(
                    _formatFileSize(state.selectedFileSize!),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusCard(BuildContext context, OrderPdfImportState state) {
    final statusData = _statusData(state);
    final color = statusData.color;

    return SectionCard(
      title: 'Status',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(statusData.icon, color: color),
              const SizedBox(width: AppTokens.space12),
              Expanded(
                child: Text(
                  statusData.text,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          if (state.errorMessage != null) ...[
            const SizedBox(height: AppTokens.space12),
            Text(
              state.errorMessage!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (state.references.isNotEmpty || state.productsFound.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppTokens.space16),
              child: Wrap(
                spacing: AppTokens.space8,
                runSpacing: AppTokens.space8,
                children: [
                  _StatChip(
                    label: 'Referências',
                    value: state.references.length.toString(),
                    color: AppTokens.accentBlue,
                  ),
                  _StatChip(
                    label: 'Produtos',
                    value: state.productsFound.length.toString(),
                    color: AppTokens.accentGreen,
                  ),
                  _StatChip(
                    label: 'Não encontradas',
                    value: state.referencesNotFound.length.toString(),
                    color: AppTokens.accentOrange,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReferenceList(BuildContext context, List<String> references) {
    return SectionCard(
      title: 'Referências encontradas (${references.length})',
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 220),
        child: SingleChildScrollView(
          child: Wrap(
            spacing: AppTokens.space8,
            runSpacing: AppTokens.space8,
            children: references
                .map(
                  (reference) => Chip(
                    label: Text(reference),
                    visualDensity: VisualDensity.compact,
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildProductList(BuildContext context, List<Product> products) {
    return SectionCard(
      title: 'Produtos encontrados (${products.length})',
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: products.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final product = products[index];
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: AppTokens.accentGreen.withValues(alpha: 0.12),
              child: const Icon(
                Icons.check_rounded,
                color: AppTokens.accentGreen,
              ),
            ),
            title: Text(
              product.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text('REF ${product.reference}'),
          );
        },
      ),
    );
  }

  Widget _buildMissingReferences(
    BuildContext context,
    List<String> referencesNotFound,
  ) {
    return SectionCard(
      title: 'Referências não encontradas (${referencesNotFound.length})',
      child: Wrap(
        spacing: AppTokens.space8,
        runSpacing: AppTokens.space8,
        children: referencesNotFound
            .map(
              (reference) => Chip(
                label: Text(reference),
                visualDensity: VisualDensity.compact,
                backgroundColor: AppTokens.accentOrange.withValues(alpha: 0.12),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildCreateCatalog(BuildContext context, OrderPdfImportState state) {
    final isSuccess = state.status == OrderPdfImportStatus.success;

    return SectionCard(
      title: 'Criar catálogo',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _catalogNameController,
            enabled: !state.isBusy && !isSuccess,
            decoration: const InputDecoration(
              labelText: 'Nome do catálogo',
              border: OutlineInputBorder(),
            ),
            onChanged: ref
                .read(orderPdfImportViewModelProvider.notifier)
                .updateCatalogName,
          ),
          const SizedBox(height: AppTokens.space16),
          AppPrimaryButton(
            label: state.status == OrderPdfImportStatus.creatingCatalog
                ? 'Criando catálogo...'
                : isSuccess
                ? 'Catálogo criado'
                : 'Criar catálogo',
            icon: isSuccess ? Icons.check_circle_outline : Icons.add_outlined,
            onPressed: state.canCreate ? () => _confirmAndCreate(state) : null,
          ),
          if (isSuccess && state.createdCatalog != null) ...[
            const SizedBox(height: AppTokens.space12),
            Text(
              'Catálogo "${state.createdCatalog!.name}" criado com ${state.createdCatalog!.productIds.length} produto(s).',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppTokens.space8),
            TextButton.icon(
              onPressed: () => context.go('/admin/catalogs'),
              icon: const Icon(Icons.menu_book_outlined),
              label: const Text('Ver catálogos'),
            ),
          ],
        ],
      ),
    );
  }

  _StatusData _statusData(OrderPdfImportState state) {
    switch (state.status) {
      case OrderPdfImportStatus.idle:
        return const _StatusData(
          icon: Icons.upload_file_outlined,
          color: AppTokens.accentBlue,
          text: 'Aguardando seleção do PDF.',
        );
      case OrderPdfImportStatus.loadingPdf:
        return const _StatusData(
          icon: Icons.hourglass_empty_rounded,
          color: AppTokens.accentBlue,
          text: 'Lendo arquivo selecionado.',
        );
      case OrderPdfImportStatus.parsing:
        return const _StatusData(
          icon: Icons.manage_search_outlined,
          color: AppTokens.accentBlue,
          text: 'Extraindo texto e identificando referências.',
        );
      case OrderPdfImportStatus.readyToCreate:
        return const _StatusData(
          icon: Icons.check_circle_outline,
          color: AppTokens.accentGreen,
          text: 'Pronto para criar o catálogo.',
        );
      case OrderPdfImportStatus.creatingCatalog:
        return const _StatusData(
          icon: Icons.add_task_outlined,
          color: AppTokens.accentBlue,
          text: 'Criando catálogo.',
        );
      case OrderPdfImportStatus.success:
        return const _StatusData(
          icon: Icons.check_circle,
          color: AppTokens.accentGreen,
          text: 'Catálogo criado com sucesso.',
        );
      case OrderPdfImportStatus.error:
        return const _StatusData(
          icon: Icons.error_outline,
          color: Colors.red,
          text: 'Não foi possível concluir a importação.',
        );
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class _StatusData {
  final IconData icon;
  final Color color;
  final String text;

  const _StatusData({
    required this.icon,
    required this.color,
    required this.text,
  });
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.space12,
        vertical: AppTokens.space8,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: AppTokens.space8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
