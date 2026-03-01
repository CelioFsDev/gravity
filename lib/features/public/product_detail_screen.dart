import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:catalogo_ja/models/product.dart';
import 'package:catalogo_ja/models/catalog.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:catalogo_ja/viewmodels/settings_viewmodel.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:catalogo_ja/ui/theme/app_tokens.dart';
import 'package:catalogo_ja/ui/widgets/app_badge_pill.dart';
import 'package:catalogo_ja/ui/widgets/app_primary_button.dart';
import 'package:catalogo_ja/ui/widgets/app_scaffold.dart';

class PublicProductDetailScreen extends ConsumerStatefulWidget {
  final Product product;
  final CatalogMode mode;

  const PublicProductDetailScreen({
    super.key,
    required this.product,
    required this.mode,
  });

  @override
  ConsumerState<PublicProductDetailScreen> createState() =>
      _PublicProductDetailScreenState();
}

class _PublicProductDetailScreenState
    extends ConsumerState<PublicProductDetailScreen> {
  String? _selectedColor;
  String? _selectedSize;
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

  Future<void> _orderViaWhatsApp() async {
    final settings = ref.read(settingsViewModelProvider);
    final whatsapp = settings.whatsappNumber;

    final currency = NumberFormat.simpleCurrency(locale: 'pt_BR');
    final price = widget.product.priceForMode(
      widget.mode == CatalogMode.atacado ? 'atacado' : 'varejo',
    );

    final message =
        '''
Ol\u00e1! Vi este produto no cat\u00e1logo:
*${widget.product.name}*
REF: ${widget.product.ref}
Pre\u00e7o: ${currency.format(price)}
Cor: ${_selectedColor ?? 'N/A'}
Tamanho: ${_selectedSize ?? 'N/A'}

Pode me ajudar?
''';

    final url = Uri.parse(
      'https://wa.me/$whatsapp?text=${Uri.encodeComponent(message)}',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.simpleCurrency(locale: 'pt_BR');
    final price = widget.product.priceForMode(
      widget.mode == CatalogMode.atacado ? 'atacado' : 'varejo',
    );
    final hasPromo = widget.product.promoEnabled;

    return AppScaffold(
      showHeader: false,
      maxWidth: 600,
      body: CustomScrollView(
        slivers: [
          // Elegant Header
          SliverAppBar(
            pinned: true,
            expandedHeight: 400,
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new,
                size: 20,
                color: AppTokens.textPrimary,
              ),
              style: IconButton.styleFrom(backgroundColor: Colors.white70),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(background: _buildGallery()),
          ),

          SliverPadding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTokens.space24,
              vertical: AppTokens.space24,
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Title Area
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.product.ref,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: AppTokens.accentBlue,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.product.name,
                            style: Theme.of(
                              context,
                            ).textTheme.headlineSmall?.copyWith(fontSize: 26),
                          ),
                        ],
                      ),
                    ),
                    if (widget.product.isOutOfStock)
                      const AppBadgePill(
                        label: 'ESGOTADO',
                        color: AppTokens.textMuted,
                        isLarge: true,
                      ),
                    if (!widget.product.isOutOfStock && hasPromo)
                      const AppBadgePill(
                        label: 'OFERTA',
                        color: AppTokens.accentRed,
                        isLarge: true,
                      ),
                  ],
                ),

                const SizedBox(height: AppTokens.space24),

                // Prices
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currency.format(price),
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: AppTokens.textPrimary,
                            fontWeight: FontWeight.w900,
                            fontSize: 32,
                          ),
                    ),
                    if (hasPromo)
                      Text(
                        'De: ${currency.format(widget.mode == CatalogMode.atacado ? widget.product.priceWholesale : widget.product.priceRetail)}',
                        style: const TextStyle(
                          decoration: TextDecoration.lineThrough,
                          color: AppTokens.textMuted,
                          fontSize: 16,
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: AppTokens.space32),

                // Colors
                if (widget.product.colors.isNotEmpty) ...[
                  Text(
                    'Cor'.toUpperCase(),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: AppTokens.space12),
                  _buildColorSelector(),
                  const SizedBox(height: AppTokens.space24),
                ],

                // Sizes
                if (widget.product.sizes.isNotEmpty) ...[
                  Text(
                    'Tamanho'.toUpperCase(),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: AppTokens.space12),
                  _buildSizeSelector(),
                  const SizedBox(height: AppTokens.space24),
                ],

                const Divider(height: AppTokens.space32),

                // Description
                if (widget.product.description != null &&
                    widget.product.description!.isNotEmpty) ...[
                  Text(
                    'Detalhes do Produto',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppTokens.space12),
                  Text(
                    widget.product.description!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTokens.textMuted,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 100), // Spacing for fab
                ],
              ]),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildGallery() {
    return PageView.builder(
      controller: _pageController,
      itemCount: widget.product.images.isEmpty
          ? 1
          : widget.product.images.length,
      itemBuilder: (context, idx) {
        final path = widget.product.images.isEmpty
            ? ''
            : widget.product.images[idx];
        return _buildImage(path);
      },
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
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? AppTokens.accentBlue : Colors.white,
              borderRadius: BorderRadius.circular(AppTokens.radiusMd),
              border: Border.all(
                color: isSelected ? AppTokens.accentBlue : AppTokens.border,
              ),
              boxShadow: isSelected ? [AppTokens.shadowSm] : null,
            ),
            child: Text(
              c,
              style: TextStyle(
                color: isSelected ? Colors.white : AppTokens.textPrimary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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
      children: widget.product.sizes.map((s) {
        final isSelected = _selectedSize == s;
        return InkWell(
          onTap: () => setState(() => _selectedSize = s),
          child: Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected ? AppTokens.textPrimary : Colors.white,
              border: Border.all(
                color: isSelected ? AppTokens.textPrimary : AppTokens.border,
              ),
            ),
            child: Text(
              s,
              style: TextStyle(
                color: isSelected ? Colors.white : AppTokens.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(AppTokens.space24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppTokens.border)),
      ),
      child: AppPrimaryButton(
        label: widget.product.isOutOfStock
            ? 'PRODUTO INDISPON\u00cdVEL'
            : 'PEDIR NO WHATSAPP',
        icon: Icons.chat_outlined,
        onPressed: widget.product.isOutOfStock ? null : _orderViaWhatsApp,
      ),
    );
  }

  Widget _buildImage(String path) {
    if (path.isEmpty) {
      return Container(
        color: AppTokens.bg,
        child: const Icon(
          Icons.image_not_supported,
          size: 64,
          color: AppTokens.textMuted,
        ),
      );
    }

    final isRemote = path.startsWith('http') || path.startsWith('data:');
    final image = kIsWeb || isRemote
        ? Image.network(path, fit: BoxFit.cover)
        : Image.file(File(path), fit: BoxFit.cover);

    return image;
  }
}
