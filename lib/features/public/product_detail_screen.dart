import 'dart:convert';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:catalogo_ja/models/product.dart';
import 'package:catalogo_ja/models/catalog.dart';
import 'package:catalogo_ja/models/order.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:catalogo_ja/ui/theme/app_tokens.dart';
import 'package:catalogo_ja/ui/widgets/app_badge_pill.dart';
import 'package:catalogo_ja/ui/widgets/app_primary_button.dart';
import 'package:catalogo_ja/core/services/app_logger.dart';
import 'package:catalogo_ja/viewmodels/cart_viewmodel.dart';
import 'package:go_router/go_router.dart';

class PublicProductDetailScreen extends ConsumerStatefulWidget {
  final Product product;
  final CatalogMode mode;
  final String? shareCode;

  const PublicProductDetailScreen({
    super.key,
    required this.product,
    required this.mode,
    this.shareCode,
  });

  @override
  ConsumerState<PublicProductDetailScreen> createState() =>
      _PublicProductDetailScreenState();
}

class _PublicProductDetailScreenState
    extends ConsumerState<PublicProductDetailScreen> {
  String? _selectedColor;
  String? _selectedSize;
  int _quantity = 1;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    if (widget.product.colors.isNotEmpty) {
      _selectedColor = widget.product.colors.first;
    }
    if (widget.product.sizes.isNotEmpty) {
      _selectedSize = widget.product.sizes.first;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _updateImageForColor(String color) {
    if (widget.product.images.isNotEmpty) {
      final idx = widget.product.imageIndicesByColor[color]?.first ?? -1;
      if (idx != -1) {
        _pageController.animateToPage(
          idx,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
      setState(() {
        _selectedColor = color;
      });
    } else {
      setState(() => _selectedColor = color);
    }
  }

  void _addToCart() {
    final price = widget.product.priceForMode(
      widget.mode == CatalogMode.atacado ? 'atacado' : 'varejo',
    );

    final attributes = <String, String>{};
    if ((_selectedColor ?? '').isNotEmpty) {
      attributes['Cor'] = _selectedColor!;
    }
    if ((_selectedSize ?? '').isNotEmpty) {
      attributes['Tamanho'] = _selectedSize!;
    }

    ref
        .read(cartViewModelProvider.notifier)
        .addItem(
          OrderItem(
            productId: widget.product.id,
            productName: widget.product.name,
            sku: widget.product.sku.isNotEmpty
                ? widget.product.sku
                : widget.product.ref,
            quantity: _quantity,
            unitPrice: price,
            attributes: attributes.isEmpty ? null : attributes,
          ),
        );

    ref
        .read(appLoggerProvider.notifier)
        .log(
          AppEvent.orderSubmitted,
          parameters: {
            'action': 'add_to_cart',
            'productId': widget.product.id,
            'productRef': widget.product.ref,
            'color': _selectedColor,
            'size': _selectedSize,
            'quantity': _quantity,
          },
        );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text('${widget.product.name} adicionado!')),
          ],
        ),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        action: SnackBarAction(
          label: 'CONTINUAR',
          textColor: Colors.white,
          onPressed: _goBackToProducts,
        ),
      ),
    );
  }

  void _goBackToProducts() {
    final code = widget.shareCode?.trim();
    if (code != null && code.isNotEmpty) {
      context.go('/c/$code');
    } else {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.simpleCurrency(locale: 'pt_BR');
    final price = widget.product.priceForMode(
      widget.mode == CatalogMode.atacado ? 'atacado' : 'varejo',
    );
    final hasPromo = widget.product.promoEnabled;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: CircleAvatar(
            backgroundColor: Colors.white.withOpacity(0.9),
            child: IconButton(
              icon: const Icon(
                Icons.arrow_back_rounded,
                color: Color(0xFF0F172A),
              ),
              onPressed: _goBackToProducts,
            ),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: CircleAvatar(
              backgroundColor: Colors.white.withOpacity(0.9),
              child: IconButton(
                icon: const Icon(
                  Icons.share_outlined,
                  color: Color(0xFF0F172A),
                ),
                onPressed: () {
                  // Implement share logic if needed
                },
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Gallery
            _buildGallerySection(),

            // Product Info
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        widget.product.ref.toUpperCase(),
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                      if (hasPromo)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF43F5E).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'PROMOÇÃO',
                            style: TextStyle(
                              color: Color(0xFFF43F5E),
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.product.name,
                    style: const TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        currency.format(price),
                        style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (hasPromo) ...[
                        const SizedBox(width: 12),
                        Text(
                          currency.format(
                            widget.mode == CatalogMode.atacado
                                ? widget.product.priceWholesale
                                : widget.product.priceRetail,
                          ),
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const Divider(height: 48),

                  // Attributes
                  if (widget.product.colors.isNotEmpty) ...[
                    _buildSectionTitle('COR'),
                    const SizedBox(height: 12),
                    _buildColorSelector(),
                    const SizedBox(height: 32),
                  ],

                  if (widget.product.sizes.isNotEmpty) ...[
                    _buildSectionTitle('TAMANHO'),
                    const SizedBox(height: 12),
                    _buildSizeSelector(),
                    const SizedBox(height: 32),
                  ],

                  _buildSectionTitle('QUANTIDADE'),
                  const SizedBox(height: 12),
                  _buildQuantitySelector(),

                  if ((widget.product.description ?? '').trim().isNotEmpty) ...[
                    const Divider(height: 64),
                    _buildSectionTitle('DESCRIÇÃO'),
                    const SizedBox(height: 12),
                    Text(
                      widget.product.description!,
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 16,
                        height: 1.6,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildGallerySection() {
    final images = widget.product.images;
    return SizedBox(
      height: 480,
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: images.isEmpty ? 1 : images.length,
            itemBuilder: (context, index) {
              final uri = images.isEmpty ? '' : images[index].uri;
              return _buildImage(uri);
            },
          ),
          // Gradient overlay for better visibility of back button
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 120,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withOpacity(0.2), Colors.transparent],
                ),
              ),
            ),
          ),
          // Page indicators
          if (images.length > 1)
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: ListenableBuilder(
                    listenable: _pageController,
                    builder: (context, _) {
                      final current = _pageController.hasClients
                          ? _pageController.page?.round() ?? 0
                          : 0;
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(
                          images.length,
                          (i) => Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: i == current
                                  ? Colors.white
                                  : Colors.white.withOpacity(0.4),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        color: Colors.grey.shade400,
        fontSize: 13,
        fontWeight: FontWeight.w900,
        letterSpacing: 1,
      ),
    );
  }

  Widget _buildColorSelector() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: widget.product.colors.map((c) {
        final isSelected = _selectedColor == c;
        return GestureDetector(
          onTap: () => _updateImageForColor(c),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF0F172A) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF0F172A)
                    : Colors.grey.shade200,
                width: 1.5,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              c,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey.shade700,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSizeSelector() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: widget.product.sizes.map((s) {
        final isSelected = _selectedSize == s;
        return GestureDetector(
          onTap: () => setState(() => _selectedSize = s),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF0F172A) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF0F172A)
                    : Colors.grey.shade200,
                width: 1.5,
              ),
            ),
            child: Text(
              s,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey.shade700,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildQuantitySelector() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildQtyBtn(Icons.remove, () {
            if (_quantity > 1) setState(() => _quantity--);
          }),
          Container(
            width: 60,
            alignment: Alignment.center,
            child: Text(
              '$_quantity',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
          _buildQtyBtn(Icons.add, () => setState(() => _quantity++)),
        ],
      ),
    );
  }

  Widget _buildQtyBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4),
          ],
        ),
        child: Icon(icon, size: 20, color: const Color(0xFF0F172A)),
      ),
    );
  }

  Widget _buildBottomBar() {
    final isOutOfStock = widget.product.isOutOfStock;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
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
      child: Row(
        children: [
          OutlinedButton.icon(
            onPressed: _goBackToProducts,
            icon: const Icon(Icons.arrow_back_rounded, size: 18),
            label: const Text('VOLTAR'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF0F172A),
              side: BorderSide(color: Colors.grey.shade300),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              onPressed: isOutOfStock ? null : _addToCart,
              style: FilledButton.styleFrom(
                backgroundColor: isOutOfStock
                    ? Colors.grey.shade200
                    : const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isOutOfStock
                        ? Icons.block
                        : Icons.add_shopping_cart_rounded,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      isOutOfStock ? 'ESGOTADO' : 'ADICIONAR',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
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

  Widget _buildImage(String path) {
    if (path.isEmpty || path.startsWith('gs://')) {
      return Container(
        color: const Color(0xFFF1F5F9),
        child: Center(
          child: Icon(
            path.startsWith('gs://') ? Icons.cloud_off : Icons.image_outlined,
            size: 64,
            color: Colors.grey.shade300,
          ),
        ),
      );
    }

    if (path.startsWith('data:')) {
      try {
        final commaIndex = path.indexOf(',');
        if (commaIndex == -1) throw Exception();
        final bytes = base64Decode(path.substring(commaIndex + 1));
        return Image.memory(bytes, fit: BoxFit.cover);
      } catch (_) {
        return _buildImage('');
      }
    }

    if (path.startsWith('http') || path.startsWith('blob:')) {
      return CachedNetworkImage(
        imageUrl: path,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          color: const Color(0xFFF1F5F9),
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        errorWidget: (context, url, error) => _buildImage(''),
      );
    }

    if (!kIsWeb) {
      final file = File(path);
      if (file.existsSync()) {
        return Image.file(file, fit: BoxFit.cover);
      }
    }

    return _buildImage('');
  }
}
