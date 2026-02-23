import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gravity/models/catalog.dart';
import 'package:gravity/models/product.dart';
import 'package:gravity/viewmodels/catalog_public_viewmodel.dart';
import 'package:gravity/ui/theme/app_tokens.dart';
import 'package:gravity/ui/widgets/app_scaffold.dart';
import 'package:gravity/ui/widgets/app_search_field.dart';
import 'package:gravity/ui/widgets/app_product_card.dart';
import 'package:gravity/ui/widgets/app_empty_state.dart';
import 'package:gravity/models/category.dart';

class CatalogHomePage extends ConsumerStatefulWidget {
  final String shareCode;

  const CatalogHomePage({super.key, required this.shareCode});

  @override
  ConsumerState<CatalogHomePage> createState() => _CatalogHomePageState();
}

class _CatalogHomePageState extends ConsumerState<CatalogHomePage> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedCategoryId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catalogAsync = ref.watch(catalogPublicProvider(widget.shareCode));

    return catalogAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, s) => Scaffold(body: Center(child: Text('Erro: $e'))),
      data: (data) {
        if (data == null) {
          return const Scaffold(body: Center(child: Text('Não encontrado')));
        }
        if (!data.catalog.active) {
          return const Scaffold(body: Center(child: Text('Indisponível')));
        }

        final filteredProducts = _getFilteredProducts(data.products);

        return AppScaffold(
          title: data.catalog.name,
          subtitle: data.catalog.announcementEnabled
              ? data.catalog.announcementText
              : null,
          maxWidth: 1000,
          showHeader: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: () {
                showAboutDialog(
                  context: context,
                  applicationName: data.catalog.name,
                  children: [Text(data.catalog.mode.label)],
                );
              },
            ),
          ],
          body: Column(
            children: [
              // Filters & Search Section
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTokens.space24,
                ),
                child: Column(
                  children: [
                    AppSearchField(
                      controller: _searchController,
                      hintText: 'Buscar por nome ou REF...',
                      onChanged: (val) =>
                          setState(() => _searchQuery = val.toLowerCase()),
                    ),
                    const SizedBox(height: AppTokens.space16),
                    _buildCategories(data.categories),
                  ],
                ),
              ),

              const SizedBox(height: AppTokens.space16),

              // Product Feed
              Expanded(
                child: filteredProducts.isEmpty
                    ? const AppEmptyState(
                        title: 'Nenhum produto',
                        message: 'Tente mudar sua busca ou filtro.',
                        icon: Icons.search_off,
                      )
                    : _buildGrid(
                        filteredProducts,
                        data.catalog.photoLayout,
                        data.catalog.mode,
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Product> _getFilteredProducts(List<Product> all) {
    var list = _selectedCategoryId == null
        ? all
        : all
              .where((p) => p.categoryIds.contains(_selectedCategoryId))
              .toList();

    if (_searchQuery.isNotEmpty) {
      list = list
          .where(
            (p) =>
                p.name.toLowerCase().contains(_searchQuery) ||
                p.ref.toLowerCase().contains(_searchQuery),
          )
          .toList();
    }
    return list;
  }

  Widget _buildCategories(List<Category> categories) {
    if (categories.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppTokens.space24),
        itemCount: categories.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: AppTokens.space8),
        itemBuilder: (context, index) {
          final isAll = index == 0;
          final cat = isAll ? null : categories[index - 1];
          final isSelected = isAll
              ? _selectedCategoryId == null
              : _selectedCategoryId == cat?.id;

          return ChoiceChip(
            label: Text(isAll ? 'Todos' : cat!.safeName),
            selected: isSelected,
            onSelected: (_) => setState(() => _selectedCategoryId = cat?.id),
            backgroundColor: AppTokens.card,
            selectedColor: AppTokens.accentBlue.withOpacity(0.1),
            labelStyle: TextStyle(
              color: isSelected ? AppTokens.accentBlue : AppTokens.textMuted,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTokens.radiusMd),
              side: BorderSide(
                color: isSelected ? AppTokens.accentBlue : AppTokens.border,
              ),
            ),
            showCheckmark: false,
          );
        },
      ),
    );
  }

  Widget _buildGrid(List<Product> products, String layout, CatalogMode mode) {
    final isList = layout == 'list';

    return GridView.builder(
      padding: const EdgeInsets.all(AppTokens.space24),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isList ? 1 : 2,
        childAspectRatio: isList ? 2.5 : 0.75,
        crossAxisSpacing: AppTokens.space16,
        mainAxisSpacing: AppTokens.space16,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        return AppProductCard(
          product: product,
          mode: mode,
          onTap: () => context.push(
            '/c/${widget.shareCode}/p/${product.id}',
            extra: {'product': product, 'mode': mode},
          ),
        );
      },
    );
  }
}
