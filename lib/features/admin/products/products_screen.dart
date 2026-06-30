import 'package:catalogo_ja/ui/widgets/app_error_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:catalogo_ja/models/category.dart';
import 'package:catalogo_ja/models/product.dart';
import 'package:catalogo_ja/viewmodels/products_viewmodel.dart';
import 'package:catalogo_ja/viewmodels/categories_viewmodel.dart';
import 'package:catalogo_ja/features/admin/products/product_form_screen.dart';
import 'package:catalogo_ja/features/admin/products/product_detail_screen.dart';
import 'package:catalogo_ja/core/services/product_ai_assistant_service.dart';
import 'package:catalogo_ja/ui/theme/app_tokens.dart';
import 'package:catalogo_ja/ui/widgets/app_error_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:catalogo_ja/models/category.dart';
import 'package:catalogo_ja/models/product.dart';
import 'package:catalogo_ja/viewmodels/products_viewmodel.dart';
import 'package:catalogo_ja/viewmodels/categories_viewmodel.dart';
import 'package:catalogo_ja/features/admin/products/product_form_screen.dart';
import 'package:catalogo_ja/features/admin/products/product_detail_screen.dart';
import 'package:catalogo_ja/core/services/product_ai_assistant_service.dart';
import 'package:catalogo_ja/ui/theme/app_tokens.dart';
import 'package:catalogo_ja/ui/widgets/app_scaffold.dart';
import 'package:catalogo_ja/ui/widgets/app_search_field.dart';
import 'package:catalogo_ja/ui/widgets/app_empty_state.dart';
import 'package:catalogo_ja/ui/widgets/app_product_list_tile.dart';
import 'package:uuid/uuid.dart';
import 'package:catalogo_ja/core/auth/user_role.dart';
import 'package:catalogo_ja/viewmodels/settings_viewmodel.dart';

