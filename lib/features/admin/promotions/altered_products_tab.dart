import 'package:catalogo_ja/models/category.dart';
import 'package:catalogo_ja/models/product.dart';
import 'package:catalogo_ja/core/utils/safe_parse.dart';
import 'package:catalogo_ja/ui/theme/app_tokens.dart';
import 'package:catalogo_ja/ui/widgets/app_empty_state.dart';
import 'package:catalogo_ja/ui/widgets/app_error_view.dart';
import 'package:catalogo_ja/ui/widgets/section_card.dart';
import 'package:catalogo_ja/viewmodels/products_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

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
    final groups = state.categories
        .where((category) => category.type == CategoryType.collection || category.type == CategoryType.productType)
        .toList()..sort((a, b) => a.safeName.compareTo(b.safeName));

    final alteredProducts = state.allProducts.where((p) => 
        p.promotionActive || p.pricePromotion != null || p.promotionPercent > 0 || p.promotionId != null
    ).toList();

    // KPIs
    int totalPromotions = alteredProducts.length;
    int activePromotions = alteredProducts.where((p) => p.promotionActive).length;
    int percentPromotions = alteredProducts.where((p) => p.resolvedPromotionType == 'percent').length;
    int manualPromotions = alteredProducts.where((p) => p.resolvedPromotionType == 'manual').length;

    // Filters
    final q = _searchQuery.trim().toLowerCase();
    var filtered = alteredProducts;
    if (q.isNotEmpty) {
      filtered = filtered.where((p) => 
        p.name.toLowerCase().contains(q) || 
        p.ref.toLowerCase().contains(q) ||
        (p.promotionName?.toLowerCase().contains(q) ?? false)
      ).toList();
    }
    if (_selectedCollectionId != null) {
      filtered = filtered.where((p) => p.categoryIds.contains(_selectedCollectionId)).toList();
    }
    if (_selectedPromotionType != null) {
      filtered = filtered.where((p) => p.resolvedPromotionType == _selectedPromotionType).toList();
    }
    if (_isActiveFilter != null) {
      filtered = filtered.where((p) => p.promotionActive == _isActiveFilter).toList();
    }

    filtered.sort((a, b) => (b.promotionUpdatedAt ?? b.updatedAt).compareTo(a.promotionUpdatedAt ?? a.updatedAt));

    return Column(
      children: [
        _buildKPIs(totalPromotions, activePromotions, percentPromotions, manualPromotions),
        const SizedBox(height: 16),
        _buildFilters(groups),
        const SizedBox(height: 16),
        Expanded(child: _buildList(filtered)),
      ],
    );
  }

  Widget _buildKPIs(int total, int active, int percent, int manual) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTokens.space24, vertical: 8),
      child: Row(
        children: [
          _kpiCard('Produtos Alterados', total.toString()),
          const SizedBox(width: 8),
          _kpiCard('Promoções Ativas', active.toString()),
          const SizedBox(width: 8),
          _kpiCard('Por Porcentagem', percent.toString()),
          const SizedBox(width: 8),
          _kpiCard('Manuais', manual.toString()),
        ],
      ),
    );
  }

  Widget _kpiCard(String title, String value) {
    return Expanded(
      child: SectionCard(
        child: Column(
          children: [
            Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            Text(title, style: const TextStyle(fontSize: 12), textAlign: TextAlign.center),
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
              decoration: const InputDecoration(labelText: 'Coleção', isDense: true),
              items: [
                const DropdownMenuItem(value: null, child: Text('Todas')),
                ...groups.map((g) => DropdownMenuItem(value: g.id, child: Text(g.safeName))),
              ],
              onChanged: (v) => setState(() => _selectedCollectionId = v),
            ),
          ),
          SizedBox(
            width: 150,
            child: DropdownButtonFormField<String?>(
              value: _selectedPromotionType,
              decoration: const InputDecoration(labelText: 'Tipo', isDense: true),
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
              decoration: const InputDecoration(labelText: 'Status', isDense: true),
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

    final allSelected = products.isNotEmpty && _selectedProductIds.length == products.length;
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
                  onPressed: _isSaving ? null : () => _clearPromotionBatch(products),
                  icon: const Icon(Icons.delete_sweep),
                  label: Text('Remover promoção (${_selectedProductIds.length})'),
                  style: FilledButton.styleFrom(backgroundColor: Colors.red),
                ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(AppTokens.space24),
            itemCount: products.length,
            separatorBuilder: (_, _) => const Divider(),
            itemBuilder: (context, index) {
              final p = products[index];
              return _AlteredProductRow(
                key: ValueKey(p.id),
                product: p,
                selected: _selectedProductIds.contains(p.id),
                onSelect: (val) {
                  setState(() {
                    if (val == true) _selectedProductIds.add(p.id);
                    else _selectedProductIds.remove(p.id);
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
      await ref.read(productsViewModelProvider.notifier).updateProductsBulk([product]);
      if (mounted) _showSnack('Produto atualizado com sucesso.');
    } catch (e) {
      if (mounted) _showSnack('Erro ao salvar: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _clearPromotion(Product p) async {
    final updated = p.copyWith(
      promoEnabled: false,
      promoPercent: 0,
      updatedAt: DateTime.now(),
      clearPriceOriginal: true,
      clearPricePromotion: true,
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
    final toUpdate = products.where((p) => _selectedProductIds.contains(p.id)).map((p) => 
      p.copyWith(
        promoEnabled: false,
        promoPercent: 0,
        updatedAt: DateTime.now(),
        clearPriceOriginal: true,
        clearPricePromotion: true,
        clearPromotionName: true,
        clearPromotionCollectionId: true,
        clearPromotionCreatedAt: true,
        clearPromotionUpdatedAt: true,
        clearPromotionType: true,
        clearPromotionId: true,
      )
    ).toList();

    setState(() => _isSaving = true);
    try {
      await ref.read(productsViewModelProvider.notifier).updateProductsBulk(toUpdate);
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
  late TextEditingController _percentCtrl;
  late TextEditingController _manualCtrl;
  late bool _isActive;
  late String _type;

  @override
  void initState() {
    super.initState();
    _initValues();
  }

  void _initValues() {
    _isActive = widget.product.promotionActive;
    _type = widget.product.resolvedPromotionType;
    _percentCtrl = TextEditingController(text: widget.product.promoPercent > 0 ? _formatEditingValue(widget.product.promoPercent) : '');
    final pPrice = widget.product.pricePromotion ?? 0;
    _manualCtrl = TextEditingController(text: pPrice > 0 ? _formatEditingValue(pPrice) : '');
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
    _percentCtrl.dispose();
    _manualCtrl.dispose();
    super.dispose();
  }

  String _formatEditingValue(double value) {
    if (value % 1 == 0) return value.toInt().toString();
    return value.toStringAsFixed(2).replaceAll('.', ',');
  }

  double _parseNumber(String text) {
    return safeDouble(text);
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.simpleCurrency(locale: 'pt_BR');
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final p = widget.product;
    final original = p.priceOriginal ?? p.priceRetail;

    // Calculate preview
    double finalPricePreview = original;
    if (_type == 'percent') {
      final perc = _parseNumber(_percentCtrl.text);
      if (perc > 0 && perc <= 100) {
        finalPricePreview = original * (1 - (perc / 100));
      }
    } else {
      final man = _parseNumber(_manualCtrl.text);
      if (man > 0) {
        finalPricePreview = man;
      }
    }

    final hasChanges = _isActive != p.promotionActive || 
                       _type != p.resolvedPromotionType ||
                       (_type == 'percent' && _parseNumber(_percentCtrl.text) != p.promoPercent) ||
                       (_type == 'manual' && _parseNumber(_manualCtrl.text) != (p.pricePromotion ?? 0));

    return Row(
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
              ? ClipRRect(borderRadius: BorderRadius.circular(8), child: _buildImage(p.mainImage!.uri))
              : const Icon(Icons.image_not_supported, color: Colors.grey),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('Ref: ${p.ref}'),
              Text('Promoção: ${p.promotionName ?? '-'}'),
              if (p.promotionUpdatedAt != null)
                Text('Alterado em: ${dateFormat.format(p.promotionUpdatedAt!)}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
        Expanded(
          flex: 3,
          child: Row(
            children: [
              Switch(
                value: _isActive,
                onChanged: (v) => setState(() => _isActive = v),
              ),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _type,
                items: const [
                  DropdownMenuItem(value: 'percent', child: Text('%')),
                  DropdownMenuItem(value: 'manual', child: Text('R\$')),
                ],
                onChanged: (v) => setState(() {
                  if (v != null) _type = v;
                }),
              ),
              const SizedBox(width: 8),
              if (_type == 'percent')
                SizedBox(
                  width: 80,
                  child: TextField(
                    controller: _percentCtrl,
                    decoration: const InputDecoration(isDense: true, suffixText: '%'),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]'))],
                    onChanged: (_) => setState((){}),
                  ),
                )
              else
                SizedBox(
                  width: 100,
                  child: TextField(
                    controller: _manualCtrl,
                    decoration: const InputDecoration(isDense: true, prefixText: 'R\$ '),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]'))],
                    onChanged: (_) => setState((){}),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          flex: 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(currency.format(original), style: const TextStyle(decoration: TextDecoration.lineThrough, color: Colors.grey, fontSize: 12)),
              Text(currency.format(finalPricePreview), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Column(
          children: [
            if (hasChanges)
              IconButton(
                icon: const Icon(Icons.check_circle, color: Colors.green),
                tooltip: 'Salvar alterações',
                onPressed: () {
                  final perc = _parseNumber(_percentCtrl.text);
                  final man = _parseNumber(_manualCtrl.text);
                  final updated = p.copyWith(
                    promoEnabled: _isActive,
                    promoPercent: _type == 'percent' ? perc : 0,
                    priceOriginal: original,
                    pricePromotion: _type == 'manual' ? man : null,
                    promotionType: _type,
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
        )
      ],
    );
  }

  Widget _buildImage(String uri) {
    if (uri.startsWith('http') || uri.startsWith('gs')) {
      return Image.network(uri, fit: BoxFit.cover, errorBuilder: (_,__,___) => const Icon(Icons.error));
    }
    return const Icon(Icons.image);
  }
}
