import 'package:catalogo_ja/features/admin/promotions/altered_products_tab.dart';
import 'package:catalogo_ja/features/admin/promotions/create_promotion_tab.dart';
import 'package:catalogo_ja/ui/widgets/app_scaffold.dart';
import 'package:catalogo_ja/viewmodels/products_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PromotionsScreen extends ConsumerWidget {
  const PromotionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: AppScaffold(
        title: 'Promoções',
        subtitle: 'Gerencie descontos e veja produtos alterados',
        actions: [
          IconButton(
            tooltip: 'Atualizar',
            onPressed: () => ref.read(productsViewModelProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
        bottom: const TabBar(
          tabs: [
            Tab(icon: Icon(Icons.collections_bookmark), text: 'Aplicar por Coleção'),
            Tab(icon: Icon(Icons.edit_attributes), text: 'Produtos Alterados'),
          ],
        ),
        body: const TabBarView(
          children: [
            CreatePromotionTab(),
            AlteredProductsTab(),
          ],
        ),
      ),
    );
  }
}
