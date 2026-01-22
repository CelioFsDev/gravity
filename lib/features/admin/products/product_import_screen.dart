import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
               Text('${state.parsedProducts.length} produtos importados com sucesso!'),
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
                if (state.isLoading) const CircularProgressIndicator() else FilledButton(
                  onPressed: details.onStepContinue,
                  child: Text(isLastStep ? 'Finalizar Importação' : 'Próximo'),
                ),
                const SizedBox(width: 16),
                if (!state.isLoading) TextButton(
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
                const Text('2. Preencha com os seus produtos mantendo a estrutura.'),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () {
                    // Logic to generate and save CSV template or open URL
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Download iniciado (Simulado)')));
                  }, 
                  icon: const Icon(Icons.download),
                  label: const Text('Baixar Template CSV'),
                ),
                 const SizedBox(height: 16),
                 const Text('Colunas: Name, REF, SKU, CategoryID, RetailPrice, WholesalePrice, MinQty, Sizes, Colors, IsActive'),
              ],
            ),
            isActive: state.currentStep >= 0,
          ),
          Step(
            title: const Text('CSV Parsing'),
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                 ElevatedButton.icon(
                   onPressed: viewModel.pickAndParseCsv,
                   icon: const Icon(Icons.upload_file),
                   label: const Text('Carregar Arquivo CSV'),
                 ),
                 if (state.errorMessage != null)
                    Padding(padding: const EdgeInsets.only(top: 8), child: Text(state.errorMessage!, style: const TextStyle(color: Colors.red))),
                 
                 const SizedBox(height: 16),
                 if (state.parsedProducts.isNotEmpty) ...[
                    Text('Produtos identificados: ${state.parsedProducts.length}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    Container(
                      height: 300,
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
                      child: ListView.separated(
                        itemCount: state.parsedProducts.length,
                        separatorBuilder: (_, __) => const Divider(),
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
                 ]
              ],
            ),
            isActive: state.currentStep >= 1,
          ),
          Step(
            title: const Text('Imagens'),
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Selecione todas as imagens dos produtos de uma vez.'),
                const Text('O sistema vinculará automaticamente se o nome do arquivo começar com o SKU do produto.'),
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
                   Text('Imagens vinculadas: ${state.imagesMatchedCount}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                   
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
