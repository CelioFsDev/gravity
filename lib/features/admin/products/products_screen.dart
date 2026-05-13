import 'package:catalogo_ja/ui/widgets/app_error_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:catalogo_ja/models/category.dart';
import 'package:catalogo_ja/models/product.dart';
import 'package:catalogo_ja/viewmodels/products_viewmodel.dart';
import 'package:catalogo_ja/viewmodels/categories_viewmodel.dart';
import 'package:catalogo_ja/features/admin/products/product_form_screen.dart';
import 'package:catalogo_ja/features/admin/products/product_detail_screen.dart';
import 'package:catalogo_ja/core/services/product_transfer_service.dart';
import 'package:catalogo_ja/core/services/catalog_share_helper.dart';
import 'package:catalogo_ja/features/admin/import/catalogo_ja_import_screen.dart';
import 'package:catalogo_ja/features/admin/import/nuvemshop_import_screen.dart';
import 'package:catalogo_ja/viewmodels/product_export_viewmodel.dart';
import 'package:catalogo_ja/ui/theme/app_tokens.dart';
import 'package:catalogo_ja/viewmodels/product_import_viewmodel.dart';
import 'package:catalogo_ja/features/admin/products/product_bulk_edit_screen.dart';
import 'package:catalogo_ja/ui/widgets/app_scaffold.dart';
import 'package:catalogo_ja/ui/widgets/app_kpi_card.dart';
import 'package:catalogo_ja/ui/widgets/app_search_field.dart';
import 'package:catalogo_ja/ui/widgets/app_empty_state.dart';
import 'package:catalogo_ja/ui/widgets/app_product_list_tile.dart';
import 'package:uuid/uuid.dart';
import 'package:catalogo_ja/core/auth/user_role.dart';
import 'package:catalogo_ja/viewmodels/auth_viewmodel.dart';
import 'package:catalogo_ja/viewmodels/settings_viewmodel.dart';