class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  bool get _showAiAssistant => false;

  late final TextEditingController _searchController;
  late final TextEditingController _assistantController;
  bool _isRunningAssistant = false;
  String? _assistantFeedback;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _assistantController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _assistantController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(productsViewModelProvider);

    return AppScaffold(
      showHeader: false,
      title: 'Produtos',
      subtitle: 'Gerencie seu estoque e preços',
      body: Column(
        children: [
          if (_showAiAssistant) _buildAiAssistantCard(context),
          _buildBulkActionsBar(context),
          _buildSyncReminderBanner(context),
          if (state.isRefreshing) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: state.whenStandard(
              onRetry: () =>
                  ref.read(productsViewModelProvider.notifier).refresh(),
              data: (data) => _ProductsContent(
                state: data,
                searchController: _searchController,
                onSearchChanged: (value) => ref
                    .read(productsViewModelProvider.notifier)
                    .setSearchQuery(value),
                onClearFilters: () => _clearFilters(data),
                onSelectCategory: (value) => ref
                    .read(productsViewModelProvider.notifier)
                    .setCategoryFilter(value),
                onSelectStatus: (value) => ref
                    .read(productsViewModelProvider.notifier)
                    .setStatusFilter(value),
                onSelectSort: (value) => ref
                    .read(productsViewModelProvider.notifier)
                    .setSortOption(value),
                onNewProduct: () => _openNewProduct(context),
                onViewProduct: (product) => _openDetails(context, product),
                onEditProduct:
                    ref.watch(currentRoleProvider).canManageRegistrations
                    ? (product) => _openEdit(context, product)
                    : null,
                onDeleteProduct: ref.watch(currentRoleProvider).canDeleteProduct
                    ? (product) => _deleteProduct(product)
                    : null,
                onDuplicateProduct:
                    ref.watch(currentRoleProvider).canManageRegistrations
                    ? (product) => _duplicateProduct(product)
                    : null,
                onTogglePromo:
                    ref.watch(currentRoleProvider).canManageRegistrations
                    ? (product) => _togglePromo(product)
                    : null,
                onRefresh: () async =>
                    ref.read(productsViewModelProvider.notifier).refresh(),
                onToggleSelection: (id) => ref
                    .read(productsViewModelProvider.notifier)
                    .toggleSelection(id),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiAssistantCard(BuildContext context) {
    final state = ref.watch(productsViewModelProvider).valueOrNull;
    final summary = state?.assistantResultSummary;
    final hasResult = state?.assistantResultIds != null;
    final resultCount = state?.assistantResultIds?.length ?? 0;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        border: Border.all(
          color: AppTokens.vibrantCyan.withValues(alpha: 0.25),
        ),
      ),
      child: ExpansionTile(
        leading: const Icon(
          Icons.auto_awesome_outlined,
          color: AppTokens.vibrantCyan,
        ),
        title: const Text(
          'Assistente IA',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          hasResult
              ? '$resultCount produto(s) no resultado'
              : 'Peça para localizar ou selecionar produtos',
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          TextField(
            controller: _assistantController,
            enabled: !_isRunningAssistant,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _runAssistantCommand(),
            decoration: InputDecoration(
              hintText: 'Ex.: separe todas as blusas que tem estoque',
              suffixIcon: _isRunningAssistant
                  ? const Padding(
                      padding: EdgeInsets.all(13),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : IconButton(
                      tooltip: 'Executar pedido',
                      onPressed: _runAssistantCommand,
                      icon: const Icon(Icons.send_rounded),
                    ),
            ),
          ),
          if (_assistantFeedback != null || summary != null) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    _assistantFeedback ?? summary!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                if (hasResult)
                  TextButton(
                    onPressed: _clearAssistantResult,
                    child: const Text('Limpar'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _runAssistantCommand() async {
    final command = _assistantController.text.trim();
    final state = ref.read(productsViewModelProvider).valueOrNull;
    if (command.length < 3 || state == null || _isRunningAssistant) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _isRunningAssistant = true;
      _assistantFeedback = null;
    });

    try {
      final service = ref.read(productAiAssistantServiceProvider);
      final plan = await service.interpret(command);
      if (!mounted) return;
      if (!plan.isSupported) {
        setState(() => _assistantFeedback = plan.message);
        return;
      }

      final matches = service.findMatches(
        plan: plan,
        products: state.allProducts,
        categories: state.categories,
      );
      final suffix = plan.usedAi
          ? ''
          : ' Interpretacao local usada enquanto a IA online nao esta disponivel.';
      final feedback =
          '${plan.message} ${matches.length} produto(s) encontrado(s).$suffix';

      ref
          .read(productsViewModelProvider.notifier)
          .applyAssistantResult(
            productIds: matches.map((product) => product.id),
            summary: feedback,
            selectProducts: plan.shouldSelect,
            sortOption: _assistantSortOption(plan.sort),
          );
      setState(() => _assistantFeedback = feedback);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _assistantFeedback = 'Nao foi possivel executar o pedido: $error';
      });
    } finally {
      if (mounted) setState(() => _isRunningAssistant = false);
    }
  }

  ProductSort? _assistantSortOption(String sort) {
    switch (sort) {
      case 'price_asc':
        return ProductSort.priceAsc;
      case 'price_desc':
        return ProductSort.priceDesc;
      case 'name_asc':
        return ProductSort.aToZ;
      case 'recent':
        return ProductSort.recent;
      default:
        return null;
    }
  }

  void _clearAssistantResult() {
    ref.read(productsViewModelProvider.notifier).clearAssistantResult();
    setState(() => _assistantFeedback = null);
  }

  Widget _buildBulkActionsBar(BuildContext context) {
    final state = ref.watch(productsViewModelProvider).value;

    if (state == null || state.selectedProductIds.isEmpty) {
      return const SizedBox.shrink();
    }

    final count = state.selectedProductIds.length;
    final notifier = ref.read(productsViewModelProvider.notifier);
    final role = ref.watch(currentRoleProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Row(
        children: [
          Text(
            '$count selecionados',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          if (role.canDeleteProduct)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _confirmBulkDelete(context),
              tooltip: 'Excluir selecionados',
            ),
          IconButton(
            icon: const Icon(Icons.category_outlined),
            onPressed: () => _showBulkCategoryDialog(context),
            tooltip: 'Alterar categoria',
          ),
          IconButton(
            icon: const Icon(Icons.visibility_outlined),
            onPressed: () => notifier.updateStatusSelected(true),
            tooltip: 'Ativar todos',
          ),
          IconButton(
            icon: const Icon(Icons.visibility_off_outlined),
            onPressed: () => notifier.updateStatusSelected(false),
            tooltip: 'Desativar todos',
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => notifier.clearSelection(),
            tooltip: 'Limpar seleção',
          ),
        ],
      ),
    );
  }

  void _confirmBulkDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Selecionados'),
        content: const Text(
          'Deseja realmente excluir todos os itens selecionados? Esta ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              ref.read(productsViewModelProvider.notifier).deleteSelected();
              Navigator.pop(context);
            },
            child: const Text('Excluir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showBulkCategoryDialog(BuildContext context) {
    final state = ref.read(productsViewModelProvider).value;

    if (state == null) return;

    final notifier = ref.read(productsViewModelProvider.notifier);
    final selectedCategoryIds = <String>{};

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Text('Categorias dos Selecionados'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Escolha uma ou mais categorias para anexar aos produtos selecionados.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: state.categories.length,
                    itemBuilder: (context, index) {
                      final cat = state.categories[index];
                      final isSelected = selectedCategoryIds.contains(cat.id);

                      return CheckboxListTile(
                        value: isSelected,
                        title: Text(cat.safeName),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (value) {
                          setModalState(() {
                            if (value == true) {
                              selectedCategoryIds.add(cat.id);
                            } else {
                              selectedCategoryIds.remove(cat.id);
                            }
                          });
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await notifier.clearCategoriesSelected();
              },
              child: const Text(
                'Retirar todas categorias',
                style: TextStyle(color: Colors.red),
              ),
            ),
            ElevatedButton(
              onPressed: selectedCategoryIds.isEmpty
                  ? null
                  : () async {
                      Navigator.pop(context);
                      await notifier.addCategoriesToSelected(
                        selectedCategoryIds,
                      );
                    },
              child: const Text('Anexar categorias'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncReminderBanner(BuildContext context) {
    final stateValue = ref.watch(productsViewModelProvider);
    final categoriesValue = ref.watch(categoriesViewModelProvider);
    final hasCloudUpdates =
        ref.watch(cloudProductUpdatesPendingProvider).valueOrNull ?? false;

    final state = stateValue.valueOrNull;
    final categoriesState = categoriesValue.valueOrNull;

    if (state == null || categoriesState == null) {
      return const SizedBox.shrink();
    }

    final pendingProducts = state.allProducts
        .where((p) => p.syncStatus == SyncStatus.pendingUpdate)
        .length;

    final pendingCategories = categoriesState.categories
        .where((c) => c.syncStatus == SyncStatus.pendingUpdate)
        .length;

    final totalPending = pendingProducts + pendingCategories;

    if (totalPending == 0 && hasCloudUpdates) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blue.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.cloud_download_outlined,
              color: Colors.blue,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Alterações da nuvem pendentes',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.blue[900],
                    ),
                  ),
                  Text(
                    'Outro celular atualizou produtos desta loja.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(fontSize: 11),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => _startCloudDownload(context),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                foregroundColor: Colors.blue[800],
              ),
              child: const Text('BAIXAR'),
            ),
          ],
        ),
      );
    }

    if (totalPending == 0) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.sync_problem_rounded,
            color: Colors.orange,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Alterações Pendentes ($totalPending)',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                Text(
                  'Novos arquivos para sincronizar.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _startCloudSync(context),
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              foregroundColor: Colors.orange[800],
            ),
            child: const Text('SINCRONIZAR'),
          ),
        ],
      ),
    );
  }

  void _clearFilters(ProductsState state) {
    final notifier = ref.read(productsViewModelProvider.notifier);

    notifier.clearAssistantResult();
    notifier.setSearchQuery('');
    notifier.setCategoryFilter(null);
    notifier.setStatusFilter(ProductStatusFilter.all);
    notifier.setSortOption(ProductSort.recent);

    _searchController.clear();
  }

  Future<void> _openNewProduct(BuildContext context) async {
    final createdProduct = await Navigator.of(
      context,
    ).push<Product>(AppMotion.pageRoute(child: const ProductFormScreen()));

    if (!context.mounted || createdProduct == null) return;

    await Navigator.of(context).push(_buildCreatedProductRoute(createdProduct));
  }

  void _openDetails(BuildContext context, Product product) {
    Navigator.of(
      context,
    ).push(AppMotion.pageRoute(child: ProductDetailScreen(product: product)));
  }

  Route _buildCreatedProductRoute(Product product) {
    return PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 520),
      reverseTransitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (context, animation, secondaryAnimation) =>
          ProductDetailScreen(product: product),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );

        return FadeTransition(
          opacity: Tween<double>(begin: 0, end: 1).animate(curved),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.94, end: 1).animate(curved),
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.04),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          ),
        );
      },
    );
  }

  void _startCloudSync(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);

    messenger.showSnackBar(
      const SnackBar(
        content: Text('Sincronizando produtos com a nuvem em segundo plano...'),
        duration: Duration(seconds: 3),
        backgroundColor: Colors.blue,
      ),
    );

    ref
        .read(productsViewModelProvider.notifier)
        .syncAllToCloud()
        .then((count) {
          if (context.mounted) {
            messenger.showSnackBar(
              SnackBar(
                content: Text(
                  'Sincronização concluída! $count produtos enviados para a nuvem.',
                ),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 5),
              ),
            );
          }
        })
        .catchError((e) {
          if (context.mounted) {
            messenger.showSnackBar(
              SnackBar(
                content: Text('Erro na sincronização em segundo plano: $e'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 5),
              ),
            );
          }
        });
  }

  void _startCloudDownload(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);

    messenger.showSnackBar(
      const SnackBar(
        content: Text('Baixando catálogo da nuvem em segundo plano...'),
        duration: Duration(seconds: 3),
        backgroundColor: Colors.blue,
      ),
    );

    ref
        .read(productsViewModelProvider.notifier)
        .syncFromCloud()
        .then((count) {
          if (context.mounted) {
            messenger.showSnackBar(
              SnackBar(
                content: Text(
                  'Sucesso! $count produtos baixados da nuvem para o seu celular.',
                ),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 5),
              ),
            );
          }
        })
        .catchError((e) {
          if (context.mounted) {
            messenger.showSnackBar(
              SnackBar(
                content: Text('Erro ao baixar catálogo: $e'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 5),
              ),
            );
          }
        });
  }

  void _openEdit(BuildContext context, Product product) {
    Navigator.of(
      context,
    ).push(AppMotion.pageRoute(child: ProductFormScreen(product: product)));
  }

  void _deleteProduct(Product product) {
    ref.read(productsViewModelProvider.notifier).deleteProduct(product.id);
  }

  void _duplicateProduct(Product product) {
    final copy = product.copyWith(
      id: const Uuid().v4(),
      name: '${product.name} (Cópia)',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    ref.read(productsViewModelProvider.notifier).addProduct(copy);
  }

  void _togglePromo(Product product) {
    final enabled = !product.promoEnabled;
    final percent = enabled && product.promoPercent <= 0
        ? 10.0
        : product.promoPercent;
    final originalPrice = product.priceOriginal ?? product.priceRetail;
    final clampedPercent = percent.clamp(0, 100).toDouble();
    final promotionalPrice = enabled
        ? product.pricePromotion ??
              (originalPrice * (1 - (clampedPercent / 100)))
        : product.pricePromotion;
    final now = DateTime.now();

    final updated = product.copyWith(
      promoEnabled: enabled,
      promoPercent: enabled ? clampedPercent : 0.0,
      priceOriginal: enabled ? originalPrice : product.priceOriginal,
      pricePromotion: promotionalPrice,
      promotionName: enabled
          ? (product.promotionName ?? 'Promocao rapida')
          : product.promotionName,
      promotionType: enabled ? 'percent' : product.promotionType,
      promotionId: enabled
          ? (product.promotionId ?? const Uuid().v4())
          : product.promotionId,
      promotionUpdatedAt: enabled ? now : product.promotionUpdatedAt,
      promotionCreatedAt: enabled
          ? (product.promotionCreatedAt ?? now)
          : product.promotionCreatedAt,
      updatedAt: now,
    );

    ref.read(productsViewModelProvider.notifier).updateProduct(updated);
  }
}

