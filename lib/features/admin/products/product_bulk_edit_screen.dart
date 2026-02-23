import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gravity/models/product.dart';
import 'package:gravity/viewmodels/products_viewmodel.dart';
import 'package:gravity/ui/theme/app_tokens.dart';
import 'package:gravity/ui/widgets/app_scaffold.dart';

class ProductBulkEditScreen extends ConsumerStatefulWidget {
  const ProductBulkEditScreen({super.key});

  @override
  ConsumerState<ProductBulkEditScreen> createState() =>
      _ProductBulkEditScreenState();
}

class _ProductBulkEditScreenState extends ConsumerState<ProductBulkEditScreen> {
  final Map<String, TextEditingController> _retailControllers = {};
  final Map<String, TextEditingController> _wholesaleControllers = {};
  bool _isSaving = false;

  @override
  void dispose() {
    for (var c in _retailControllers.values) {
      c.dispose();
    }
    for (var c in _wholesaleControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _initializeControllers(List<Product> products) {
    for (var p in products) {
      if (!_retailControllers.containsKey(p.id)) {
        _retailControllers[p.id] = TextEditingController(
          text: p.retailPrice.toString(),
        );
        _wholesaleControllers[p.id] = TextEditingController(
          text: p.wholesalePrice.toString(),
        );
      }
    }
  }

  Future<void> _saveAll() async {
    setState(() => _isSaving = true);
    try {
      final productsState = ref.read(productsViewModelProvider).value;
      if (productsState == null) return;

      final products = productsState.filteredProducts;
      final notifier = ref.read(productsViewModelProvider.notifier);

      for (var p in products) {
        final newRetail =
            double.tryParse(_retailControllers[p.id]?.text ?? '') ??
            p.priceRetail;
        final newWholesale =
            double.tryParse(_wholesaleControllers[p.id]?.text ?? '') ??
            p.priceWholesale;

        if (newRetail != p.priceRetail || newWholesale != p.priceWholesale) {
          await notifier.updateProduct(
            p.copyWith(
              priceRetail: newRetail,
              priceWholesale: newWholesale,
              updatedAt: DateTime.now(),
            ),
          );
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Preços atualizados com sucesso!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao salvar: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final productsState = ref.watch(productsViewModelProvider);

    return AppScaffold(
      title: 'Edição Rápida',
      subtitle: 'Altere preços de forma massiva',
      actions: [
        if (_isSaving)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _saveAll,
            tooltip: 'Salvar tudo',
          ),
      ],
      body: productsState.when(
        data: (state) {
          _initializeControllers(state.filteredProducts);
          if (state.filteredProducts.isEmpty) {
            return const Center(child: Text('Nenhum produto para editar.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppTokens.space16),
            itemCount: state.filteredProducts.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, index) {
              final product = state.filteredProducts[index];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${product.ref} - ${product.name}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _retailControllers[product.id],
                            decoration: const InputDecoration(
                              labelText: 'Varejo',
                              prefixText: 'R\$ ',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            controller: _wholesaleControllers[product.id],
                            decoration: const InputDecoration(
                              labelText: 'Atacado',
                              prefixText: 'R\$ ',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
        error: (e, _) => Center(child: Text('Erro: $e')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
