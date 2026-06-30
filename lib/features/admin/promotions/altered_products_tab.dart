import 'package:catalogo_ja/models/category.dart';
import 'package:catalogo_ja/models/product.dart';
import 'package:catalogo_ja/core/utils/safe_parse.dart';
import 'package:catalogo_ja/ui/theme/app_tokens.dart';
import 'package:catalogo_ja/ui/widgets/app_empty_state.dart';
import 'package:catalogo_ja/ui/widgets/app_error_view.dart';
import 'package:catalogo_ja/ui/widgets/section_card.dart';
import 'package:catalogo_ja/ui/widgets/promo_badge.dart';
import 'package:catalogo_ja/viewmodels/products_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:catalogo_ja/core/utils/currency_formatter.dart';

class AlteredProductsTab extends ConsumerStatefulWidget {
  const AlteredProductsTab({super.key});

  @override
  ConsumerState<AlteredProductsTab> createState() => _AlteredProductsTabState();
}

class _AlteredProductsTabState extends ConsumerState<AlteredProductsTab> {
  String _searchQuery = '';
  String? _selectedCollectionId;
  String? _selectedPromotionType;
  bool? _isActiveFilter;

  final Set<String> _selectedProductIds = {};
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    final productsState = ref.watch(productsViewModelProvider);

