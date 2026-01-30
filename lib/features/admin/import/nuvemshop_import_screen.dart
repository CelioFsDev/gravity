import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:gravity/core/importer/nuvemshop_csv_reader.dart';
import 'package:gravity/core/importer/nuvemshop_forward_fill.dart';
import 'package:gravity/core/importer/nuvemshop_import_service.dart';
import 'package:gravity/data/repositories/categories_repository.dart';
import 'package:gravity/data/repositories/products_repository.dart';

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
  ImportReport? _report;

  Future<void> _pickFile() async {
    setState(() {
      _report = null;
      _preview = null;
    });
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    final table = await NuvemshopCsvReader.readFromPlatformFile(file);
    final filled = forwardFill(table.rows, const [
      'Identificador URL',
      'Nome',
      'Categorias',
      'Preço',
      'Preço promocional',
      'Descrição',
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
    });

    final service = NuvemshopImportService(
      productsRepository: ref.read(productsRepositoryProvider),
      categoriesRepository: ref.read(categoriesRepositoryProvider),
    );

    try {
      final report = await service.importCsvFile(
        file,
        onProgress: (p) => setState(() => _progress = p),
      );
      setState(() {
        _report = report;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final previewRows = _preview?.rows.take(5).toList() ?? [];
    return Scaffold(
      appBar: AppBar(title: const Text('Importar Nuvemshop')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: Colors.orange),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Importe o CSV exportado em Produtos > Lista de produtos > Exportar.\n'
                      'O preco atacado nao vem da Nuvemshop. Após importar, revise o atacado no editor do produto.',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _loading ? null : _pickFile,
              icon: const Icon(Icons.upload_file),
              label: const Text('Selecionar CSV da Nuvemshop'),
            ),
            const SizedBox(height: 12),
            if (_selectedFile != null)
              Text(
                'Arquivo: ${_selectedFile!.name}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            if (previewRows.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Preview (5 linhas):',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: previewRows.length,
                  itemBuilder: (context, index) {
                    final row = previewRows[index];
                    return Card(
                      child: ListTile(
                        title: Text(row['Nome'] ?? '-'),
                        subtitle: Text(
                          'SKU: ${row['SKU'] ?? '-'} | Preco: ${row['Preço'] ?? '-'} | Categoria: ${row['Categorias'] ?? '-'}',
                        ),
                      ),
                    );
                  },
                ),
              ),
            ] else
              const Spacer(),
            if (_loading)
              LinearProgressIndicator(value: _progress > 0 ? _progress : null),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _selectedFile == null || _loading ? null : _import,
                child: const Text('Importar agora'),
              ),
            ),
            if (_report != null) ...[
              const SizedBox(height: 12),
              Text(
                'Criados: ${_report!.createdCount} | Atualizados: ${_report!.updatedCount} | Variacoes: ${_report!.variantsCount}',
              ),
              if (_report!.warnings.isNotEmpty)
                Text('Avisos: ${_report!.warnings.length}'),
            ],
          ],
        ),
      ),
    );
  }
}

