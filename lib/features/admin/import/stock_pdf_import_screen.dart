import 'dart:typed_data';
import 'package:catalogo_ja/models/stock_pdf_row.dart';
import 'package:catalogo_ja/ui/widgets/app_error_view.dart';
import 'package:catalogo_ja/ui/widgets/app_primary_button.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:catalogo_ja/viewmodels/stock_import_viewmodel.dart';
import 'package:catalogo_ja/models/stock_import_history.dart';

class StockPdfImportScreen extends ConsumerStatefulWidget {
  const StockPdfImportScreen({super.key});

  @override
  ConsumerState<StockPdfImportScreen> createState() => _StockPdfImportScreenState();
}

class _StockPdfImportScreenState extends ConsumerState<StockPdfImportScreen> {
  int _currentStep = 0;

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );

    if (result != null && result.files.single.bytes != null) {
      final bytes = result.files.single.bytes!;
      final name = result.files.single.name;
      
      await ref.read(stockImportViewModelProvider.notifier).processPdf(bytes, name);
      setState(() {
        _currentStep = 1;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(stockImportViewModelProvider);
    final notifier = ref.read(stockImportViewModelProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Importar Estoque (PDF)'),
      ),
      body: state.isProcessing 
          ? const Center(child: CircularProgressIndicator())
          : state.error != null
              ? AppErrorView(
                  error: state.error!,
                  onRetry: () => notifier.clear(),
                )
              : state.isApplied
                  ? _buildSuccessView()
                  : Stepper(
                      currentStep: _currentStep,
                      onStepContinue: () {
                        if (_currentStep == 0 && state.rows.isNotEmpty) {
                          setState(() => _currentStep = 1);
                        } else if (_currentStep == 1) {
                          setState(() => _currentStep = 2);
                        } else if (_currentStep == 2) {
                          notifier.applyImport();
                        }
                      },
                      onStepCancel: () {
                        if (_currentStep > 0) {
                          setState(() => _currentStep -= 1);
                        }
                      },
                      steps: [
                        Step(
                          title: const Text('Selecionar Arquivo'),
                          content: _buildStepUpload(state),
                          isActive: _currentStep >= 0,
                        ),
                        Step(
                          title: const Text('Configurações e Resumo'),
                          content: _buildStepSummary(state, notifier),
                          isActive: _currentStep >= 1,
                        ),
                        Step(
                          title: const Text('Prévia e Correções'),
                          content: _buildStepPreview(state, notifier),
                          isActive: _currentStep >= 2,
                        ),
                      ],
                    ),
    );
  }

  Widget _buildStepUpload(StockImportState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Selecione o arquivo PDF do sistema para importar os saldos de estoque.'),
        const SizedBox(height: 16),
        AppPrimaryButton(
          onPressed: _pickFile,
          label: 'Escolher PDF',
          icon: Icons.upload_file,
        ),
        if (state.fileName != null) ...[
          const SizedBox(height: 16),
          Text('Arquivo selecionado: ${state.fileName}', style: const TextStyle(fontWeight: FontWeight.bold)),
        ]
      ],
    );
  }

  Widget _buildStepSummary(StockImportState state, StockImportViewModel notifier) {
    if (state.metadata == null) return const SizedBox();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Empresa/Loja: ${state.metadata!.companyName ?? state.metadata!.companyCode ?? "Desconhecida"}'),
                Text('Linhas lidas: ${state.rows.length}'),
                Text('Total de Peças no PDF: ${state.metadata!.totalQuantity ?? "N/A"}'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text('Modo de Importação', style: TextStyle(fontWeight: FontWeight.bold)),
        DropdownButton<StockImportMode>(
          value: state.mode,
          isExpanded: true,
          items: const [
            DropdownMenuItem(value: StockImportMode.replace, child: Text('Substituir estoque pelo PDF')),
            DropdownMenuItem(value: StockImportMode.add, child: Text('Somar estoque do PDF')),
            DropdownMenuItem(value: StockImportMode.subtract, child: Text('Subtrair estoque do PDF')),
            DropdownMenuItem(value: StockImportMode.verify, child: Text('Apenas Conferir')),
          ],
          onChanged: (mode) {
            if (mode != null) notifier.setMode(mode);
          },
        ),
      ],
    );
  }

  Widget _buildStepPreview(StockImportState state, StockImportViewModel notifier) {
    if (state.rows.isEmpty) return const Text('Nenhuma linha encontrada.');

    return SizedBox(
      height: 400,
      child: ListView.builder(
        itemCount: state.rows.length,
        itemBuilder: (context, index) {
          final row = state.rows[index];
          final hasError = row.status != StockPdfRowStatus.ok;
          
          return Card(
            color: hasError ? Colors.red[50] : null,
            child: ListTile(
              leading: Checkbox(
                value: row.selected,
                onChanged: row.status == StockPdfRowStatus.negativeStock || row.status == StockPdfRowStatus.productNotFound 
                   ? null 
                   : (v) => notifier.toggleRowSelection(index),
              ),
              title: Text('${row.reference} - ${row.colorName} - ${row.size}'),
              subtitle: Text(
                hasError ? 'ERRO: ${row.status.name}' : '${row.currentStock} -> ${row.finalStock}',
                style: TextStyle(color: hasError ? Colors.red : Colors.green, fontWeight: FontWeight.bold),
              ),
              trailing: Text('Lido: ${row.quantity}', style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSuccessView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 64),
          const SizedBox(height: 16),
          const Text('Importação concluída com sucesso!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          AppPrimaryButton(
            onPressed: () {
              ref.read(stockImportViewModelProvider.notifier).clear();
              setState(() => _currentStep = 0);
            },
            label: 'Fazer nova importação',
          ),
        ],
      ),
    );
  }
}