class _ProductsContent extends ConsumerWidget {
  final ProductsState state;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearFilters;
  final ValueChanged<String?> onSelectCategory;
  final ValueChanged<ProductStatusFilter> onSelectStatus;
  final ValueChanged<ProductSort> onSelectSort;
  final VoidCallback onNewProduct;
  final ValueChanged<Product> onViewProduct;
  final ValueChanged<Product>? onEditProduct;
  final ValueChanged<Product>? onDeleteProduct;
  final ValueChanged<Product>? onDuplicateProduct;
  final ValueChanged<Product>? onTogglePromo;
  final RefreshCallback onRefresh;
  final ValueChanged<String> onToggleSelection;

  const _ProductsContent({
    required this.state,
    required this.searchController,
    required this.onSearchChanged,
    required this.onClearFilters,
    required this.onSelectCategory,
    required this.onSelectStatus,
    required this.onSelectSort,
    required this.onNewProduct,
    required this.onViewProduct,
    this.onEditProduct,
    this.onDeleteProduct,
    this.onDuplicateProduct,
    this.onTogglePromo,
    required this.onRefresh,
    required this.onToggleSelection,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasFilters =
        state.searchQuery.isNotEmpty ||
        state.productTypeFilterId != null ||
        state.collectionFilterId != null ||
        state.statusFilter != ProductStatusFilter.all ||
        state.sortOption != ProductSort.recent;

    if (searchController.text != state.searchQuery) {
      searchController.value = TextEditingValue(
        text: state.searchQuery,
        selection: TextSelection.collapsed(offset: state.searchQuery.length),
      );
    }

    final syncProgress = ref.watch(syncProgressProvider);

    return Column(
      children: [
        if (syncProgress.isSyncing)
          _buildSyncProgressBanner(context, syncProgress),
        Expanded(
          child: RefreshIndicator(
            onRefresh: onRefresh,
            displacement: 20,
            color: AppTokens.accentBlue,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTokens.space24,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate.fixed([
                      const SizedBox(height: AppTokens.space16),
                      _SearchAndFiltersSection(
                        state: state,
                        controller: searchController,
                        onSearchChanged: onSearchChanged,
                        onClearFilters: hasFilters ? onClearFilters : null,
                        onSelectCategory: onSelectCategory,
                        onSelectStatus: onSelectStatus,
                        onSelectSort: onSelectSort,
                        onNewProduct: onNewProduct,
                      ),
                      const SizedBox(height: AppTokens.space24),
                    ]),
                  ),
                ),
                _buildProductsSliver(
                  ref,
                  isInitialSyncCompleted: ref
                      .watch(settingsViewModelProvider)
                      .isInitialSyncCompleted,
                ),
                const SliverToBoxAdapter(
                  child: SizedBox(height: AppTokens.space48),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProductsSliver(
    WidgetRef ref, {
    required bool isInitialSyncCompleted,
  }) {
    if (state.filteredProducts.isEmpty) {
      return SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: AppTokens.space24),
        sliver: SliverToBoxAdapter(
          child: !isInitialSyncCompleted && !kIsWeb
              ? const AppEmptyState(
                  icon: Icons.cloud_download_outlined,
                  title: 'Carga Inicial Necessária',
                  subtitle:
                      'Como este é seu primeiro acesso neste aparelho, você precisa importar o Backup (ZIP - "WinRAR") para carregar os produtos, evitando custos elevados de rede. Vá em "Importar".',
                  message: '',
                )
              : const AppEmptyState(
                  icon: Icons.inventory_2_outlined,
                  title: 'Nenhum produto encontrado',
                  subtitle:
                      'Tente ajustar seus filtros ou cadastre um novo produto.',
                  message: '',
                ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: AppTokens.space24),
      sliver: SliverList.builder(
        itemCount: state.filteredProducts.length,
        itemBuilder: (context, index) {
          final product = state.filteredProducts[index];
          final isSelected = state.selectedProductIds.contains(product.id);

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AppProductListTile(
              product: product,
              isSelected: isSelected,
              onTap: () => onViewProduct(product),
              onLongPress: () => onToggleSelection(product.id),
              onEdit: onEditProduct != null
                  ? () => onEditProduct!(product)
                  : null,
              onDelete: onDeleteProduct != null
                  ? () => onDeleteProduct!(product)
                  : null,
              onDuplicate: onDuplicateProduct != null
                  ? () => onDuplicateProduct!(product)
                  : null,
              onTogglePromo: onTogglePromo != null
                  ? () => onTogglePromo!(product)
                  : null,
            ),
          );
        },
      ),
    );
  }

  Widget _buildSyncProgressBanner(BuildContext context, SyncProgress sync) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.primaryContainer.withValues(alpha: 0.95),
        border: const Border(bottom: BorderSide(color: Colors.black12)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  sync.message,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${(sync.progress * 100).toInt()}%',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(value: sync.progress, minHeight: 4),
          ),
        ],
      ),
    );
  }
}

