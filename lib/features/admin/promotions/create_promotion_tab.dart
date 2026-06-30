import 'package:catalogo_ja/models/category.dart';
import 'package:catalogo_ja/models/product.dart';
import 'package:catalogo_ja/core/utils/safe_parse.dart';
import 'package:catalogo_ja/ui/theme/app_tokens.dart';
import 'package:catalogo_ja/ui/widgets/app_empty_state.dart';
import 'package:catalogo_ja/ui/widgets/app_error_view.dart';
import 'package:catalogo_ja/ui/widgets/app_primary_button.dart';
import 'package:catalogo_ja/ui/widgets/section_card.dart';
import 'package:catalogo_ja/viewmodels/products_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

enum _PromotionApplyMode { percent, manual }

class CreatePromotionTab extends ConsumerStatefulWidget {
  const CreatePromotionTab({super.key});

  @override
  ConsumerState<CreatePromotionTab> createState() => _CreatePromotionTabState();
}

class _CreatePromotionTabState extends ConsumerState<CreatePromotionTab> {
  final _nameController = TextEditingController();
  final _percentController = TextEditingController(text: '20');
  final _manualValueController = TextEditingController();
  final Map<String, TextEditingController> _priceControllers = {};
  final Map<String, TextEditingController> _percentControllers = {};
  final Map<String, _PromotionApplyMode> _typeByProductId = {};

  String? _selectedGroupId;
  Set<String> _selectedProductIds = {};
  _PromotionApplyMode _mode = _PromotionApplyMode.percent;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _percentController.dispose();
    _manualValueController.dispose();
    for (final controller in _priceControllers.values) {
      controller.dispose();
    }
    for (final controller in _percentControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

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

    if (groups.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(AppTokens.space24),
        child: AppEmptyState(
          icon: Icons.local_offer_outlined,
          title: 'Nenhuma colecao ou categoria',
          subtitle:
              'Cadastre colecoes ou categorias antes de criar uma promocao.',
          message: '',
        ),
      );
    }

    if (_selectedGroupId != null &&
        !groups.any((group) => group.id == _selectedGroupId)) {
      _selectedGroupId = null;
      _selectedProductIds = {};
    }

