import 'dart:convert';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:catalogo_ja/models/product.dart';
import 'package:catalogo_ja/models/product_variant.dart';
import 'package:catalogo_ja/models/catalog.dart';
import 'package:catalogo_ja/models/order.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:catalogo_ja/core/services/app_logger.dart';
import 'package:catalogo_ja/core/utils/uri_utils.dart';
import 'package:catalogo_ja/viewmodels/cart_viewmodel.dart';
import 'package:firebase_storage/firebase_storage.dart';
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
    final colors = _availableColors;
    final sizes = _availableSizes;
    if (colors.isNotEmpty) {
      _selectedColor = colors.first;
    }
    if (sizes.isNotEmpty) {
      _selectedSize = sizes.first;
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
            sku: _selectedVariantSku,
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

  List<String> get _availableColors {
    final values = <String>{};
    for (final color in widget.product.colors) {
      final trimmed = color.trim();
      if (trimmed.isNotEmpty) values.add(trimmed);
    }
    for (final variant in widget.product.variants) {
      final color = _variantAttribute(variant.attributes, const [
        'cor',
        'color',
        'colour',
      ]);
      if (color != null && color.trim().isNotEmpty) values.add(color.trim());
    }
    return values.toList();
  }

  List<String> get _availableSizes {
    final values = <String>{};
    for (final size in widget.product.sizes) {
      final trimmed = size.trim();
      if (trimmed.isNotEmpty) values.add(trimmed);
    }
    for (final variant in widget.product.variants) {
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

  String get _selectedVariantSku {
    ProductVariant? selected;
    for (final variant in widget.product.variants) {
      final color = _variantAttribute(variant.attributes, const [
        'cor',
        'color',
        'colour',
      ]);
      final size = _variantAttribute(variant.attributes, const [
        'tamanho',
        'tam',
        'size',
        'grade',
      ]);
      final matchesColor =
          _selectedColor == null || color == null || color == _selectedColor;
      final matchesSize =
          _selectedSize == null || size == null || size == _selectedSize;
      if (matchesColor && matchesSize) {
        selected = variant;
        break;
      }
    }

    if (selected != null && selected.sku.trim().isNotEmpty) {
      return selected.sku.trim();
    }
    if (widget.product.sku.trim().isNotEmpty) return widget.product.sku.trim();
    return widget.product.ref;
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
                  if (_availableColors.isNotEmpty) ...[
                    _buildSectionTitle('COR'),
                    const SizedBox(height: 12),
                    _buildColorSelector(),
                    const SizedBox(height: 32),
                  ],

                  if (_availableSizes.isNotEmpty) ...[
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
      children: _availableColors.map((c) {
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
      children: _availableSizes.map((s) {
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
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(24, 14, 24, 16 + bottomPadding),
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
          _buildBottomOptionsPanel(),
          const SizedBox(height: 12),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _goBackToProducts,
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: const Text('VOLTAR'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0F172A),
                  side: BorderSide(color: Colors.grey.shade300),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 20,
                  ),
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
        ],
      ),
    );
  }

  Widget _buildBottomOptionsPanel() {
    final colors = _availableColors;
    final sizes = _availableSizes;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: colors.isEmpty
                  ? _buildFreeOptionField(
                      label: 'Cor',
                      onChanged: (value) => _selectedColor = value.trim(),
                    )
                  : _buildOptionDropdown(
                      label: 'Cor',
                      value: colors.contains(_selectedColor)
                          ? _selectedColor
                          : null,
                      options: colors,
                      onChanged: (value) =>
                          setState(() => _selectedColor = value),
                    ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: sizes.isEmpty
                  ? _buildFreeOptionField(
                      label: 'Tamanho',
                      onChanged: (value) => _selectedSize = value.trim(),
                    )
                  : _buildOptionDropdown(
                      label: 'Tamanho',
                      value: sizes.contains(_selectedSize)
                          ? _selectedSize
                          : null,
                      options: sizes,
                      onChanged: (value) =>
                          setState(() => _selectedSize = value),
                    ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            const Text(
              'Quantidade',
              style: TextStyle(
                color: Color(0xFF475569),
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
            const Spacer(),
            _buildQuantitySelector(),
          ],
        ),
      ],
    );
  }

  Widget _buildOptionDropdown({
    required String label,
    required String? value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: _bottomOptionDecoration(label),
      items: options
          .map((option) => DropdownMenuItem(value: option, child: Text(option)))
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildFreeOptionField({
    required String label,
    required ValueChanged<String> onChanged,
  }) {
    return TextField(
      onChanged: onChanged,
      decoration: _bottomOptionDecoration(label),
      textCapitalization: TextCapitalization.words,
    );
  }

  InputDecoration _bottomOptionDecoration(String label) {
    return InputDecoration(
      labelText: label,
      isDense: true,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
        borderSide: BorderSide(color: Color(0xFF0F172A), width: 1.4),
      ),
    );
  }

  Widget _buildImage(String path) {
    final imagePath = path.trim();
    if (!UriUtils.isUsableImagePath(imagePath)) {
      return Container(
        color: const Color(0xFFF1F5F9),
        child: Center(
          child: Icon(
            Icons.image_outlined,
            size: 64,
            color: Colors.grey.shade300,
          ),
        ),
      );
    }

    if (imagePath.startsWith('gs://')) {
      return FutureBuilder<String?>(
        future: _getDownloadUrl(imagePath),
        builder: (context, snapshot) {
          final url = snapshot.data;
          if (url == null || url.isEmpty) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Container(
                color: const Color(0xFFF1F5F9),
                child: const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            }
            return Container(
              color: const Color(0xFFF1F5F9),
              child: Center(
                child: Icon(
                  Icons.cloud_off,
                  size: 64,
                  color: Colors.grey.shade300,
                ),
              ),
            );
          }
          return _buildImage(url);
        },
      );
    }

    if (imagePath.startsWith('data:')) {
      try {
        final commaIndex = imagePath.indexOf(',');
        if (commaIndex == -1) throw Exception();
        final bytes = base64Decode(imagePath.substring(commaIndex + 1));
        return Image.memory(bytes, fit: BoxFit.cover);
      } catch (_) {
        return _buildImage('');
      }
    }

    if (UriUtils.isNetworkImageUri(imagePath)) {
      return CachedNetworkImage(
        imageUrl: imagePath,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          color: const Color(0xFFF1F5F9),
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        errorWidget: (context, url, error) => _buildImage(''),
      );
    }

    if (!kIsWeb) {
      try {
        final file = File(imagePath);
        if (file.existsSync() &&
            file.statSync().type != FileSystemEntityType.directory) {
          return Image.file(file, fit: BoxFit.cover);
        }
      } catch (_) {}
    }

    return _buildImage('');
  }

  Future<String?> _getDownloadUrl(String storageUri) async {
    try {
      final ref = FirebaseStorage.instanceFor(
        bucket: 'gs://catalogo-ja-89aae.firebasestorage.app',
      ).refFromURL(storageUri);
      return await ref.getDownloadURL();
    } catch (_) {
      return null;
    }
  }
}
