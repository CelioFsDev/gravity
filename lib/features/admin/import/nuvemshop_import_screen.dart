import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:catalogo_ja/core/importer/nuvemshop_api_client.dart';
import 'package:catalogo_ja/core/importer/nuvemshop_csv_reader.dart';
import 'package:catalogo_ja/core/importer/nuvemshop_forward_fill.dart';
import 'package:catalogo_ja/core/importer/nuvemshop_import_service.dart';
import 'package:catalogo_ja/core/services/image_cache_service.dart';
import 'package:catalogo_ja/data/repositories/categories_repository.dart';
import 'package:catalogo_ja/data/repositories/products_repository.dart';
import 'package:catalogo_ja/ui/theme/app_tokens.dart';
import 'package:catalogo_ja/ui/widgets/app_scaffold.dart';
import 'package:catalogo_ja/ui/widgets/section_card.dart';
import 'package:catalogo_ja/ui/widgets/app_primary_button.dart';
import 'package:catalogo_ja/viewmodels/products_viewmodel.dart';
import 'package:catalogo_ja/viewmodels/categories_viewmodel.dart';
import 'package:catalogo_ja/viewmodels/catalogs_viewmodel.dart';
import 'package:catalogo_ja/viewmodels/catalog_public_viewmodel.dart';

class NuvemshopImportScreen extends ConsumerStatefulWidget {
  const NuvemshopImportScreen({super.key});

  @override
  ConsumerState<NuvemshopImportScreen> createState() =>
      _NuvemshopImportScreenState();
}

class _NuvemshopImportScreenState extends ConsumerState<NuvemshopImportScreen> {
  PlatformFile? _selectedFile;
  ImportTable? _preview;
  bool _loading = false;
  double _progress = 0.0;
  String _statusText = '';
  ImportReport? _report;
  final _storeIdController = TextEditingController();
  final _tokenController = TextEditingController();

