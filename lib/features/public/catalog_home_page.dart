import 'dart:ui';

import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:catalogo_ja/models/catalog.dart';
import 'package:catalogo_ja/models/product.dart';
import 'package:catalogo_ja/viewmodels/catalog_public_viewmodel.dart';
import 'package:catalogo_ja/ui/widgets/app_product_card.dart';
import 'package:catalogo_ja/ui/widgets/app_empty_state.dart';
import 'package:catalogo_ja/models/category.dart';
import 'package:catalogo_ja/models/order.dart';
import 'package:catalogo_ja/viewmodels/cart_viewmodel.dart';
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
                  'Não foi possível carregar esta vitrine.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey.shade900,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Detalhe técnico: $e',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => context.go('/'),
                  child: const Text('Voltar ao Início'),
                ),
              ],
            ),
          ),
        ),
      ),
      data: (data) {
        try {
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
                        categories: data.categories,
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
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
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
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
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
        } catch (e) {
          debugPrint('Error building public catalog UI: $e');
          return const Scaffold(
            backgroundColor: Color(0xFFF8FAFC),
            body: Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Nao foi possivel montar esta vitrine.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }
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
                color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
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
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
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
              color: const Color(0xFF0F172A).withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
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
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: cart.items.length,
                    separatorBuilder: (_, _) => const Divider(height: 32),
                    itemBuilder: (context, index) {
                      final item = cart.items[index];
                      // Find actual product for image
                      final product = products.firstWhere(
                        (p) => p.id == item.productId,
                        orElse: () => products.first,
                      );

                      return Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: SizedBox(
                              width: 64,
                              height: 64,
                              child: product.images.isNotEmpty
                                  ? Image.network(
                                      product.images.first.uri,
                                      fit: BoxFit.cover,
                                    )
                                  : Container(color: Colors.grey.shade100),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.productName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                if (item.attributes != null)
                                  Text(
                                    item.attributes!.values.join(' / '),
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 12,
                                    ),
                                  ),
                                const SizedBox(height: 4),
                                Text(
                                  currency.format(item.unitPrice),
                                  style: const TextStyle(
                                    color: Color(0xFF2563EB),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline),
                                onPressed: () => ref
                                    .read(cartViewModelProvider.notifier)
                                    .updateQuantity(index, item.quantity - 1),
                              ),
                              Text(
                                '${item.quantity}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline),
                                onPressed: () => ref
                                    .read(cartViewModelProvider.notifier)
                                    .updateQuantity(index, item.quantity + 1),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
          ),

          // Footer
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SafeArea(
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        currency.format(cart.subtotal),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: cart.items.isEmpty
                          ? null
                          : () => _checkout(
                              context,
                              cart,
                              catalog,
                              whatsappNumber,
                              products,
                            ),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'ENVIAR PEDIDO VIA WHATSAPP',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _checkout(
    BuildContext context,
    CartState cart,
    Catalog catalog,
    String? whatsapp,
    List<Product> products,
  ) async {
    final cleanPhone = whatsapp?.replaceAll(RegExp(r'[^0-9]'), '') ?? '';
    if (cleanPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('WhatsApp do vendedor não configurado')),
      );
      return;
    }

    final currency = NumberFormat.simpleCurrency(locale: 'pt_BR');
    var message = '*NOVO PEDIDO - CATALOGO JA*\n';
    message += '*Vitrine:* ${catalog.name}\n\n';

    for (final item in cart.items) {
      final product = _findProductForOrderItem(products, item);
      final reference = _resolveOrderReference(product, item);
      final color = _resolveOrderAttribute(item, const ['Cor', 'COR', 'color']);
      final size = _resolveOrderAttribute(item, const [
        'Tamanho',
        'TAM',
        'Tam',
        'tamanho',
        'size',
      ]);

      message += '\u2022 ${item.productName}\n';
      message += 'Referencia: $reference\n';
      message += 'Cor: ${color.isEmpty ? '-' : color}\n';
      message += 'Tam: ${size.isEmpty ? '-' : size}\n';
      message += 'Valor: ${currency.format(item.unitPrice)}\n';
      message += 'Quantidade: ${item.quantity}\n';
      message += 'Preco: ${currency.format(item.totalPrice)}\n\n';
    }

    message += '\n*TOTAL: ${currency.format(cart.subtotal)}*';

    final launched = await _launchWhatsAppOrder(
      phone: cleanPhone,
      message: message,
    );
    if (!launched && context.mounted) {
      await Clipboard.setData(ClipboardData(text: message));
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Pedido copiado'),
          content: const Text(
            'Nao foi possivel abrir o WhatsApp automaticamente. A mensagem do pedido foi copiada para voce colar no WhatsApp.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  Future<bool> _launchWhatsAppOrder({
    required String phone,
    required String message,
  }) async {
    final encodedMessage = Uri.encodeComponent(message);
    final urls = kIsWeb
        ? [
            Uri.parse(
              'https://api.whatsapp.com/send?phone=$phone&text=$encodedMessage',
            ),
            Uri.parse('https://wa.me/$phone?text=$encodedMessage'),
          ]
        : [
            Uri.parse('whatsapp://send?phone=$phone&text=$encodedMessage'),
            Uri.parse('https://wa.me/$phone?text=$encodedMessage'),
            Uri.parse(
              'https://api.whatsapp.com/send?phone=$phone&text=$encodedMessage',
            ),
          ];

    for (final uri in urls) {
      try {
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
          webOnlyWindowName: '_blank',
        );
        if (launched) return true;
      } catch (_) {
        continue;
      }
    }

    return false;
  }

  Product? _findProductForOrderItem(List<Product> products, OrderItem item) {
    for (final product in products) {
      if (product.id == item.productId) return product;
    }
    return null;
  }

  String _resolveOrderReference(Product? product, OrderItem item) {
    final productRef = product?.ref.trim() ?? '';
    if (productRef.isNotEmpty) return productRef;
    final sku = item.sku?.trim() ?? '';
    if (sku.isNotEmpty) return sku;
    return item.productId;
  }

  String _resolveOrderAttribute(OrderItem item, List<String> keys) {
    final attributes = item.attributes;
    if (attributes == null || attributes.isEmpty) return '';
    for (final key in keys) {
      final value = attributes[key]?.trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    final lowerKeys = keys.map((key) => key.toLowerCase()).toSet();
    for (final entry in attributes.entries) {
      if (lowerKeys.contains(entry.key.toLowerCase())) {
        return entry.value.trim();
      }
    }
    return '';
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
      padding: EdgeInsets.fromLTRB(16, isCompact ? 8 : 16, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: searchController,
            onChanged: onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Buscar produtos...',
              prefixIcon: const Icon(Icons.search, color: Color(0xFF64748B)),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
            ),
          ),
          if (categories.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: categories.length + 1,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final isAll = index == 0;
                  final category = isAll ? null : categories[index - 1];
                  final categoryId = category?.id;
                  final label = isAll ? 'Todos' : category?.safeName ?? '';
                  final isSelected = isAll
                      ? selectedCategoryId == null
                      : selectedCategoryId == categoryId;

                  return FilterChip(
                    label: Text(label),
                    selected: isSelected,
                    onSelected: (_) => onCategorySelected(categoryId),
                    backgroundColor: Colors.white,
                    selectedColor: const Color(0xFF0F172A),
                    labelStyle: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : const Color(0xFF64748B),
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      fontSize: 13,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isSelected
                            ? Colors.transparent
                            : Colors.grey.shade200,
                      ),
                    ),
                    showCheckmark: false,
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  double get maxExtent => categories.isNotEmpty ? (isCompact ? 120 : 130) : 70;
  @override
  double get minExtent => categories.isNotEmpty ? (isCompact ? 120 : 130) : 70;
  @override
  bool shouldRebuild(covariant _SearchAndCategoriesDelegate oldDelegate) =>
      true;
}

class _HeaderPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _HeaderPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