    return productsState.whenStandard(
      onRetry: () => ref.read(productsViewModelProvider.notifier).refresh(),
      data: _buildContent,
    );
  }

  Widget _buildContent(ProductsState state) {
    final groups =
        state.categories
            .where(
              (category) =>
                  category.type == CategoryType.collection ||
                  category.type == CategoryType.productType,
            )
            .toList()
          ..sort((a, b) => a.safeName.compareTo(b.safeName));

    final alteredProducts = state.allProducts
        .where(
          (p) =>
              p.promoEnabledRetail ||
              p.promoEnabledWholesale ||
              p.promotionName != null,
        )
        .toList();

    // KPIs
    int totalPromotions = alteredProducts.length;
    int activeRetail = alteredProducts
        .where((p) => p.promoEnabledRetail)
        .length;
    int activeWholesale = alteredProducts
        .where((p) => p.promoEnabledWholesale)
        .length;

    // Filters
    final q = _searchQuery.trim().toLowerCase();
    var filtered = alteredProducts;
    if (q.isNotEmpty) {
      filtered = filtered
          .where(
            (p) =>
                p.name.toLowerCase().contains(q) ||
                p.ref.toLowerCase().contains(q) ||
                (p.promotionName?.toLowerCase().contains(q) ?? false),
          )
          .toList();
    }
    if (_selectedCollectionId != null) {
      filtered = filtered
          .where((p) => p.categoryIds.contains(_selectedCollectionId))
          .toList();
    }
    if (_selectedPromotionType != null) {
      filtered = filtered
          .where(
            (p) =>
                p.resolvedPromotionType == _selectedPromotionType ||
                p.resolvedPromotionTypeWholesale == _selectedPromotionType,
          )
          .toList();
    }
    if (_isActiveFilter != null) {
      filtered = filtered
          .where(
            (p) =>
                p.promoEnabledRetail == _isActiveFilter ||
                p.promoEnabledWholesale == _isActiveFilter,
          )
          .toList();
    }

    filtered.sort(
      (a, b) => (b.promotionUpdatedAt ?? b.updatedAt).compareTo(
        a.promotionUpdatedAt ?? a.updatedAt,
      ),
    );

    return Column(
      children: [
        _buildKPIs(totalPromotions, activeRetail, activeWholesale),
        const SizedBox(height: 16),
        _buildFilters(groups),
        const SizedBox(height: 16),
        Expanded(child: _buildList(filtered)),
      ],
    );
  }

  Widget _buildKPIs(int total, int activeRetail, int activeWholesale) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.space24,
        vertical: 8,
      ),
      child: Row(
        children: [
          _kpiCard('Produtos Alterados', total.toString()),
          const SizedBox(width: 8),
          _kpiCard('Promos Varejo', activeRetail.toString()),
          const SizedBox(width: 8),
          _kpiCard('Promos Atacado', activeWholesale.toString()),
        ],
      ),
    );
  }

  Widget _kpiCard(String title, String value) {
    return Expanded(
      child: SectionCard(
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text(
              title,
              style: const TextStyle(fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters(List<Category> groups) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTokens.space24),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          SizedBox(
            width: 200,
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Buscar (Ref, Nome, Promocao)',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
          SizedBox(
            width: 200,
            child: DropdownButtonFormField<String?>(
              value: _selectedCollectionId,
              decoration: const InputDecoration(
                labelText: 'Coleção',
                isDense: true,
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('Todas')),
                ...groups.map(
                  (g) => DropdownMenuItem(value: g.id, child: Text(g.safeName)),
                ),
              ],
              onChanged: (v) => setState(() => _selectedCollectionId = v),
            ),
          ),
          SizedBox(
            width: 150,
            child: DropdownButtonFormField<String?>(
              value: _selectedPromotionType,
              decoration: const InputDecoration(
                labelText: 'Tipo',
                isDense: true,
              ),
              items: const [
                DropdownMenuItem(value: null, child: Text('Todos')),
                DropdownMenuItem(value: 'percent', child: Text('Porcentagem')),
                DropdownMenuItem(value: 'manual', child: Text('Manual')),
              ],
              onChanged: (v) => setState(() => _selectedPromotionType = v),
            ),
          ),
          SizedBox(
            width: 150,
            child: DropdownButtonFormField<bool?>(
              value: _isActiveFilter,
              decoration: const InputDecoration(
                labelText: 'Status',
                isDense: true,
              ),
              items: const [
                DropdownMenuItem(value: null, child: Text('Todos')),
                DropdownMenuItem(value: true, child: Text('Ativa')),
                DropdownMenuItem(value: false, child: Text('Removida')),
              ],
              onChanged: (v) => setState(() => _isActiveFilter = v),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<Product> products) {
    if (products.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(AppTokens.space24),
        child: AppEmptyState(
          icon: Icons.list_alt,
          title: 'Nenhum produto encontrado',
          subtitle: 'Altere os filtros ou crie novas promoções.',
          message: '',
        ),
      );
    }

    final allSelected =
        products.isNotEmpty && _selectedProductIds.length == products.length;
    final partiallySelected = _selectedProductIds.isNotEmpty && !allSelected;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTokens.space24),
          child: Row(
            children: [
              Checkbox(
                value: partiallySelected ? null : allSelected,
                tristate: true,
                onChanged: (_) {
                  setState(() {
                    if (allSelected) {
                      _selectedProductIds.clear();
                    } else {
                      _selectedProductIds.addAll(products.map((p) => p.id));
                    }
                  });
                },
              ),
              const Text('Selecionar todos na view atual'),
              const Spacer(),
              if (_selectedProductIds.isNotEmpty)
                FilledButton.icon(
                  onPressed: _isSaving
                      ? null
                      : () => _clearPromotionBatch(products),
                  icon: const Icon(Icons.delete_sweep),
                  label: Text(
                    'Remover promoção (${_selectedProductIds.length})',
                  ),
                  style: FilledButton.styleFrom(backgroundColor: Colors.red),
                ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(AppTokens.space24),
            itemCount: products.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final p = products[index];
              return _AlteredProductRow(
                key: ValueKey(p.id),
                product: p,
                selected: _selectedProductIds.contains(p.id),
                onSelect: (val) {
                  setState(() {
                    if (val == true)
                      _selectedProductIds.add(p.id);
                    else
                      _selectedProductIds.remove(p.id);
                  });
                },
                onSave: (Product updated) => _saveProduct(updated),
                onRemovePromotion: () => _clearPromotion(p),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _saveProduct(Product product) async {
    setState(() => _isSaving = true);
    try {
      await ref.read(productsViewModelProvider.notifier).updateProductsBulk([
        product,
      ]);
      if (mounted) _showSnack('Produto atualizado com sucesso.');
    } catch (e) {
      if (mounted) _showSnack('Erro ao salvar: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _clearPromotion(Product p) async {
    final updated = p.copyWith(
      promoEnabledRetail: false,
      promoPercentRetail: 0,
      clearPriceOriginalRetail: true,
      clearPricePromotionRetail: true,
      promoEnabledWholesale: false,
      promoPercentWholesale: 0,
      clearPriceOriginalWholesale: true,
      clearPricePromotionWholesale: true,
      updatedAt: DateTime.now(),
      clearPromotionName: true,
      clearPromotionCollectionId: true,
      clearPromotionCreatedAt: true,
      clearPromotionUpdatedAt: true,
      clearPromotionType: true,
      clearPromotionId: true,
    );
    await _saveProduct(updated);
  }

  Future<void> _clearPromotionBatch(List<Product> products) async {
    final toUpdate = products
        .where((p) => _selectedProductIds.contains(p.id))
        .map(
          (p) => p.copyWith(
            promoEnabledRetail: false,
            promoPercentRetail: 0,
            clearPriceOriginalRetail: true,
            clearPricePromotionRetail: true,
            promoEnabledWholesale: false,
            promoPercentWholesale: 0,
            clearPriceOriginalWholesale: true,
            clearPricePromotionWholesale: true,
            updatedAt: DateTime.now(),
            clearPromotionName: true,
            clearPromotionCollectionId: true,
            clearPromotionCreatedAt: true,
            clearPromotionUpdatedAt: true,
            clearPromotionType: true,
            clearPromotionId: true,
          ),
        )
        .toList();

    setState(() => _isSaving = true);
    try {
      await ref
          .read(productsViewModelProvider.notifier)
          .updateProductsBulk(toUpdate);
      if (mounted) {
        _selectedProductIds.clear();
        _showSnack('${toUpdate.length} promoções removidas.');
      }
    } catch (e) {
      if (mounted) _showSnack('Erro ao remover em lote: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _AlteredProductRow extends StatefulWidget {
  final Product product;
  final bool selected;
  final ValueChanged<bool?> onSelect;
  final ValueChanged<Product> onSave;
  final VoidCallback onRemovePromotion;

  const _AlteredProductRow({
    super.key,
    required this.product,
    required this.selected,
    required this.onSelect,
    required this.onSave,
    required this.onRemovePromotion,
  });

  @override
  State<_AlteredProductRow> createState() => _AlteredProductRowState();
}

class _AlteredProductRowState extends State<_AlteredProductRow> {
  late TextEditingController _percentRetailCtrl;
  late TextEditingController _manualRetailCtrl;
  late TextEditingController _percentWholesaleCtrl;
  late TextEditingController _manualWholesaleCtrl;

  late bool _isActiveRetail;
  late bool _isActiveWholesale;
  late String _typeRetail;
  late String _typeWholesale;

  @override
  void initState() {
    super.initState();
    _initValues();
  }

  void _initValues() {
    _isActiveRetail = widget.product.promoEnabledRetail;
    _isActiveWholesale = widget.product.promoEnabledWholesale;

    _typeRetail = widget.product.resolvedPromotionType;
    _typeWholesale = widget.product.resolvedPromotionTypeWholesale;

    _percentRetailCtrl = TextEditingController(
      text: widget.product.promoPercentRetail > 0
          ? _formatPercent(widget.product.promoPercentRetail)
          : '',
    );
    final pPriceR = widget.product.pricePromotionRetail ?? 0;
    _manualRetailCtrl = TextEditingController(
      text: pPriceR > 0 ? _formatCurrency(pPriceR) : '',
    );

    _percentWholesaleCtrl = TextEditingController(
      text: widget.product.promoPercentWholesale > 0
          ? _formatPercent(widget.product.promoPercentWholesale)
          : '',
    );
    final pPriceW = widget.product.pricePromotionWholesale ?? 0;
    _manualWholesaleCtrl = TextEditingController(
      text: pPriceW > 0 ? _formatCurrency(pPriceW) : '',
    );
  }

  @override
  void didUpdateWidget(covariant _AlteredProductRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.product != widget.product) {
      _initValues();
    }
  }

  @override
  void dispose() {
    _percentRetailCtrl.dispose();
    _manualRetailCtrl.dispose();
    _percentWholesaleCtrl.dispose();
    _manualWholesaleCtrl.dispose();
    super.dispose();
  }

  String _formatCurrency(double value) {
    final formatter = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    return formatter.format(value);
  }

  String _formatPercent(double value) {
    if (value % 1 == 0) return value.toInt().toString();
    return value.toStringAsFixed(2).replaceAll('.', ',');
  }

  double _parseCurrency(String text) {
    if (text.isEmpty) return 0.0;
    String cleaned = text
        .replaceAll(',', '.')
        .replaceAll(RegExp(r'[^0-9.]'), '');
    if (cleaned.split('.').length > 2) {
      final parts = cleaned.split('.');
      final decimal = parts.removeLast();
      cleaned = '${parts.join('')}.$decimal';
    }
    return double.tryParse(cleaned) ?? 0.0;
  }

  double _parseNumber(String text) {
    return safeDouble(text);
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.simpleCurrency(locale: 'pt_BR');
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final p = widget.product;
    final originalR = p.priceOriginalForPromotion;
    final originalW = p.priceOriginalForPromotionWholesale;

    final hasChanges =
        _isActiveRetail != p.promoEnabledRetail ||
        _isActiveWholesale != p.promoEnabledWholesale ||
        _typeRetail != p.resolvedPromotionType ||
        _typeWholesale != p.resolvedPromotionTypeWholesale ||
        (_typeRetail == 'percent' &&
            _parseNumber(_percentRetailCtrl.text) != p.promoPercentRetail) ||
        (_typeRetail == 'manual' &&
            _parseCurrency(_manualRetailCtrl.text) !=
                (p.pricePromotionRetail ?? 0)) ||
        (_typeWholesale == 'percent' &&
            _parseNumber(_percentWholesaleCtrl.text) !=
                p.promoPercentWholesale) ||
        (_typeWholesale == 'manual' &&
            _parseCurrency(_manualWholesaleCtrl.text) !=
                (p.pricePromotionWholesale ?? 0));

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(value: widget.selected, onChanged: widget.onSelect),
              const SizedBox(width: 8),
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: p.mainImage != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: _buildImage(p.mainImage!.uri),
                      )
                    : const Icon(Icons.image_not_supported, color: Colors.grey),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('Ref: ${p.ref}'),
                    if (p.promotionName != null)
                      Text('Promoção: ${p.promotionName}'),
                    if (p.promotionUpdatedAt != null)
                      Text(
                        'Alterado em: ${dateFormat.format(p.promotionUpdatedAt!)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                  ],
                ),
              ),
              Column(
                children: [
                  if (hasChanges)
                    IconButton(
                      icon: const Icon(Icons.check_circle, color: Colors.green),
                      tooltip: 'Salvar alterações',
                      onPressed: () {
                        final percR = _parseNumber(_percentRetailCtrl.text);
                        final manR = _parseCurrency(_manualRetailCtrl.text);
                        final percW = _parseNumber(_percentWholesaleCtrl.text);
                        final manW = _parseCurrency(_manualWholesaleCtrl.text);
                        final updated = p.copyWith(
                          promoEnabledRetail: _isActiveRetail,
                          promoPercentRetail: _typeRetail == 'percent'
                              ? percR
                              : 0,
                          priceOriginalRetail: originalR,
                          pricePromotionRetail: _typeRetail == 'manual'
                              ? manR
                              : null,
                          promotionType: _typeRetail,

                          promoEnabledWholesale: _isActiveWholesale,
                          promoPercentWholesale: _typeWholesale == 'percent'
                              ? percW
                              : 0,
                          priceOriginalWholesale: originalW,
                          pricePromotionWholesale: _typeWholesale == 'manual'
                              ? manW
                              : null,

                          promotionUpdatedAt: DateTime.now(),
                          updatedAt: DateTime.now(),
                        );
                        widget.onSave(updated);
                      },
                    ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    tooltip: 'Remover promoção',
                    onPressed: widget.onRemovePromotion,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 500;
              final retailBlock = _buildPricingBlock(
                context,
                currency,
                'VAREJO',
                originalR,
                _typeRetail,
                _percentRetailCtrl,
                _manualRetailCtrl,
                (v) => setState(() => _typeRetail = v),
                (_) => setState(() {}),
                (_) => setState(() {}),
                _isActiveRetail,
                (v) => setState(() => _isActiveRetail = v),
              );

              final wholesaleBlock = _buildPricingBlock(
                context,
                currency,
                'ATACADO',
                originalW,
                _typeWholesale,
                _percentWholesaleCtrl,
                _manualWholesaleCtrl,
                (v) => setState(() => _typeWholesale = v),
                (_) => setState(() {}),
                (_) => setState(() {}),
                _isActiveWholesale,
                (v) => setState(() => _isActiveWholesale = v),
              );

              if (isWide) {
                return Padding(
                  padding: const EdgeInsets.only(left: 48),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: retailBlock),
                      const SizedBox(width: 24),
                      Expanded(child: wholesaleBlock),
                    ],
                  ),
                );
              } else {
                return Padding(
                  padding: const EdgeInsets.only(left: 48),
                  child: Column(
                    children: [
                      retailBlock,
                      const SizedBox(height: 24),
                      wholesaleBlock,
                    ],
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPricingBlock(
    BuildContext context,
    NumberFormat currency,
    String title,
    double original,
    String type,
    TextEditingController percentController,
    TextEditingController priceController,
    ValueChanged<String> onTypeChanged,
    ValueChanged<String> onPercentChanged,
    ValueChanged<String> onPriceChanged,
    bool isActive,
    ValueChanged<bool> onActiveChanged,
  ) {
    double finalPricePreview = original;
    if (type == 'percent') {
      final perc = _parseNumber(percentController.text);
      if (perc > 0 && perc <= 100)
        finalPricePreview = original * (1 - (perc / 100));
    } else {
      final man = _parseCurrency(priceController.text);
      if (man > 0) finalPricePreview = man;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(12),
        color: isActive
            ? Colors.blue.shade50.withValues(alpha: 0.3)
            : Colors.transparent,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Switch(value: isActive, onChanged: onActiveChanged),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
              if (isActive && finalPricePreview < original)
                PromoBadge(
                  discountPercentage:
                      ((original - finalPricePreview) / original * 100)
                          .round()
                          .clamp(0, 100),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('De', style: Theme.of(context).textTheme.labelSmall),
                    Text(
                      currency.format(original),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        decoration: TextDecoration.lineThrough,
                        decorationColor: Color(0xFFF43F5E),
                        color: Color(0xFFF43F5E),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<String>(
                  value: type,
                  onChanged: isActive
                      ? (value) {
                          if (value != null) onTypeChanged(value);
                        }
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'Tipo',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'percent',
                      child: Text('Porcentagem'),
                    ),
                    DropdownMenuItem(value: 'manual', child: Text('Manual')),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: percentController,
                  enabled: isActive && type == 'percent',
                  textAlign: TextAlign.end,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
                  ],
                  onChanged: onPercentChanged,
                  decoration: const InputDecoration(
                    labelText: 'Desconto',
                    suffixText: '%',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: TextField(
                  controller: priceController,
                  enabled: isActive,
                  textAlign: TextAlign.end,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [CurrencyInputFormatter()],
                  onChanged: onPriceChanged,
                  decoration: const InputDecoration(
                    labelText: 'Por',
                    prefixText: 'R\$ ',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildImage(String uri) {
    if (uri.startsWith('http') || uri.startsWith('gs')) {
      return Image.network(
        uri,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Icon(Icons.error),
      );
    }
    return const Icon(Icons.image);
  }
}
