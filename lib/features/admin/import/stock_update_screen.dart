import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:catalogo_ja/viewmodels/product_import_viewmodel.dart';
import 'package:catalogo_ja/ui/widgets/app_scaffold.dart';
import 'package:catalogo_ja/ui/widgets/app_primary_button.dart';
import 'package:catalogo_ja/ui/theme/app_tokens.dart';

class StockUpdateScreen extends ConsumerStatefulWidget {
  const StockUpdateScreen({super.key});

  @override
  ConsumerState<StockUpdateScreen> createState() => _StockUpdateScreenState();
}

class _StockUpdateScreenState extends ConsumerState<StockUpdateScreen> {
  final _controller = TextEditingController();
  StockUpdateReport? _report;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _process() async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cole o texto primeiro')),
      );
      return;
    }

    try {
      final result = await ref
          .read(productImportViewModelProvider.notifier)
          .updateStockFromPdfText(text);

      setState(() {
        _report = result;
      });
      
      if (mounted && result.updatedCount > 0) {
         ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${result.updatedCount} itens atualizados!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(productImportViewModelProvider);

    return AppScaffold(
      title: 'Atualizar Estoque (PDF)',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTokens.space24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Cole aqui o texto extra\u00eddo do seu relat\u00f3rio em PDF.',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppTokens.space8),
            const Text(
              'O sistema vai procurar refer\u00eancias no padr\u00e3o:\nREF - DESCRI\u00c7\u00c3O - COR - TAM UN QTDE',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: AppTokens.space16),
            TextField(
              controller: _controller,
              maxLines: 15,
              decoration: InputDecoration(
                hintText: 'Exemplo:\n106544 - CROPPED LISTRADO LUREX - BEGE - G UN 3',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
            ),
            const SizedBox(height: AppTokens.space24),
            if (state.isLoading)
              Column(
                children: [
                  LinearProgressIndicator(value: state.progress),
                  const SizedBox(height: AppTokens.space8),
                  Text(state.message ?? 'Processando...'),
                ],
              )
            else
              AppPrimaryButton(
                label: 'Processar Agora',
                onPressed: state.isLoading ? null : _process,
              ),
            if (_report != null) ...[
              const SizedBox(height: AppTokens.space24),
              _buildReportView(_report!),
            ],
            if (state.errorMessage != null) ...[
              const SizedBox(height: AppTokens.space16),
              Container(
                padding: const EdgeInsets.all(AppTokens.space16),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  state.errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReportView(StockUpdateReport report) {
    return Container(
      padding: const EdgeInsets.all(AppTokens.space16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics, color: Colors.blue[900]),
              const SizedBox(width: 8),
              Text(
                'Resultado do Processamento',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[900],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.space8),
          Text('✅ ${report.updatedCount} itens atualizados no estoque.'),
          if (report.hasErrors) ...[
            const SizedBox(height: AppTokens.space16),
            Text(
              '⚠️ ${report.errors.length} itens ignorados (n\u00e3o encontrados):',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
            ),
            const SizedBox(height: 4),
            SizedBox(
              maxHeight: 200,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: report.errors.length.clamp(0, 10),
                itemBuilder: (context, index) => Text(
                  '\u2022 ${report.errors[index]}',
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            ),
            if (report.errors.length > 10)
              const Text('... e outros.', style: TextStyle(fontSize: 10)),
          ],
        ],
      ),
    );
  }
}
