import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gravity/core/services/product_transfer_service.dart';
import 'package:gravity/viewmodels/product_import_viewmodel.dart';

class ProductImportScreen extends ConsumerWidget {
  const ProductImportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(productImportViewModelProvider);
    final viewModel = ref.read(productImportViewModelProvider.notifier);

    // If done, show success
    if (state.isDone) {
      return Scaffold(
        appBar: AppBar(title: const Text('Importação Concluída')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 64),
              const SizedBox(height: 16),
              Text(
                '${state.parsedProducts.length} produtos importados com sucesso!',
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Voltar para Produtos'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Importar Produtos')),
      body: Stepper(
        type: StepperType.horizontal,
        currentStep: state.currentStep,
        onStepContinue: () {
          if (state.currentStep < 2) {
            viewModel.nextStep();
          } else {
            viewModel.finalizeImport();
          }
        },
        onStepCancel: () {
          if (state.currentStep > 0) {
            viewModel.prevStep();
          } else {
            Navigator.of(context).pop();
          }
        },
        controlsBuilder: (context, details) {
          final isLastStep = state.currentStep == 2;
          return Padding(
            padding: const EdgeInsets.only(top: 24.0),
            child: Row(
              children: [
                if (state.isLoading)
                  const CircularProgressIndicator()
                else
                  FilledButton(
                    onPressed: details.onStepContinue,
                    child: Text(
                      isLastStep ? 'Finalizar Importação' : 'Próximo',
                    ),
                  ),
                const SizedBox(width: 16),
                if (!state.isLoading)
                  TextButton(
                    onPressed: details.onStepCancel,
                    child: const Text('Voltar'),
                  ),
              ],
            ),
          );
        },
        steps: [
          Step(
            title: const Text('Template'),
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('1. Baixe o modelo de planilha CSV abaixo.'),
                const Text(
                  '2. Preencha com os seus produtos mantendo a estrutura.',
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () {
                    ProductTransferService.saveTemplateCsv(context);
                  },
                  icon: const Icon(Icons.download),
                  label: const Text('Baixar Template CSV'),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Colunas: SKU, Name, REF, Category, RetailPrice, WholesalePrice(opcional), MinQty, Sizes, Colors, IsActive, IsOutOfStock, IsOnSale, SaleDiscountPercent, MainImageIndex, CreatedAt, ImageFiles',
                ),
                const SizedBox(height: 8),
                const Text(
                  'Na importacao Nuvemshop, o atacado nao e lido do CSV.',
                ),
              ],
            ),
            isActive: state.currentStep >= 0,
          ),
          Step(
            title: const Text('CSV Parsing'),
            content: Column(
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
                          'O preço atacado não vem da Nuvemshop. Após importar, revise o atacado conforme sua política.',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: viewModel.pickAndParseCsv,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Carregar CSV ou ZIP'),
                ),
                if (state.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      state.errorMessage!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),

                const SizedBox(height: 16),
                if (state.parsedProducts.isNotEmpty) ...[
                  Text(
                    'Produtos identificados: ${state.parsedProducts.length}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Container(
                    height: 300,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                    ),
                    child: ListView.separated(
                      itemCount: state.parsedProducts.length,
                      separatorBuilder: (_, _) => const Divider(),
                      itemBuilder: (context, index) {
                        final p = state.parsedProducts[index];
                        return ListTile(
                          title: Text(p.name),
                          subtitle: Text('SKU: ${p.sku} | REF: ${p.reference}'),
                          trailing: Text('R\$ ${p.retailPrice}'),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
            isActive: state.currentStep >= 1,
          ),
          Step(
            title: const Text('Imagens'),
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Selecione todas as imagens dos produtos de uma vez.',
                ),
                const Text(
                  'O sistema vinculará automaticamente se o nome do arquivo começar com o SKU ou a Referência do produto.',
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: viewModel.pickAndMatchImages,
                  icon: const Icon(Icons.image),
                  label: const Text('Carregar Imagens'),
                ),
                const SizedBox(height: 16),
                if (state.imagesTotalCount > 0)
                  Text('Imagens carregadas: ${state.imagesTotalCount}'),
                if (state.imagesMatchedCount > 0)
                  Text(
                    'Imagens vinculadas: ${state.imagesMatchedCount}',
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                // Maybe show list of products with no image?
              ],
            ),
            isActive: state.currentStep >= 2,
          ),
        ],
      ),
    );
  }
}