class _SearchAndFiltersSection extends StatelessWidget {
  final ProductsState state;
  final TextEditingController controller;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback? onClearFilters;
  final ValueChanged<String?> onSelectCategory;
  final ValueChanged<ProductStatusFilter> onSelectStatus;
  final ValueChanged<ProductSort> onSelectSort;
  final VoidCallback onNewProduct;

  const _SearchAndFiltersSection({
    required this.state,
    required this.controller,
    required this.onSearchChanged,
    required this.onClearFilters,
    required this.onSelectCategory,
    required this.onSelectStatus,
    required this.onSelectSort,
    required this.onNewProduct,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: AppSearchField(
                controller: controller,
                hintText: 'Buscar por nome, REF, cor...',
                onChanged: onSearchChanged,
                onClear: onClearFilters,
              ),
            ),
            const SizedBox(width: AppTokens.space8),
            SizedBox.square(
              dimension: 48,
              child: IconButton.filled(
                tooltip: 'Novo produto',
                onPressed: onNewProduct,
                style: IconButton.styleFrom(
                  backgroundColor: AppTokens.electricBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                  ),
                ),
                icon: const Icon(Icons.add_rounded),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTokens.space12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              const SizedBox(width: 8),
              _FilterChip(
                label: _categoryLabel(state),
                isActive: state.productTypeFilterId != null,
                onPressed: () => _selectCategory(context),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: _statusLabel(state.statusFilter),
                isActive: state.statusFilter != ProductStatusFilter.all,
                onPressed: () => _selectStatus(context),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: _sortLabel(state.sortOption),
                isActive: state.sortOption != ProductSort.recent,
                onPressed: () => _selectSort(context),
              ),
              if (onClearFilters != null) ...[
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Limpar',
                  isActive: false,
                  onPressed: onClearFilters,
                  isDestructive: true,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  String _categoryLabel(ProductsState state) {
    if (state.productTypeFilterId == null) return 'Categoria';

    final category = state.categories
        .where((c) => c.id == state.productTypeFilterId)
        .map((c) => c.name)
        .firstOrNull;

    return category ?? 'Categoria';
  }

  String _statusLabel(ProductStatusFilter status) {
    switch (status) {
      case ProductStatusFilter.active:
        return 'Ativo';
      case ProductStatusFilter.outOfStock:
        return 'Esgotado';
      case ProductStatusFilter.inactive:
        return 'Inativos';
      case ProductStatusFilter.withPhotos:
        return 'Com Fotos';
      case ProductStatusFilter.noPhotos:
        return 'Sem Fotos';
      case ProductStatusFilter.zeroPrice:
        return 'Preço Zero';
      case ProductStatusFilter.createdToday:
        return 'Criados Hoje';
      case ProductStatusFilter.all:
        return 'Todos os Status';
    }
  }

  String _sortLabel(ProductSort sort) {
    switch (sort) {
      case ProductSort.recent:
        return 'Recentes';
      case ProductSort.priceAsc:
        return 'Menor preço';
      case ProductSort.priceDesc:
        return 'Maior preço';
      case ProductSort.aToZ:
        return 'A-Z';
    }
  }

  Future<void> _selectCategory(BuildContext context) async {
    final categories = state.categories
        .where((c) => c.type == CategoryType.productType)
        .toList();

    final options = <_SheetOption<String?>>[
      const _SheetOption(value: null, label: 'Todas categorias'),
      ...categories.map((c) => _SheetOption(value: c.id, label: c.safeName)),
    ];

    final result = await _showSelectionSheet<String?>(
      context,
      title: 'Categoria',
      options: options,
      selected: state.productTypeFilterId,
    );

    if (result != null || state.productTypeFilterId != null) {
      onSelectCategory(result);
    }
  }

  Future<void> _selectStatus(BuildContext context) async {
    final options = const [
      _SheetOption(value: ProductStatusFilter.all, label: 'Todos'),
      _SheetOption(value: ProductStatusFilter.active, label: 'Ativo'),
      _SheetOption(value: ProductStatusFilter.outOfStock, label: 'Esgotado'),
      _SheetOption(value: ProductStatusFilter.inactive, label: 'Inativo'),
      _SheetOption(value: ProductStatusFilter.withPhotos, label: 'Com Fotos'),
      _SheetOption(value: ProductStatusFilter.noPhotos, label: 'Sem Fotos'),
    ];

    final result = await _showSelectionSheet<ProductStatusFilter>(
      context,
      title: 'Status',
      options: options,
      selected: state.statusFilter,
    );

    if (result != null) onSelectStatus(result);
  }

  Future<void> _selectSort(BuildContext context) async {
    final options = const [
      _SheetOption(value: ProductSort.recent, label: 'Mais recentes'),
      _SheetOption(value: ProductSort.priceAsc, label: 'Menor preço'),
      _SheetOption(value: ProductSort.priceDesc, label: 'Maior preço'),
      _SheetOption(value: ProductSort.aToZ, label: 'A-Z'),
    ];

    final result = await _showSelectionSheet<ProductSort>(
      context,
      title: 'Ordenar por',
      options: options,
      selected: state.sortOption,
    );

    if (result != null) onSelectSort(result);
  }

  Future<T?> _showSelectionSheet<T>(
    BuildContext context, {
    required String title,
    required List<_SheetOption<T>> options,
    required T? selected,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTokens.radiusLg),
        ),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    icon: const Icon(Icons.close_rounded, size: 20),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: options.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final option = options[index];
                  final isSelected = option.value == selected;

                  return ListTile(
                    title: Text(
                      option.label,
                      style: TextStyle(
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w400,
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(
                            Icons.check_rounded,
                            color: AppTokens.accentBlue,
                          )
                        : null,
                    onTap: () => Navigator.pop(sheetContext, option.value),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback? onPressed;
  final bool isDestructive;

  const _FilterChip({
    required this.label,
    required this.isActive,
    this.onPressed,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: isActive,
      onSelected: onPressed != null ? (_) => onPressed!() : null,
      backgroundColor: isDestructive
          ? AppTokens.accentRed.withValues(alpha: 0.05)
          : null,
      selectedColor: AppTokens.accentBlue,
      checkmarkColor: Colors.white,
      labelStyle: TextStyle(
        fontSize: 13,
        fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
        color: isActive
            ? Colors.white
            : (isDestructive
                  ? AppTokens.accentRed
                  : Theme.of(context).colorScheme.onSurfaceVariant),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        side: BorderSide(
          color: isActive
              ? AppTokens.accentBlue
              : (isDestructive
                    ? AppTokens.accentRed.withValues(alpha: 0.2)
                    : Theme.of(context).dividerColor),
          width: 0.8,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
    );
  }
}

class _SheetOption<T> {
  final T value;
  final String label;

  const _SheetOption({required this.value, required this.label});
}

class _ProductsListSection extends StatefulWidget {
  final ProductsState state;
  final VoidCallback onNewProduct;
  final ValueChanged<Product> onViewProduct;
  final ValueChanged<Product>? onEditProduct;
  final ValueChanged<Product>? onDeleteProduct;
  final ValueChanged<Product>? onDuplicateProduct;
  final ValueChanged<Product>? onTogglePromo;
  final Set<String> selectedIds;
  final ValueChanged<String> onToggleSelection;
  final bool isInitialSyncCompleted;

  const _ProductsListSection(
    this.onEditProduct,
    this.onDeleteProduct,
    this.onDuplicateProduct,
    this.onTogglePromo, {
    required this.state,
    required this.onNewProduct,
    required this.onViewProduct,
    required this.selectedIds,
    required this.onToggleSelection,
    required this.isInitialSyncCompleted,
  });

  @override
  State<_ProductsListSection> createState() => _ProductsListSectionState();
}

class _ProductsListSectionState extends State<_ProductsListSection> {
  @override
  Widget build(BuildContext context) {
    if (widget.state.filteredProducts.isEmpty) {
      if (!widget.isInitialSyncCompleted) {
        return const AppEmptyState(
          icon: Icons.cloud_download_outlined,
          title: 'Carga Inicial Necessária',
          subtitle:
              'Como este é seu primeiro acesso neste aparelho, você precisa importar o Backup (ZIP - "WinRAR") para carregar os produtos, evitando custos elevados de rede. Vá em "Importar".',
          message: '',
        );
      }

      return const AppEmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'Nenhum produto encontrado',
        subtitle: 'Tente ajustar seus filtros ou cadastre um novo produto.',
        message: '',
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: widget.state.filteredProducts.length,
      itemBuilder: (context, index) {
        final product = widget.state.filteredProducts[index];
        final isSelected = widget.selectedIds.contains(product.id);

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: AppProductListTile(
            product: product,
            isSelected: isSelected,
            onTap: () => widget.onViewProduct(product),
            onLongPress: () => widget.onToggleSelection(product.id),
            onEdit: widget.onEditProduct != null
                ? () => widget.onEditProduct!(product)
                : null,
            onDelete: widget.onDeleteProduct != null
                ? () => widget.onDeleteProduct!(product)
                : null,
            onDuplicate: widget.onDuplicateProduct != null
                ? () => widget.onDuplicateProduct!(product)
                : null,
            onTogglePromo: widget.onTogglePromo != null
                ? () => widget.onTogglePromo!(product)
                : null,
          ),
        );
      },
    );
  }
}