class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  late final TextEditingController _searchController;

  bool get _showSupportTools {
    final email = ref
        .read(authViewModelProvider)
        .valueOrNull
        ?.email
        ?.trim()
        .toLowerCase();

    return UserRole.superAdminEmails.contains(email);
  }

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(productsViewModelProvider);

    return AppScaffold(
      showHeader: true,
      title: 'Produtos',
      subtitle: 'Gerencie seu estoque e preços',
      body: Column(
        children: [
          _buildHeader(
            context,
            Theme.of(context).brightness == Brightness.dark,
          ),
          _buildBulkActionsBar(context),
          _buildSyncReminderBanner(context),
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
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 80),
        child: FloatingActionButton.extended(
          onPressed: () => _openNewProduct(context),
          label: const Text(
            'NOVO PRODUTO',
            style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
          ),
          icon: const Icon(Icons.add_rounded),
          backgroundColor: AppTokens.electricBlue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    final state = ref.watch(productsViewModelProvider).valueOrNull;
    final totalProducts = state?.allProducts.length ?? 0;
    final promoCount =
        state?.allProducts.where((p) => p.promoEnabled).length ?? 0;
    final outOfStockCount =
        state?.allProducts.where((p) => p.isOutOfStock).length ?? 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      decoration: BoxDecoration(
        color: isDark
            ? AppTokens.deepNavy.withOpacity(0.3)
            : Colors.white.withOpacity(0.5),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildSummaryItem(
                  'Total',
                  totalProducts.toString(),
                  AppTokens.vibrantCyan,
                  Icons.inventory_2_outlined,
                ),
                const SizedBox(width: 8),
                _buildSummaryItem(
                  'Promo',
                  promoCount.toString(),
                  AppTokens.vibrantPink,
                  Icons.percent_rounded,
                ),
                const SizedBox(width: 8),
                _buildSummaryItem(
                  'Esgotado',
                  outOfStockCount.toString(),
                  Colors.orangeAccent,
                  Icons.block_flipped,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 120,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.04),
          width: 1,
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: color.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : Colors.black87,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white38 : Colors.black45,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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

  Widget _buildBottomBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTokens.space16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: ref.watch(currentRoleProvider).canManageRegistrations
            ? Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _openImport(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.cloud_download_outlined, size: 18),
                      label: const Text('Importar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _openNewProduct(context),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Novo Produto'),
                    ),
                  ),
                ],
              )
            : const SizedBox.shrink(),
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
          color: Colors.blue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          border: Border.all(color: Colors.blue.withOpacity(0.3)),
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
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
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

  Widget _buildMoreActions(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded),
      onSelected: (value) {
        if (value == 'sync_upload') _startCloudSync(context);
        if (value == 'sync_download') _startCloudDownload(context);

        if (value == 'bulk_edit') {
          Navigator.of(
            context,
          ).push(AppMotion.pageRoute(child: const ProductBulkEditScreen()));
        }

        if (value == 'export') _showExportOptions(context);
      },
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: 'sync_upload',
          child: Row(
            children: [
              Icon(
                Icons.cloud_upload_outlined,
                size: 18,
                color: AppTokens.accentBlue,
              ),
              SizedBox(width: 8),
              Text(
                'Subir Catálogo (Nuvem)',
                style: TextStyle(color: AppTokens.accentBlue),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'sync_download',
          child: Row(
            children: [
              Icon(
                Icons.cloud_download_outlined,
                size: 18,
                color: AppTokens.accentBlue,
              ),
              SizedBox(width: 8),
              Text('Baixar Catálogo (Nuvem)'),
            ],
          ),
        ),
        PopupMenuDivider(),
        PopupMenuItem(
          value: 'bulk_edit',
          child: Row(
            children: [
              Icon(Icons.edit_note_outlined, size: 18),
              SizedBox(width: 8),
              Text('Edição Rápida (Preços)'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'export',
          child: Row(
            children: [
              Icon(Icons.share_outlined, size: 18),
              SizedBox(width: 8),
              Text('Exportar Catálogo'),
            ],
          ),
        ),
      ],
    );
  }

  void _clearFilters(ProductsState state) {
    final notifier = ref.read(productsViewModelProvider.notifier);

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

  void _openImport(BuildContext context) {
    final screenContext = context;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTokens.radiusLg),
        ),
      ),
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.cloud_download_outlined),
                title: const Text('Importar Backup (CatalogoJa)'),
                subtitle: const Text(
                  'Restaura produtos, categorias e coleções de um arquivo JSON.',
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(
                    AppMotion.pageRoute(child: const CatalogoJaImportScreen()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.add_a_photo_outlined),
                title: const Text('Adicionar Fotos em Lote'),
                subtitle: const Text(
                  'Seleciona várias fotos e associa aos produtos automaticamente.',
                ),
                onTap: () {
                  Navigator.pop(context);
                  _startPhotoReferenceLinking();
                },
              ),
              ListTile(
                leading: const Icon(Icons.cloud_sync_outlined),
                title: const Text('Sincronizar Fotos da Nuvem'),
                subtitle: const Text(
                  'Baixa fotos automaticamente usando a URL Base configurada em Ajustes.',
                ),
                onTap: () async {
                  final messenger = ScaffoldMessenger.of(screenContext);

                  Navigator.pop(context);

                  try {
                    await CatalogShareHelper.runWithLoadingDialog(
                      screenContext,
                      () async {
                        ref
                            .read(productImportViewModelProvider.notifier)
                            .reset();
                        await ref
                            .read(productImportViewModelProvider.notifier)
                            .syncRemoteImagesFromUrl();
                      },
                      title: 'Sincronizando fotos...',
                      message:
                          'Buscando imagens na nuvem e vinculando produtos.',
                    );
                  } catch (e) {
                    if (!screenContext.mounted) return;
                    messenger.showSnackBar(
                      SnackBar(content: Text('Erro ao sincronizar fotos: $e')),
                    );
                    return;
                  }

                  if (!mounted) return;

                  final syncState = ref.read(productImportViewModelProvider);

                  if (syncState.errorMessage != null) {
                    messenger.showSnackBar(
                      SnackBar(content: Text(syncState.errorMessage!)),
                    );
                    return;
                  }

                  final matched = syncState.imagesMatchedCount;
                  final total = syncState.imagesTotalCount;

                  final message = matched > 0
                      ? 'Sincronização concluída: $matched produto(s) com foto em $total verificados.'
                      : 'Sincronização concluída sem fotos encontradas. Verifique a URL Base e os nomes (REF.ext).';

                  messenger.showSnackBar(SnackBar(content: Text(message)));
                },
              ),
              if (_showSupportTools)
                ListTile(
                  leading: const Icon(Icons.auto_fix_high_outlined),
                  title: const Text('Reorganizar Fotos'),
                  subtitle: const Text(
                    'Religa fotos pelos nomes e limita P, detalhes e cores para evitar erro no PDF.',
                  ),
                  onTap: () async {
                    Navigator.pop(context);

                    try {
                      final updatedCount =
                          await CatalogShareHelper.runWithLoadingDialog(
                            screenContext,
                            () => ref
                                .read(productsViewModelProvider.notifier)
                                .reorganizePhotosPriority(),
                            title: 'Reorganizando fotos...',
                            message:
                                'Ajustando fotos principais, detalhes e cores.',
                          );

                      if (!screenContext.mounted) return;

                      ScaffoldMessenger.of(screenContext).showSnackBar(
                        SnackBar(
                          content: Text(
                            updatedCount > 0
                                ? 'Reorganização concluída em $updatedCount produto(s).'
                                : 'Nenhum produto precisou de reorganização.',
                          ),
                        ),
                      );
                    } catch (e) {
                      if (!screenContext.mounted) return;

                      ScaffoldMessenger.of(screenContext).showSnackBar(
                        SnackBar(
                          content: Text('Erro ao reorganizar fotos: $e'),
                        ),
                      );
                    }
                  },
                ),
              ListTile(
                leading: const Icon(Icons.shopping_bag_outlined),
                title: const Text('Importar Nuvemshop'),
                subtitle: const Text(
                  'Importa produtos e fotos da sua loja Nuvemshop.',
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(
                    AppMotion.pageRoute(child: const NuvemshopImportScreen()),
                  );
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  void _showExportOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTokens.radiusLg),
        ),
      ),
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.archive_outlined),
                title: const Text('Backup Completo do Aplicativo'),
                subtitle: const Text(
                  'Gera um arquivo .zip com todos os dados e imagens para migração.',
                ),
                onTap: () {
                  Navigator.pop(context);

                  final viewModel = ref.read(
                    productExportViewModelProvider.notifier,
                  );

                  viewModel.exportPackage();

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Gerando backup completo em segundo plano...',
                      ),
                      backgroundColor: AppTokens.accentBlue,
                    ),
                  );
                },
              ),
              if (_showSupportTools)
                ListTile(
                  leading: const Icon(Icons.code),
                  title: const Text('Backup Simples (Apenas Dados)'),
                  subtitle: const Text('Arquivo JSON leve sem imagens.'),
                  onTap: () {
                    Navigator.pop(context);
                    ProductTransferService.shareCatalogoJaBackup(context, ref);
                  },
                ),
              if (_showSupportTools) const Divider(),
              if (_showSupportTools)
                ListTile(
                  leading: const Icon(Icons.file_present_outlined),
                  title: const Text('Planilha para Edição (CSV)'),
                  subtitle: const Text(
                    'Exporta produtos e fotos em formato CSV/ZIP.',
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    ProductTransferService.shareProductsPackage(context, ref);
                  },
                ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  void _startPhotoReferenceLinking() {
    ref.read(productImportViewModelProvider.notifier).reset();

    ref
        .read(productImportViewModelProvider.notifier)
        .pickAndMatchImagesToExistingProducts();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Iniciando vinculação de fotos em segundo plano...'),
        backgroundColor: AppTokens.accentBlue,
      ),
    );
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

    final updated = product.copyWith(
      promoEnabled: enabled,
      promoPercent: enabled ? percent : 0.0,
      updatedAt: DateTime.now(),
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
          child: !isInitialSyncCompleted
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
        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.95),
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

