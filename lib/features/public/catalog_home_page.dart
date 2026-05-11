import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:catalogo_ja/models/catalog.dart';
import 'package:catalogo_ja/models/product.dart';
import 'package:catalogo_ja/viewmodels/catalog_public_viewmodel.dart';
import 'package:catalogo_ja/ui/theme/app_tokens.dart';
import 'package:catalogo_ja/ui/widgets/app_product_card.dart';
import 'package:catalogo_ja/ui/widgets/app_empty_state.dart';
import 'package:catalogo_ja/models/category.dart';
import 'package:catalogo_ja/models/order.dart';
import 'package:catalogo_ja/viewmodels/cart_viewmodel.dart';
import 'package:flutter/foundation.dart' hide Category;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class CatalogHomePage extends ConsumerStatefulWidget {
  final String shareCode;
  final String? sellerWhatsapp;

  const CatalogHomePage({
    super.key,
    required this.shareCode,
    this.sellerWhatsapp,
  });

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
      loading: () => Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                color: Color(0xFF0F172A),
                strokeWidth: 3,
              ),
              const SizedBox(height: 24),
              Text(
                'Carregando vitrine...',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
      error: (e, s) => Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
                const SizedBox(height: 16),
                Text(
                  'Não foi possível carregar esta vitrine.\n$e',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade800),
                ),
              ],
            ),
          ),
        ),
      ),
      data: (data) {
        if (data == null) {
          return const Scaffold(
            backgroundColor: Color(0xFFF8FAFC),
            body: Center(child: Text('Catálogo não encontrado')),
          );
        }
        if (!data.catalog.active) {
          return const Scaffold(
            backgroundColor: Color(0xFFF8FAFC),
            body: Center(child: Text('Catálogo indisponível no momento')),
          );
        }

        final whatsappNumber = widget.sellerWhatsapp ?? data.whatsappNumber;
        final filteredProducts = _getFilteredProducts(data.products);
        final cart = ref.watch(cartViewModelProvider);
        final mediaSize = MediaQuery.sizeOf(context);
        final isCompactViewport =
            mediaSize.width < 600 || mediaSize.height < 700;

        if (cart.catalogId != data.catalog.id) {
          Future.microtask(
            () => ref
                .read(cartViewModelProvider.notifier)
                .initCart(data.catalog.tenantId ?? '', data.catalog.id),
          );
        }

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          extendBody: true,
          body: Stack(
            children: [
              // Main Content
              CustomScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: _buildShowcaseHeader(
                      data.catalog,
                      filteredProducts.length,
                      whatsappNumber,
                    ),
                  ),
                  SliverPersistentHeader(
                    pinned: !isCompactViewport,
                    delegate: _SearchAndCategoriesDelegate(
                      searchController: _searchController,
                      onSearchChanged: (val) =>
                          setState(() => _searchQuery = val.toLowerCase()),
                      categories: data.categories as List<Category>,
                      selectedCategoryId: _selectedCategoryId,
                      onCategorySelected: (id) =>
                          setState(() => _selectedCategoryId = id),
                      isCompact: isCompactViewport,
                    ),
                  ),
                  if (filteredProducts.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: AppEmptyState(
                          title: 'Nenhum produto',
                          subtitle: 'Tente mudar sua busca ou filtro.',
                          icon: Icons.search_off,
                          message: '',
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        isCompactViewport ? 12 : 16,
                        isCompactViewport ? 12 : 16,
                        isCompactViewport ? 12 : 16,
                        cart.items.isNotEmpty ? 120 : 32,
                      ),
                      sliver: SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: _getCrossAxisCount(
                            context,
                            data.catalog.photoLayout,
                          ),
                          childAspectRatio: _getChildAspectRatio(
                            context,
                            data.catalog.photoLayout,
                          ),
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final product = filteredProducts[index];
                          return AppProductCard(
                            product: product,
                            mode: data.catalog.mode,
                            onTap: () => context.push(
                              '/c/${widget.shareCode}/p/${product.id}',
                              extra: {
                                'product': product,
                                'mode': data.catalog.mode,
                                'shareCode': widget.shareCode,
                              },
                            ),
                          );
                        }, childCount: filteredProducts.length),
                      ),
                    ),
                ],
              ),

              // Floating Cart Bar
              if (cart.items.isNotEmpty)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: _buildCartBar(
                    context,
                    cart,
                    data.catalog,
                    whatsappNumber,
                    data.products,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  int _getCrossAxisCount(BuildContext context, String layout) {
    if (layout == 'list') return 1;
    final width = MediaQuery.of(context).size.width;
    if (width > 1200) return 5;
    if (width > 900) return 4;
    if (width > 600) return 3;
    return 2;
  }

  double _getChildAspectRatio(BuildContext context, String layout) {
    if (layout == 'list') return 2.2;
    final width = MediaQuery.of(context).size.width;
    if (width > 900) return 0.58;
    if (width > 600) return 0.56;
    return 0.48;
  }

  Widget _buildShowcaseHeader(
    Catalog catalog,
    int productsCount,
    String? whatsappNumber,
  ) {
    final mediaSize = MediaQuery.sizeOf(context);
    final isCompactViewport = mediaSize.width < 600 || mediaSize.height < 700;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          // Subtle Pattern or Glow
          Positioned(
            right: -50,
            top: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF38BDF8).withOpacity(0.15),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              isCompactViewport ? 16 : 24,
              isCompactViewport ? 24 : 40,
              isCompactViewport ? 16 : 24,
              isCompactViewport ? 22 : 32,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _HeaderPill(
                      icon: Icons.storefront_outlined,
                      label: catalog.mode == CatalogMode.atacado
                          ? 'ATACADO'
                          : 'VAREJO',
                      color: const Color(0xFF38BDF8),
                    ),
                    const SizedBox(width: 8),
                    _HeaderPill(
                      icon: Icons.inventory_2_outlined,
                      label: '$productsCount ITENS',
                      color: Colors.white24,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  catalog.name,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isCompactViewport ? 28 : 34,
                    height: 1.1,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Explore nossa vitrine e selecione os itens desejados.',
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: isCompactViewport ? 14 : 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (catalog.announcementEnabled &&
                    (catalog.announcementText ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFF59E0B).withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.campaign_outlined,
                          color: Color(0xFFF59E0B),
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            catalog.announcementText!,
                            style: const TextStyle(
                              color: Color(0xFFF59E0B),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
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
        padding: EdgeInsets.zero,
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
            backgroundColor: Colors.white,
            selectedColor: const Color(0xFFE8F8F5),
            labelStyle: TextStyle(
              color: isSelected ? const Color(0xFF047857) : AppTokens.textMuted,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTokens.radiusMd),
              side: BorderSide(
                color: isSelected ? const Color(0xFF10B981) : AppTokens.border,
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = isList
            ? 1
            : (constraints.maxWidth / 260).floor().clamp(1, 6);
        final cardWidth = constraints.maxWidth / crossAxisCount;
        final childAspectRatio = isList
            ? 2.5
            : (cardWidth / 360).clamp(0.64, 0.86);

        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: childAspectRatio,
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
                extra: {
                  'product': product,
                  'mode': mode,
                  'shareCode': widget.shareCode,
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCartBar(
    BuildContext context,
    CartState cart,
    Catalog catalog,
    String? whatsappNumber,
    List<Product> products,
  ) {
    final currency = NumberFormat.simpleCurrency(locale: 'pt_BR');

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A).withOpacity(0.85),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: [
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: () => _showCartSheet(
                      context,
                      catalog,
                      whatsappNumber,
                      products,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${cart.totalItems} item(ns)',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          currency.format(cart.subtotal),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                FilledButton(
                  onPressed: () => _showCartSheet(
                    context,
                    catalog,
                    whatsappNumber,
                    products,
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF38BDF8),
                    foregroundColor: const Color(0xFF0F172A),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Text(
                        'FINALIZAR',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward_rounded, size: 18),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showCartSheet(
    BuildContext context,
    Catalog catalog,
    String? whatsappNumber,
    List<Product> products,
  ) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return _CartSheetContent(
          catalog: catalog,
          whatsappNumber: whatsappNumber,
          products: products,
        );
      },
    );
  }
}

class _CartSheetContent extends ConsumerWidget {
  const _CartSheetContent({
    required this.catalog,
    required this.whatsappNumber,
    required this.products,
  });

  final Catalog catalog;
  final String? whatsappNumber;
  final List<Product> products;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartViewModelProvider);
    final currency = NumberFormat.simpleCurrency(locale: 'pt_BR');

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
            child: Row(
              children: [
                const Icon(
                  Icons.shopping_bag_outlined,
                  size: 28,
                  color: Color(0xFF0F172A),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Meu Carrinho',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: cart.items.isEmpty
                      ? null
                      : () => ref
                            .read(cartViewModelProvider.notifier)
                            .clearCart(),
                  child: Text(
                    'Limpar',
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Items List
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.5,
            ),
            child: cart.items.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 64),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.shopping_cart_outlined,
                          size: 64,
                          color: Colors.grey.shade200,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Carrinho vazio',
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: cart.items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      return _CartItemTile(
                        item: cart.items[index],
                        index: index,
                        product: _findProduct(cart.items[index].productId),
                      );
                    },
                  ),
          ),

          // Footer
          Container(
            padding: EdgeInsets.fromLTRB(
              24,
              24,
              24,
              24 + MediaQuery.of(context).padding.bottom,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total',
                      style: TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      currency.format(cart.subtotal),
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: cart.items.isEmpty
                        ? null
                        : () => _sendToWhatsApp(
                            context,
                            cart,
                            catalog,
                            whatsappNumber,
                          ),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline_rounded, size: 20),
                        SizedBox(width: 12),
                        Text(
                          'ENVIAR PEDIDO PELO WHATSAPP',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Product? _findProduct(String productId) {
    for (final product in products) {
      if (product.id == productId) return product;
    }
    return null;
  }

  Future<void> _sendToWhatsApp(
    BuildContext context,
    CartState cart,
    Catalog catalog,
    String? whatsappNumber,
  ) async {
    final whatsapp = (whatsappNumber ?? '').replaceAll(RegExp(r'\D'), '');
    final message = _buildWhatsAppMessage(cart, catalog);
    final encodedMessage = Uri.encodeComponent(message);
    final appUrl = whatsapp.isEmpty
        ? Uri.parse('whatsapp://send?text=$encodedMessage')
        : Uri.parse('whatsapp://send?phone=$whatsapp&text=$encodedMessage');
    final webUrl = whatsapp.isEmpty
        ? Uri.parse('https://api.whatsapp.com/send?text=$encodedMessage')
        : Uri.parse(
            'https://api.whatsapp.com/send?phone=$whatsapp&text=$encodedMessage',
          );

    try {
      if (!kIsWeb && await canLaunchUrl(appUrl)) {
        await launchUrl(appUrl, mode: LaunchMode.externalApplication);
        return;
      }

      await launchUrl(webUrl, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nao foi possivel abrir o WhatsApp neste dispositivo.'),
        ),
      );
    }
  }

  String _buildWhatsAppMessage(CartState cart, Catalog catalog) {
    final currency = NumberFormat.simpleCurrency(locale: 'pt_BR');
    final buffer = StringBuffer()
      ..writeln('Olá! Quero fazer este pedido pelo catálogo:')
      ..writeln()
      ..writeln('Catálogo: ${catalog.name}')
      ..writeln();

    for (var i = 0; i < cart.items.length; i++) {
      final item = cart.items[i];
      buffer
        ..writeln('${i + 1}. ${item.productName}')
        ..writeln('REF/SKU: ${item.sku ?? '-'}');

      final attrs = item.attributes ?? {};
      if ((attrs['Cor'] ?? '').isNotEmpty) {
        buffer.writeln('Cor: ${attrs['Cor']}');
      }
      if ((attrs['Tamanho'] ?? '').isNotEmpty) {
        buffer.writeln('Tamanho: ${attrs['Tamanho']}');
      }

      buffer
        ..writeln('Qtd: ${item.quantity}')
        ..writeln('Valor un.: ${currency.format(item.unitPrice)}')
        ..writeln('Subtotal: ${currency.format(item.totalPrice)}')
        ..writeln();
    }

    buffer
      ..writeln('Total: ${currency.format(cart.subtotal)}')
      ..writeln()
      ..writeln('Nome:')
      ..writeln('Cidade:')
      ..writeln('Observações:');

    return buffer.toString();
  }
}

class _HeaderPill extends StatelessWidget {
  const _HeaderPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchAndCategoriesDelegate extends SliverPersistentHeaderDelegate {
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final List<Category> categories;
  final String? selectedCategoryId;
  final ValueChanged<String?> onCategorySelected;
  final bool isCompact;

  _SearchAndCategoriesDelegate({
    required this.searchController,
    required this.onSearchChanged,
    required this.categories,
    required this.selectedCategoryId,
    required this.onCategorySelected,
    required this.isCompact,
  });

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: const Color(0xFFF8FAFC),
      padding: EdgeInsets.fromLTRB(
        isCompact ? 12 : 16,
        isCompact ? 8 : 12,
        isCompact ? 12 : 16,
        isCompact ? 8 : 12,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              controller: searchController,
              onChanged: onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Buscar produto...',
                hintStyle: TextStyle(color: Colors.grey.shade400),
                prefixIcon: Icon(Icons.search, color: Colors.grey.shade400),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: isCompact ? 11 : 14,
                ),
              ),
            ),
          ),
          SizedBox(height: isCompact ? 10 : 12),
          SizedBox(
            height: isCompact ? 36 : 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: categories.length + 1,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final isAll = index == 0;
                final cat = isAll ? null : categories[index - 1];
                final isSelected = isAll
                    ? selectedCategoryId == null
                    : selectedCategoryId == cat?.id;

                return GestureDetector(
                  onTap: () => onCategorySelected(cat?.id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF0F172A)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF0F172A)
                            : Colors.grey.shade200,
                      ),
                    ),
                    child: Text(
                      isAll ? 'TODOS' : cat!.safeName.toUpperCase(),
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.grey.shade600,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  double get maxExtent => isCompact ? 112 : 140;

  @override
  double get minExtent => isCompact ? 112 : 140;

  @override
  bool shouldRebuild(covariant _SearchAndCategoriesDelegate oldDelegate) {
    return oldDelegate.selectedCategoryId != selectedCategoryId ||
        oldDelegate.categories != categories ||
        oldDelegate.searchController != searchController ||
        oldDelegate.isCompact != isCompact;
  }
}

class _CartItemTile extends ConsumerWidget {
  const _CartItemTile({
    required this.item,
    required this.index,
    required this.product,
  });

  final OrderItem item;
  final int index;
  final Product? product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = NumberFormat.simpleCurrency(locale: 'pt_BR');
    final attrs = item.attributes ?? {};
    final colors = product == null ? <String>[] : _availableColors(product!);
    final sizes = product == null ? <String>[] : _availableSizes(product!);
    final selectedColor = attrs['Cor'];
    final selectedSize = attrs['Tamanho'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'REF: ${item.sku ?? '-'}',
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (attrs.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: attrs.entries
                        .map((e) => _buildAttrBadge(e.key, e.value))
                        .toList(),
                  ),
                ],
                if (colors.isNotEmpty || sizes.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      if (colors.isNotEmpty)
                        _buildOptionDropdown(
                          context: context,
                          label: 'Cor',
                          value: colors.contains(selectedColor)
                              ? selectedColor
                              : null,
                          options: colors,
                          onChanged: (value) => _updateOptions(
                            ref,
                            color: value,
                            size: selectedSize,
                          ),
                        ),
                      if (sizes.isNotEmpty)
                        _buildOptionDropdown(
                          context: context,
                          label: 'Tamanho',
                          value: sizes.contains(selectedSize)
                              ? selectedSize
                              : null,
                          options: sizes,
                          onChanged: (value) => _updateOptions(
                            ref,
                            color: selectedColor,
                            size: value,
                          ),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  currency.format(item.totalPrice),
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                IconButton(
                  onPressed: () => ref
                      .read(cartViewModelProvider.notifier)
                      .updateQuantity(index, item.quantity + 1),
                  icon: const Icon(Icons.add_rounded, size: 20),
                  color: const Color(0xFF0F172A),
                ),
                Text(
                  '${item.quantity}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
                IconButton(
                  onPressed: () => ref
                      .read(cartViewModelProvider.notifier)
                      .updateQuantity(index, item.quantity - 1),
                  icon: const Icon(Icons.remove_rounded, size: 20),
                  color: const Color(0xFF0F172A),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttrBadge(String key, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$key: $value',
        style: const TextStyle(
          color: Color(0xFF475569),
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildOptionDropdown({
    required BuildContext context,
    required String label,
    required String? value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
  }) {
    return SizedBox(
      width: 150,
      child: DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
        ),
        items: options
            .map(
              (option) => DropdownMenuItem(value: option, child: Text(option)),
            )
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  void _updateOptions(WidgetRef ref, {String? color, String? size}) {
    final attributes = <String, String>{...?item.attributes};
    if (color == null || color.trim().isEmpty) {
      attributes.remove('Cor');
    } else {
      attributes['Cor'] = color.trim();
    }
    if (size == null || size.trim().isEmpty) {
      attributes.remove('Tamanho');
    } else {
      attributes['Tamanho'] = size.trim();
    }

    ref
        .read(cartViewModelProvider.notifier)
        .updateItem(
          index,
          OrderItem(
            productId: item.productId,
            productName: item.productName,
            sku: _variantSkuFor(color: color, size: size),
            quantity: item.quantity,
            unitPrice: item.unitPrice,
            attributes: attributes.isEmpty ? null : attributes,
            notes: item.notes,
          ),
        );
  }

  String? _variantSkuFor({String? color, String? size}) {
    final currentSku = item.sku;
    final targetProduct = product;
    if (targetProduct == null) return currentSku;

    for (final variant in targetProduct.variants) {
      final variantColor = _variantAttribute(variant.attributes, const [
        'cor',
        'color',
        'colour',
      ]);
      final variantSize = _variantAttribute(variant.attributes, const [
        'tamanho',
        'tam',
        'size',
        'grade',
      ]);
      final matchesColor =
          color == null || variantColor == null || variantColor == color;
      final matchesSize =
          size == null || variantSize == null || variantSize == size;
      if (matchesColor && matchesSize && variant.sku.trim().isNotEmpty) {
        return variant.sku.trim();
      }
    }

    if (targetProduct.sku.trim().isNotEmpty) return targetProduct.sku.trim();
    return targetProduct.ref.isNotEmpty ? targetProduct.ref : currentSku;
  }

  List<String> _availableColors(Product product) {
    final values = <String>{};
    for (final color in product.colors) {
      final trimmed = color.trim();
      if (trimmed.isNotEmpty) values.add(trimmed);
    }
    for (final variant in product.variants) {
      final color = _variantAttribute(variant.attributes, const [
        'cor',
        'color',
        'colour',
      ]);
      if (color != null && color.trim().isNotEmpty) values.add(color.trim());
    }
    return values.toList();
  }

  List<String> _availableSizes(Product product) {
    final values = <String>{};
    for (final size in product.sizes) {
      final trimmed = size.trim();
      if (trimmed.isNotEmpty) values.add(trimmed);
    }
    for (final variant in product.variants) {
      final size = _variantAttribute(variant.attributes, const [
        'tamanho',
        'tam',
        'size',
        'grade',
      ]);
      if (size != null && size.trim().isNotEmpty) values.add(size.trim());
    }
    return values.toList();
  }

  String? _variantAttribute(
    Map<String, String> attributes,
    List<String> aliases,
  ) {
    for (final entry in attributes.entries) {
      final key = _normalizeAttributeKey(entry.key);
      if (aliases.contains(key)) return entry.value;
    }
    return null;
  }

  String _normalizeAttributeKey(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll('ç', 'c')
        .replaceAll('ã', 'a')
        .replaceAll('á', 'a')
        .replaceAll('à', 'a')
        .replaceAll('â', 'a')
        .replaceAll('é', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ô', 'o')
        .replaceAll('õ', 'o')
        .replaceAll('ú', 'u');
  }
}