  Future<void> _pickFile() async {
    setState(() {
      _report = null;
      _preview = null;
    });
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      // allowedExtensions: ['csv'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (!file.name.toLowerCase().endsWith('.csv')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Formato invalido. Selecione um arquivo .csv.')),
        );
      }
      return;
    }
    final table = await NuvemshopCsvReader.readFromPlatformFile(file);
    final filled = forwardFill(table.rows, const [
      'Nome',
      'Categorias',
      'Pre\u00e7o',
      'Pre\u00e7o promocional',
      'Descri\u00e7\u00e3o',
      'Tags',
    ]);
    setState(() {
      _selectedFile = file;
      _preview = ImportTable(headers: table.headers, rows: filled);
    });
  }

  Future<void> _import() async {
    final file = _selectedFile;
    if (file == null) return;
    setState(() {
      _loading = true;
      _progress = 0.0;
      _statusText = 'Preparando importa\u00e7\u00e3o...';
    });

    final storeId = _storeIdController.text.trim();
    final token = _tokenController.text.trim();
    final service = NuvemshopImportService(
      productsRepository: ref.read(productsRepositoryProvider),
      categoriesRepository: ref.read(categoriesRepositoryProvider),
      imageCacheService: ref.read(imageCacheServiceProvider),
      nuvemshopApiClient: (storeId.isNotEmpty && token.isNotEmpty)
          ? NuvemshopApiClient(storeId: storeId, accessToken: token)
          : null,
    );

    try {
      debugPrint('Iniciando _import no Screen');
      final report = await service.importCsvFile(
        file,
        onProgress: (p) => setState(() => _progress = p),
        onStatus: (status) => setState(() => _statusText = status),
      );
      debugPrint(
        'Importa\u00e7\u00e3o conclu\u00edda: ${report.createdCount} criados, ${report.updatedCount} atualizados',
      );
      setState(() {
        _report = report;
        _statusText = report.warnings.isNotEmpty
            ? 'Importa\u00e7\u00e3o conclu\u00edda com avisos.'
            : 'Importa\u00e7\u00e3o conclu\u00edda.';
      });
      ref.invalidate(productsViewModelProvider);
      ref.invalidate(categoriesViewModelProvider);
      ref.invalidate(catalogsViewModelProvider);
      ref.invalidate(catalogPublicProvider);
    } catch (e, stack) {
      debugPrint('Erro na importa\u00e7\u00e3o: $e\n$stack');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro na importa\u00e7\u00e3o: $e'),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(label: 'OK', onPressed: () {}),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  void dispose() {
    _storeIdController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final previewRows = _preview?.rows.take(5).toList() ?? [];

    return AppScaffold(
      title: 'Importar Nuvemshop',
      subtitle: 'Traga seus produtos via CSV',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTokens.space24),
        child: Column(
          children: [
            _buildInstructions(),
            const SizedBox(height: 24),
            _buildFileSelection(),
            const SizedBox(height: 24),
            _buildApiConfig(),
            if (previewRows.isNotEmpty) ...[
              const SizedBox(height: 24),
              _buildPreview(previewRows),
            ],
            if (_report != null) ...[
              const SizedBox(height: 24),
              _buildReport(),
            ],
            const SizedBox(height: 32),
            if (_loading) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _progress > 0 ? _progress : null,
                  backgroundColor: AppTokens.borderLight,
                  valueColor: const AlwaysStoppedAnimation(
                    AppTokens.accentBlue,
                  ),
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 16),
              if (_statusText.isNotEmpty)
                Text(
                  _statusText,
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 16),
            ],
            SizedBox(
              width: double.infinity,
              child: AppPrimaryButton(
                label: _loading ? 'Importando...' : 'Iniciar Importa\u00e7\u00e3o',
                onPressed: _selectedFile == null || _loading ? null : _import,
                icon: Icons.cloud_download_outlined,
              ),
            ),
            if (_report != null && !_loading) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.inventory_2_outlined),
                  label: const Text('Voltar para Produtos'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: () => context.go('/admin/products'),
                  icon: const Icon(Icons.menu),
                  label: const Text('Voltar para o Menu'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInstructions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: Colors.orange, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Importe o CSV exportado em Produtos > Lista de produtos > Exportar em sua Nuvemshop.\n\n'
              'Importante: O pre\u00e7o de atacado n\u00e3o \u00e9 exportado pela Nuvemshop. Ap\u00f3s a importa\u00e7\u00e3o, revise os valores no editor de produtos.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileSelection() {
    return SectionCard(
      title: 'Arquivo de Origem',
      child: Column(
        children: [
          InkWell(
            onTap: _loading ? null : _pickFile,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                border: Border.all(
                  color: AppTokens.border,
                  style: BorderStyle.solid,
                ),
                borderRadius: BorderRadius.circular(12),
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              child: Column(
                children: [
                  Icon(
                    _selectedFile == null
                        ? Icons.upload_file_outlined
                        : Icons.check_circle_outline,
                    size: 48,
                    color: _selectedFile == null
                        ? Theme.of(context).colorScheme.onSurfaceVariant
                        : AppTokens.accentGreen,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _selectedFile == null
                        ? 'Clique para selecionar o CSV'
                        : _selectedFile!.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                  ),
                  if (_selectedFile != null)
                    Text(
                      '${(_selectedFile!.size / 1024).toStringAsFixed(1)} KB',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApiConfig() {
    return SectionCard(
      title: 'API Nuvemshop (Opcional)',
      child: Column(
        children: [
          TextField(
            controller: _storeIdController,
            enabled: !_loading,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Store ID',
              hintText: 'Ex: 123456',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _tokenController,
            enabled: !_loading,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Access Token',
              hintText: 'Token da API Nuvemshop',
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Se preencher, o importador busca imagens pela API quando o CSV n\u00e3o tiver URL da imagem.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview(List<Map<String, String>> previewRows) {
    return SectionCard(
      title: 'Pr\u00e9via dos Dados',
      child: Column(
        children: previewRows.map((row) {
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListTile(
              dense: true,
              title: Text(
                row['Nome'] ?? '-',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                'SKU: ${row['SKU'] ?? '-'} | Pre\u00e7o: ${row['Pre\u00e7o'] ?? '-'}',
                style: const TextStyle(fontSize: 11),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildReport() {
    return SectionCard(
      title: 'Relat\u00f3rio de Importa\u00e7\u00e3o',
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildReportStat(
                'Criados',
                _report!.createdCount,
                AppTokens.accentGreen,
              ),
              _buildReportStat(
                'Atualizados',
                _report!.updatedCount,
                AppTokens.accentBlue,
              ),
              _buildReportStat(
                'Varia\u00e7\u00f5es',
                _report!.variantsCount,
                AppTokens.accentPurple,
              ),
            ],
          ),
          if (_report!.warnings.isNotEmpty) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _report!.warnings.take(3).join('\n'),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.orange.shade800),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReportStat(String label, int value, Color color) {
    return Column(
      children: [
        Text(
          value.toString(),
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppTokens.textMuted),
        ),
      ],
    );
  }
}