class _KpiSection extends StatelessWidget {
  final ProductsState state;

  const _KpiSection({required this.state});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 4,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: MediaQuery.of(context).size.width < 600 ? 2 : 4,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        mainAxisExtent: 140,
      ),
      itemBuilder: (context, index) {
        switch (index) {
          case 0:
            return AppKpiCard(
              label: 'Total',
              value: state.totalCount.toString(),
              color: AppTokens.accentBlue,
              icon: Icons.inventory_2_outlined,
            );
          case 1:
            return AppKpiCard(
              label: 'Ativos',
              value: state.activeCount.toString(),
              color: AppTokens.accentGreen,
              icon: Icons.check_circle_outline,
            );
          case 2:
            return AppKpiCard(
              label: 'Esgotados',
              value: state.outOfStockCount.toString(),
              color: AppTokens.accentRed,
              icon: Icons.error_outline,
            );
          case 3:
            return AppKpiCard(
              label: 'Promoções',
              value: state.onSaleCount.toString(),
              color: AppTokens.accentOrange,
              icon: Icons.percent_rounded,
            );
          default:
            return const SizedBox.shrink();
        }
      },
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

  const _SearchAndFiltersSection({
    required this.state,
    required this.controller,
    required this.onSearchChanged,
    required this.onClearFilters,
    required this.onSelectCategory,
    required this.onSelectStatus,
    required this.onSelectSort,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSearchField(
          controller: controller,
          hintText: 'Buscar por nome, REF, cor...',
          onChanged: onSearchChanged,
          onClear: onClearFilters,
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
          ? AppTokens.accentRed.withOpacity(0.05)
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
                    ? AppTokens.accentRed.withOpacity(0.2)
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

  const _ProductsListSection({
    required this.state,
    required this.onNewProduct,
    required this.onViewProduct,
    required this.selectedIds,
    required this.onToggleSelection,
    required this.isInitialSyncCompleted,
    this.onEditProduct,
    this.onDeleteProduct,
    this.onDuplicateProduct,
    this.onTogglePromo,
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
