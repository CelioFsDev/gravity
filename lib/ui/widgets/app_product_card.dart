import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:catalogo_ja/core/utils/uri_utils.dart';
import 'package:catalogo_ja/models/catalog.dart';
import 'package:catalogo_ja/models/order.dart';
import 'package:catalogo_ja/models/product.dart';
import 'package:catalogo_ja/models/product_image.dart';
import 'package:catalogo_ja/models/product_variant.dart';
import 'package:catalogo_ja/viewmodels/cart_viewmodel.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class AppProductCard extends ConsumerStatefulWidget {
  final Product product;
  final CatalogMode mode;
  final VoidCallback onTap;

  const AppProductCard({
    super.key,
    required this.product,
    required this.mode,
    required this.onTap,
  });

  @override
  ConsumerState<AppProductCard> createState() => _AppProductCardState();
}

class _AppProductCardState extends ConsumerState<AppProductCard> {
  String? _selectedColor;
  String? _selectedSize;
  int _quantity = 1;

  @override
  void initState() {
    super.initState();
    _setDefaultOptions();
  }

  @override
  void didUpdateWidget(covariant AppProductCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.product.id != widget.product.id) {
      _quantity = 1;
      _setDefaultOptions();
    }
  }

  void _setDefaultOptions() {
    final colors = _availableColors;
    final sizes = _availableSizes;
    _selectedColor = colors.isNotEmpty ? colors.first : null;
    _selectedSize = sizes.isNotEmpty ? sizes.first : null;
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.simpleCurrency(locale: 'pt_BR');
    final price = widget.product.priceForMode(
      widget.mode == CatalogMode.atacado ? 'atacado' : 'varejo',
    );
    final colors = _availableColors;
    final sizes = _availableSizes;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: GestureDetector(
              onTap: widget.onTap,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildImage(widget.product.mainImage),
                  if (widget.product.promoEnabled)
                    Positioned(
                      top: 10,
                      left: 10,
                      child: _buildTag('PROMO', const Color(0xFFF43F5E)),
                    ),
                  if (widget.product.isOutOfStock)
                    Container(
                      color: Colors.black.withOpacity(0.5),
                      alignment: Alignment.center,
                      child: _buildTag('ESGOTADO', Colors.white, isLarge: true),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(11),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: widget.onTap,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.product.ref.toUpperCase(),
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF1E293B),
                          fontSize: 13,
                          height: 1.15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  currency.format(price),
                  style: const TextStyle(
                    color: Color(0xFF2563EB),
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                if (colors.isNotEmpty || sizes.isNotEmpty) ...[
                  Row(
                    children: [
                      if (colors.isNotEmpty)
                        Expanded(
                          child: _buildCompactDropdown(
                            value: colors.contains(_selectedColor)
                                ? _selectedColor
                                : null,
                            hint: 'Cor',
                            options: colors,
                            onChanged: (value) =>
                                setState(() => _selectedColor = value),
                          ),
                        ),
                      if (colors.isNotEmpty && sizes.isNotEmpty)
                        const SizedBox(width: 7),
                      if (sizes.isNotEmpty)
                        Expanded(
                          child: _buildCompactDropdown(
                            value: sizes.contains(_selectedSize)
                                ? _selectedSize
                                : null,
                            hint: 'Tam',
                            options: sizes,
                            onChanged: (value) =>
                                setState(() => _selectedSize = value),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                Row(
                  children: [
                    _buildQtyButton(Icons.remove_rounded, () {
                      if (_quantity > 1) setState(() => _quantity--);
                    }),
                    SizedBox(
                      width: 30,
                      child: Text(
                        '$_quantity',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    _buildQtyButton(
                      Icons.add_rounded,
                      () => setState(() => _quantity++),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: widget.product.isOutOfStock
                            ? null
                            : _addToCart,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          minimumSize: const Size(0, 36),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(11),
                          ),
                        ),
                        icon: const Icon(
                          Icons.add_shopping_cart_rounded,
                          size: 15,
                        ),
                        label: const Text(
                          'Add',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactDropdown({
    required String? value,
    required String hint,
    required List<String> options,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      dropdownColor: Colors.white,
      iconEnabledColor: const Color(0xFF475569),
      style: const TextStyle(
        color: Color(0xFF0F172A),
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          color: Color(0xFF64748B),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        isDense: true,
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
      selectedItemBuilder: (context) => options
          .map(
            (option) => Align(
              alignment: Alignment.centerLeft,
              child: Text(
                option,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          )
          .toList(),
      items: options
          .map(
            (option) => DropdownMenuItem(
              value: option,
              child: Text(
                option,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildQtyButton(IconData icon, VoidCallback onPressed) {
    return SizedBox(
      width: 29,
      height: 29,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
        padding: EdgeInsets.zero,
        style: IconButton.styleFrom(
          backgroundColor: const Color(0xFFF1F5F9),
          foregroundColor: const Color(0xFF475569),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        ),
      ),
    );
  }

  void _addToCart() {
    final attrs = <String, String>{};
    if ((_selectedColor ?? '').trim().isNotEmpty) {
      attrs['Cor'] = _selectedColor!.trim();
    }
    if ((_selectedSize ?? '').trim().isNotEmpty) {
      attrs['Tamanho'] = _selectedSize!.trim();
    }

    final price = widget.product.priceForMode(
      widget.mode == CatalogMode.atacado ? 'atacado' : 'varejo',
    );

    ref
        .read(cartViewModelProvider.notifier)
        .addItem(
          OrderItem(
            productId: widget.product.id,
            productName: widget.product.name,
            sku: _selectedVariantSku,
            quantity: _quantity,
            unitPrice: price,
            attributes: attrs.isEmpty ? null : attrs,
          ),
        );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${widget.product.name} adicionado ao pedido.'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
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

  Widget _buildTag(String label, Color color, {bool isLarge = false}) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isLarge ? 12 : 8,
        vertical: isLarge ? 6 : 4,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color == Colors.white ? Colors.black : Colors.white,
          fontSize: isLarge ? 12 : 9,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildImage(ProductImage? img) {
    if (img == null || img.uri.isEmpty) {
      return _buildPlaceholder();
    }

    final uri = img.uri.trim();
    if (!UriUtils.isUsableImagePath(uri)) {
      return _buildPlaceholder();
    }

    if (uri.startsWith('gs://')) {
      return FutureBuilder<String?>(
        future: _getDownloadUrl(uri),
        builder: (context, snapshot) {
          final url = snapshot.data;
          if (url == null || url.isEmpty) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildLoadingPlaceholder();
            }
            return _buildPlaceholder(icon: Icons.cloud_off);
          }
          return _buildNetworkImage(url);
        },
      );
    }

    if (uri.startsWith('data:')) {
      return _buildDataUrlImage(uri);
    }

    if (UriUtils.isNetworkImageUri(uri)) {
      return _buildNetworkImage(uri);
    }

    if (!kIsWeb) {
      try {
        final file = File(uri);
        if (file.existsSync() &&
            file.statSync().type != FileSystemEntityType.directory) {
          return Image.file(file, fit: BoxFit.cover);
        }
      } catch (_) {}
    }

    return _buildPlaceholder();
  }

  Widget _buildNetworkImage(String uri) {
    return CachedNetworkImage(
      imageUrl: uri,
      fit: BoxFit.cover,
      placeholder: (context, url) => _buildLoadingPlaceholder(),
      errorWidget: (context, url, error) => _buildPlaceholder(),
    );
  }

  Widget _buildLoadingPlaceholder() {
    return Container(
      color: const Color(0xFFF1F5F9),
      child: const Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Color(0xFFCBD5E1),
          ),
        ),
      ),
    );
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

  Widget _buildPlaceholder({IconData icon = Icons.image_outlined}) {
    return Container(
      color: const Color(0xFFF1F5F9),
      child: Center(
        child: Icon(icon, color: const Color(0xFFCBD5E1), size: 32),
      ),
    );
  }

  Widget _buildDataUrlImage(String uri) {
    try {
      final commaIndex = uri.indexOf(',');
      if (commaIndex == -1) return _buildPlaceholder();
      final bytes = base64Decode(uri.substring(commaIndex + 1));
      return Image.memory(bytes, fit: BoxFit.cover);
    } catch (_) {
      return _buildPlaceholder();
    }
  }
}