    final productsInGroup = _productsForGroup(state, _selectedGroupId);
    _syncPriceControllers(productsInGroup);
    final selectedProducts = productsInGroup
        .where((product) => _selectedProductIds.contains(product.id))
        .toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;
        final setupPanel = _buildSetupPanel(
          state,
          groups,
          productsInGroup,
          selectedProducts,
        );
        final productsPanel = _buildProductsPanel(
          productsInGroup,
          selectedProducts,
        );
        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppTokens.space24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: isWide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 4, child: setupPanel),
                        const SizedBox(width: AppTokens.space24),
                        Expanded(flex: 6, child: productsPanel),
                      ],
                    )
                  : Column(
                      children: [
                        setupPanel,
                        const SizedBox(height: AppTokens.space24),
                        productsPanel,
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSetupPanel(
    ProductsState state,
    List<Category> groups,
    List<Product> productsInGroup,
    List<Product> selectedProducts,
  ) {
    return Column(
      children: [
        SectionCard(
          title: 'Nova promocao',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nome da promocao',
                  hintText: 'Ex.: Promocao Inverno 2026',
                  prefixIcon: Icon(Icons.sell_outlined),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selectedGroupId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Colecao, categoria ou grupo',
                  prefixIcon: Icon(Icons.collections_bookmark_outlined),
                ),
                items: groups
                    .map(
                      (group) => DropdownMenuItem(
                        value: group.id,
                        child: Text(
                          _groupLabel(group),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) => _selectGroup(state, value),
              ),
              const SizedBox(height: 16),
              SegmentedButton<_PromotionApplyMode>(
                segments: const [
                  ButtonSegment(
                    value: _PromotionApplyMode.percent,
                    icon: Icon(Icons.percent_rounded),
                    label: Text('Percentual'),
                  ),
                  ButtonSegment(
                    value: _PromotionApplyMode.manual,
                    icon: Icon(Icons.edit_outlined),
                    label: Text('Manual'),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: (selection) {
                  setState(() => _mode = selection.first);
                },
              ),
              const SizedBox(height: 16),
              if (_mode == _PromotionApplyMode.percent)
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _percentController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Desconto',
                          suffixText: '%',
                          prefixIcon: Icon(Icons.percent_rounded),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: productsInGroup.isEmpty
                          ? null
                          : () => _applyPercent(productsInGroup),
                      icon: const Icon(Icons.arrow_downward_rounded),
                      label: const Text('Aplicar'),
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _manualValueController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Preco promocional unico',
                          prefixText: 'R\$ ',
                          prefixIcon: Icon(Icons.payments_outlined),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: productsInGroup.isEmpty
                          ? null
                          : () => _applyManualValue(productsInGroup),
                      icon: const Icon(Icons.done_all_rounded),
                      label: const Text('Aplicar'),
                    ),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: AppTokens.space16),
        SectionCard(
          title: 'Resumo',
          child: Column(
            children: [
              _buildSummaryRow(
                'Produtos no grupo',
                '${productsInGroup.length}',
              ),
              _buildSummaryRow('Selecionados', '${_selectedProductIds.length}'),
              _buildSummaryRow(
                'Ja em promocao',
                '${productsInGroup.where((p) => p.promotionActive).length}',
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: selectedProducts.isEmpty || _isSaving
                          ? null
                          : () => _clearPromotion(selectedProducts),
                      icon: const Icon(Icons.local_offer_outlined),
                      label: const Text('Remover promocao'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              AppPrimaryButton(
                label: _isSaving ? 'SALVANDO...' : 'SALVAR PROMOCAO',
                icon: Icons.check_circle_outline,
                onPressed: _isSaving || selectedProducts.isEmpty
                    ? null
                    : () => _savePromotion(selectedProducts),
                color: null,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProductsPanel(
    List<Product> productsInGroup,
    List<Product> selectedProducts,
  ) {
    final allSelected =
        productsInGroup.isNotEmpty &&
        selectedProducts.length == productsInGroup.length;
    final partiallySelected = selectedProducts.isNotEmpty && !allSelected;

    return SectionCard(
      title: 'Produtos da colecao',
      child: Column(
        children: [
          Row(
            children: [
              Checkbox(
                value: partiallySelected ? null : allSelected,
                tristate: true,
                onChanged: productsInGroup.isEmpty
                    ? null
                    : (_) => _toggleSelectAll(productsInGroup, !allSelected),
              ),
              Expanded(
                child: Text(
                  productsInGroup.isEmpty
                      ? 'Selecione um grupo com produtos'
                      : '${selectedProducts.length} de ${productsInGroup.length} selecionados',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              TextButton.icon(
                onPressed: productsInGroup.isEmpty
                    ? null
                    : () => _toggleSelectAll(productsInGroup, true),
                icon: const Icon(Icons.select_all_rounded, size: 18),
                label: const Text('Todos'),
              ),
            ],
          ),
          const Divider(),
          if (productsInGroup.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: AppEmptyState(
                icon: Icons.inventory_2_outlined,
                title: 'Nenhum produto encontrado',
                subtitle: 'Escolha outra colecao ou categoria.',
                message: '',
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: productsInGroup.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final product = productsInGroup[index];
                return _PromotionProductRow(
                  product: product,
                  selected: _selectedProductIds.contains(product.id),
                  type:
                      _typeByProductId[product.id] ?? _modeFromProduct(product),
                  priceController: _priceControllers[product.id]!,
                  percentController: _percentControllers[product.id]!,
                  onSelectedChanged: (value) => _toggleProduct(product.id),
                  onTypeChanged: (value) => _setProductType(product, value),
                  onPercentChanged: (value) =>
                      _setProductPercent(product, value),
                  onPromotionPriceChanged: (_) => _setProductManual(product.id),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  void _selectGroup(ProductsState state, String? groupId) {
    final products = _productsForGroup(state, groupId);
    setState(() {
      _selectedGroupId = groupId;
      _selectedProductIds = products.map((product) => product.id).toSet();
      _resetPriceControllers(products);
    });
  }

  List<Product> _productsForGroup(ProductsState state, String? groupId) {
    if (groupId == null || groupId.trim().isEmpty) return const [];
    return state.allProducts
        .where((product) => product.categoryIds.contains(groupId))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  void _toggleSelectAll(List<Product> products, bool selected) {
    setState(() {
      _selectedProductIds = selected
          ? products.map((product) => product.id).toSet()
          : {};
    });
  }

  void _toggleProduct(String productId) {
    setState(() {
      if (_selectedProductIds.contains(productId)) {
        _selectedProductIds.remove(productId);
      } else {
        _selectedProductIds.add(productId);
      }
    });
  }

  void _applyPercent(List<Product> products) {
    final percent = _parseNumber(_percentController.text);
    if (percent < 0 || percent > 100) {
      _showSnack('Informe um percentual entre 0 e 100.');
      return;
    }

    setState(() {
      for (final product in products) {
        if (!_selectedProductIds.contains(product.id)) continue;
        _typeByProductId[product.id] = _PromotionApplyMode.percent;
        _percentControllers[product.id]?.text = _formatPercent(percent);
        _updatePercentPrice(product, percent);
      }
    });
  }

  void _applyManualValue(List<Product> products) {
    final value = _parseNumber(_manualValueController.text);
    if (value <= 0) {
      _showSnack('Informe um preco promocional maior que zero.');
      return;
    }

    setState(() {
      for (final product in products) {
        if (_selectedProductIds.contains(product.id)) {
          _typeByProductId[product.id] = _PromotionApplyMode.manual;
          _priceControllers[product.id]?.text = _formatEditingPrice(value);
        }
      }
    });
  }

  void _setProductType(Product product, _PromotionApplyMode type) {
    setState(() {
      _typeByProductId[product.id] = type;
      if (type == _PromotionApplyMode.percent) {
        var percent = _parseNumber(
          _percentControllers[product.id]?.text ?? _percentController.text,
        );
        if (percent <= 0) {
          percent = _parseNumber(_percentController.text);
          _percentControllers[product.id]?.text = _formatPercent(percent);
        }
        if (percent >= 0 && percent <= 100) {
          _updatePercentPrice(product, percent);
        }
      }
    });
  }

  void _setProductPercent(Product product, String value) {
    setState(() {
      _typeByProductId[product.id] = _PromotionApplyMode.percent;
      final percent = _parseNumber(value);
      if (percent >= 0 && percent <= 100) {
        _updatePercentPrice(product, percent);
      }
    });
  }

  void _setProductManual(String productId) {
    if (_typeByProductId[productId] == _PromotionApplyMode.manual) return;
    setState(() {
      _typeByProductId[productId] = _PromotionApplyMode.manual;
    });
  }

  void _updatePercentPrice(Product product, double percent) {
    final original = product.priceOriginal ?? product.priceRetail;
    final value = original * (1 - (percent / 100));
    _priceControllers[product.id]?.text = _formatEditingPrice(value);
  }

  Future<void> _savePromotion(List<Product> selectedProducts) async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showSnack('Informe o nome da promocao.');
      return;
    }

    final invalidProducts = <String>[];
    final invalidPercentProducts = <String>[];
    final moreExpensiveProducts = <String>[];
    for (final product in selectedProducts) {
      final promoPrice = _parseNumber(
        _priceControllers[product.id]?.text ?? '',
      );
      final original = product.priceOriginal ?? product.priceRetail;
      final type = _typeByProductId[product.id] ?? _modeFromProduct(product);
      final percent = _parseNumber(_percentControllers[product.id]?.text ?? '');
      if (promoPrice <= 0) {
        invalidProducts.add(product.name);
      } else if (type == _PromotionApplyMode.percent &&
          (percent < 0 || percent > 100)) {
        invalidPercentProducts.add(product.name);
      } else if (original > 0 && promoPrice > original) {
        moreExpensiveProducts.add(product.name);
      }
    }

    if (invalidProducts.isNotEmpty) {
      _showSnack('Revise produtos com preco promocional zerado.');
      return;
    }

    if (invalidPercentProducts.isNotEmpty) {
      _showSnack('Revise os percentuais entre 0 e 100.');
      return;
    }

    if (moreExpensiveProducts.isNotEmpty) {
      final confirmed = await _confirmHigherPrices(moreExpensiveProducts);
      if (!confirmed) return;
    }

    setState(() => _isSaving = true);
    try {
      final now = DateTime.now();
      final promotionId = const Uuid().v4();
      final updates = selectedProducts.map((product) {
        final original = product.priceOriginal ?? product.priceRetail;
        final promoPrice = _parseNumber(
          _priceControllers[product.id]?.text ?? '',
        );
        final type = _typeByProductId[product.id] ?? _modeFromProduct(product);
        final percent = type == _PromotionApplyMode.percent
            ? _parseNumber(_percentControllers[product.id]?.text ?? '')
            : 0.0;
        return product.copyWith(
          promoEnabled: true,
          promoPercent: percent,
          priceOriginal: original,
          pricePromotion: promoPrice,
          promotionName: name,
          promotionCollectionId: _selectedGroupId,
          promotionType: _promotionTypeValue(type),
          promotionId: promotionId,
          promotionCreatedAt: now,
          promotionUpdatedAt: now,
          updatedAt: now,
        );
      }).toList();

      await ref
          .read(productsViewModelProvider.notifier)
          .updateProductsBulk(updates);
      if (!mounted) return;
      _showSnack('Promocao salva em ${updates.length} produto(s).');
    } catch (error) {
      if (mounted) _showSnack('Erro ao salvar promocao: $error');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _clearPromotion(List<Product> selectedProducts) async {
    setState(() => _isSaving = true);
    try {
      final now = DateTime.now();
      final updates = selectedProducts
          .map(
            (product) => product.copyWith(
              promoEnabled: false,
              promoPercent: 0,
              updatedAt: now,
              clearPriceOriginal: true,
              clearPricePromotion: true,
              clearPromotionName: true,
              clearPromotionCollectionId: true,
              clearPromotionCreatedAt: true,
              clearPromotionUpdatedAt: true,
              clearPromotionType: true,
              clearPromotionId: true,
            ),
          )
          .toList();
      await ref
          .read(productsViewModelProvider.notifier)
          .updateProductsBulk(updates);
      if (!mounted) return;
      _resetPriceControllers(updates);
      _showSnack('Promocao removida dos produtos selecionados.');
    } catch (error) {
      if (mounted) _showSnack('Erro ao remover promocao: $error');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<bool> _confirmHigherPrices(List<String> productNames) async {
    final preview = productNames.take(3).join(', ');
    final suffix = productNames.length > 3 ? '...' : '';
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Preco maior que o original'),
        content: Text(
          'Alguns precos promocionais ficaram maiores que o original: '
          '$preview$suffix. Deseja salvar mesmo assim?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Revisar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Salvar mesmo assim'),
          ),
        ],
      ),
    );
    return result == true;
  }

  void _syncPriceControllers(List<Product> products) {
    final ids = products.map((product) => product.id).toSet();
    final staleIds = _priceControllers.keys
        .where((id) => !ids.contains(id))
        .toList(growable: false);
    for (final id in staleIds) {
      _priceControllers.remove(id)?.dispose();
      _percentControllers.remove(id)?.dispose();
      _typeByProductId.remove(id);
    }

    for (final product in products) {
      _priceControllers.putIfAbsent(
        product.id,
        () => TextEditingController(
          text: _formatEditingPrice(
            product.promotionActive
                ? product.promotionPriceRetail
                : product.priceRetail,
          ),
        ),
      );
      _percentControllers.putIfAbsent(
        product.id,
        () => TextEditingController(
          text: _formatPercent(
            product.promotionActive && product.promoPercent > 0
                ? product.promoPercent
                : _parseNumber(_percentController.text),
          ),
        ),
      );
      _typeByProductId.putIfAbsent(
        product.id,
        () => product.promotionActive ? _modeFromProduct(product) : _mode,
      );
    }
  }

  void _resetPriceControllers(List<Product> products) {
    for (final controller in _priceControllers.values) {
      controller.dispose();
    }
    for (final controller in _percentControllers.values) {
      controller.dispose();
    }
    _priceControllers.clear();
    _percentControllers.clear();
    _typeByProductId.clear();
    for (final product in products) {
      _priceControllers[product.id] = TextEditingController(
        text: _formatEditingPrice(
          product.promotionActive
              ? product.promotionPriceRetail
              : product.priceRetail,
        ),
      );
      _percentControllers[product.id] = TextEditingController(
        text: _formatPercent(
          product.promotionActive && product.promoPercent > 0
              ? product.promoPercent
              : _parseNumber(_percentController.text),
        ),
      );
      _typeByProductId[product.id] = product.promotionActive
          ? _modeFromProduct(product)
          : _mode;
    }
  }

  double _parseNumber(String text) {
    return safeDouble(text);
  }

  String _formatEditingPrice(double value) {
    return value.toStringAsFixed(2).replaceAll('.', ',');
  }

  String _formatPercent(double value) {
    if (value % 1 == 0) return value.toInt().toString();
    return value.toStringAsFixed(2).replaceAll('.', ',');
  }

  _PromotionApplyMode _modeFromProduct(Product product) {
    return product.resolvedPromotionType == 'manual'
        ? _PromotionApplyMode.manual
        : _PromotionApplyMode.percent;
  }

  String _promotionTypeValue(_PromotionApplyMode type) {
    return type == _PromotionApplyMode.manual ? 'manual' : 'percent';
  }

  String _groupLabel(Category category) {
    final prefix = category.type == CategoryType.collection
        ? 'Colecao'
        : 'Categoria';
    return '$prefix - ${category.safeName}';
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _PromotionProductRow extends StatelessWidget {
  const _PromotionProductRow({
    required this.product,
    required this.selected,
    required this.type,
    required this.priceController,
    required this.percentController,
    required this.onSelectedChanged,
    required this.onTypeChanged,
    required this.onPercentChanged,
    required this.onPromotionPriceChanged,
  });

  final Product product;
  final bool selected;
  final _PromotionApplyMode type;
  final TextEditingController priceController;
  final TextEditingController percentController;
  final ValueChanged<bool> onSelectedChanged;
  final ValueChanged<_PromotionApplyMode> onTypeChanged;
  final ValueChanged<String> onPercentChanged;
  final ValueChanged<String> onPromotionPriceChanged;

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.simpleCurrency(locale: 'pt_BR');
    final original = product.priceOriginal ?? product.priceRetail;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Checkbox(
                value: selected,
                onChanged: (value) => onSelectedChanged(value == true),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 3),
                    Wrap(
                      spacing: 10,
                      runSpacing: 4,
                      children: [
                        Text(
                          product.ref.isEmpty ? 'Sem referencia' : product.ref,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (product.promotionActive)
                          Text(
                            product.promotionName ?? 'Em promocao',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: AppTokens.vibrantPink,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(left: 48),
            child: Wrap(
              spacing: 12,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 116,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Original',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      Text(
                        currency.format(original),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 152,
                  child: DropdownButtonFormField<_PromotionApplyMode>(
                    value: type,
                    onChanged: selected
                        ? (value) {
                            if (value != null) onTypeChanged(value);
                          }
                        : null,
                    decoration: const InputDecoration(
                      labelText: 'Tipo',
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: _PromotionApplyMode.percent,
                        child: Text('Porcentagem'),
                      ),
                      DropdownMenuItem(
                        value: _PromotionApplyMode.manual,
                        child: Text('Manual'),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 112,
                  child: TextField(
                    controller: percentController,
                    enabled: selected && type == _PromotionApplyMode.percent,
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
                    ),
                  ),
                ),
                SizedBox(
                  width: 136,
                  child: TextField(
                    controller: priceController,
                    enabled: selected,
                    textAlign: TextAlign.end,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
                    ],
                    onChanged: onPromotionPriceChanged,
                    decoration: const InputDecoration(
                      labelText: 'Promo',
                      prefixText: 'R\$ ',
                      isDense: true,
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
}
