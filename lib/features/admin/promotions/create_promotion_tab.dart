import 'package:catalogo_ja/models/category.dart';
import 'package:catalogo_ja/models/product.dart';
import 'package:catalogo_ja/core/utils/safe_parse.dart';
import 'package:catalogo_ja/ui/theme/app_tokens.dart';
import 'package:catalogo_ja/ui/widgets/app_empty_state.dart';
import 'package:catalogo_ja/ui/widgets/app_error_view.dart';
import 'package:catalogo_ja/ui/widgets/app_primary_button.dart';
import 'package:catalogo_ja/ui/widgets/section_card.dart';
import 'package:catalogo_ja/ui/widgets/promo_badge.dart';
import 'package:catalogo_ja/viewmodels/products_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:catalogo_ja/core/utils/currency_formatter.dart';

enum _PromotionApplyMode { percent, manual }

class CreatePromotionTab extends ConsumerStatefulWidget {
  const CreatePromotionTab({super.key});

  @override
  ConsumerState<CreatePromotionTab> createState() => _CreatePromotionTabState();
}

class _CreatePromotionTabState extends ConsumerState<CreatePromotionTab> {
  final _nameController = TextEditingController();
  
  final _percentRetailController = TextEditingController(text: '20');
  final _manualValueRetailController = TextEditingController();
  final _percentWholesaleController = TextEditingController(text: '20');
  final _manualValueWholesaleController = TextEditingController();
  
  final Map<String, TextEditingController> _priceRetailControllers = {};
  final Map<String, TextEditingController> _percentRetailControllers = {};
  final Map<String, _PromotionApplyMode> _typeRetailByProductId = {};

  final Map<String, TextEditingController> _priceWholesaleControllers = {};
  final Map<String, TextEditingController> _percentWholesaleControllers = {};
  final Map<String, _PromotionApplyMode> _typeWholesaleByProductId = {};

  String? _selectedGroupId;
  Set<String> _selectedProductIds = {};
  _PromotionApplyMode _mode = _PromotionApplyMode.percent;
  bool _isSaving = false;
  bool _applyToRetail = true;
  bool _applyToWholesale = true;

  @override
  void dispose() {
    _nameController.dispose();
    _percentRetailController.dispose();
    _manualValueRetailController.dispose();
    _percentWholesaleController.dispose();
    _manualValueWholesaleController.dispose();
    for (final c in _priceRetailControllers.values) c.dispose();
    for (final c in _priceWholesaleControllers.values) c.dispose();
    for (final c in _percentRetailControllers.values) c.dispose();
    for (final c in _percentWholesaleControllers.values) c.dispose();
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
              Row(
                children: [
                  Expanded(
                    child: CheckboxListTile(
                      title: const Text('Aplicar Varejo'),
                      value: _applyToRetail,
                      onChanged: (v) => setState(() => _applyToRetail = v == true),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  ),
                  Expanded(
                    child: CheckboxListTile(
                      title: const Text('Aplicar Atacado'),
                      value: _applyToWholesale,
                      onChanged: (v) => setState(() => _applyToWholesale = v == true),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  ),
                ],
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
                Column(
                  children: [
                    if (_applyToRetail)
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _percentRetailController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]'))],
                              decoration: const InputDecoration(labelText: 'Desconto Varejo', suffixText: '%', prefixIcon: Icon(Icons.storefront)),
                            ),
                          ),
                        ],
                      ),
                    if (_applyToRetail && _applyToWholesale) const SizedBox(height: 12),
                    if (_applyToWholesale)
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _percentWholesaleController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]'))],
                              decoration: const InputDecoration(labelText: 'Desconto Atacado', suffixText: '%', prefixIcon: Icon(Icons.inventory_2)),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: productsInGroup.isEmpty || (!_applyToRetail && !_applyToWholesale) ? null : () => _applyPercent(productsInGroup),
                        icon: const Icon(Icons.arrow_downward_rounded),
                        label: const Text('Aplicar Lote'),
                      ),
                    ),
                  ],
                )
              else
                Column(
                  children: [
                    if (_applyToRetail)
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _manualValueRetailController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [CurrencyInputFormatter()],
                              decoration: const InputDecoration(labelText: 'Preco Promocional Varejo', prefixText: 'R\$ ', prefixIcon: Icon(Icons.storefront)),
                            ),
                          ),
                        ],
                      ),
                    if (_applyToRetail && _applyToWholesale) const SizedBox(height: 12),
                    if (_applyToWholesale)
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _manualValueWholesaleController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [CurrencyInputFormatter()],
                              decoration: const InputDecoration(labelText: 'Preco Promocional Atacado', prefixText: 'R\$ ', prefixIcon: Icon(Icons.inventory_2)),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: productsInGroup.isEmpty || (!_applyToRetail && !_applyToWholesale) ? null : () => _applyManualValue(productsInGroup),
                        icon: const Icon(Icons.done_all_rounded),
                        label: const Text('Aplicar Lote'),
                      ),
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
              _buildSummaryRow('Produtos no grupo', '${productsInGroup.length}'),
              _buildSummaryRow('Selecionados', '${_selectedProductIds.length}'),
              _buildSummaryRow('Ja em promocao (V)', '${productsInGroup.where((p) => p.promoEnabledRetail).length}'),
              _buildSummaryRow('Ja em promocao (A)', '${productsInGroup.where((p) => p.promoEnabledWholesale).length}'),
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
                  typeRetail: _typeRetailByProductId[product.id] ?? _modeFromProduct(product, true),
                  typeWholesale: _typeWholesaleByProductId[product.id] ?? _modeFromProduct(product, false),
                  priceRetailController: _priceRetailControllers[product.id]!,
                  percentRetailController: _percentRetailControllers[product.id]!,
                  priceWholesaleController: _priceWholesaleControllers[product.id]!,
                  percentWholesaleController: _percentWholesaleControllers[product.id]!,
                  onSelectedChanged: (value) => _toggleProduct(product.id),
                  onTypeRetailChanged: (value) => _setProductType(product, true, value),
                  onTypeWholesaleChanged: (value) => _setProductType(product, false, value),
                  onPercentRetailChanged: (value) => _setProductPercent(product, true, value),
                  onPercentWholesaleChanged: (value) => _setProductPercent(product, false, value),
                  onPromotionPriceRetailChanged: (_) => _setProductManual(product.id, true),
                  onPromotionPriceWholesaleChanged: (_) => _setProductManual(product.id, false),
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
    if (_applyToRetail) {
      final percentR = _parseNumber(_percentRetailController.text);
      if (percentR < 0 || percentR > 100) {
        _showSnack('Varejo: Informe um percentual entre 0 e 100.');
        return;
      }
    }
    if (_applyToWholesale) {
      final percentW = _parseNumber(_percentWholesaleController.text);
      if (percentW < 0 || percentW > 100) {
        _showSnack('Atacado: Informe um percentual entre 0 e 100.');
        return;
      }
    }

    setState(() {
      for (final product in products) {
        if (!_selectedProductIds.contains(product.id)) continue;
        if (_applyToRetail) {
          final percent = _parseNumber(_percentRetailController.text);
          _typeRetailByProductId[product.id] = _PromotionApplyMode.percent;
          _percentRetailControllers[product.id]?.text = _formatPercent(percent);
          _updatePercentPrice(product, true, percent);
        }
        if (_applyToWholesale) {
          final percent = _parseNumber(_percentWholesaleController.text);
          _typeWholesaleByProductId[product.id] = _PromotionApplyMode.percent;
          _percentWholesaleControllers[product.id]?.text = _formatPercent(percent);
          _updatePercentPrice(product, false, percent);
        }
      }
    });
  }

  void _applyManualValue(List<Product> products) {
    if (_applyToRetail) {
      final valueR = _parseCurrency(_manualValueRetailController.text);
      if (valueR <= 0) {
        _showSnack('Varejo: Informe um preco promocional maior que zero.');
        return;
      }
    }
    if (_applyToWholesale) {
      final valueW = _parseCurrency(_manualValueWholesaleController.text);
      if (valueW <= 0) {
        _showSnack('Atacado: Informe um preco promocional maior que zero.');
        return;
      }
    }

    setState(() {
      for (final product in products) {
        if (!_selectedProductIds.contains(product.id)) continue;
        if (_applyToRetail) {
          final value = _parseCurrency(_manualValueRetailController.text);
          _typeRetailByProductId[product.id] = _PromotionApplyMode.manual;
          _priceRetailControllers[product.id]?.text = _formatCurrency(value);
        }
        if (_applyToWholesale) {
          final value = _parseCurrency(_manualValueWholesaleController.text);
          _typeWholesaleByProductId[product.id] = _PromotionApplyMode.manual;
          _priceWholesaleControllers[product.id]?.text = _formatCurrency(value);
        }
      }
    });
  }

  void _setProductType(Product product, bool isRetail, _PromotionApplyMode type) {
    setState(() {
      if (isRetail) {
        _typeRetailByProductId[product.id] = type;
        var discount = _parseNumber(_percentRetailControllers[product.id]?.text ?? _percentRetailController.text);
        if (discount <= 0 && type == _PromotionApplyMode.percent) {
          discount = _parseNumber(_percentRetailController.text);
          _percentRetailControllers[product.id]?.text = _formatPercent(discount);
        }
        if (discount >= 0) _updatePercentPrice(product, true, discount);
      } else {
        _typeWholesaleByProductId[product.id] = type;
        var discount = _parseNumber(_percentWholesaleControllers[product.id]?.text ?? _percentWholesaleController.text);
        if (discount <= 0 && type == _PromotionApplyMode.percent) {
          discount = _parseNumber(_percentWholesaleController.text);
          _percentWholesaleControllers[product.id]?.text = _formatPercent(discount);
        }
        if (discount >= 0) _updatePercentPrice(product, false, discount);
      }
    });
  }

  void _setProductPercent(Product product, bool isRetail, String value) {
    setState(() {
      final percent = _parseNumber(value);
      if (isRetail) {
        _updatePercentPrice(product, true, percent);
      } else {
        _updatePercentPrice(product, false, percent);
      }
    });
  }

  double _calculatePromotionalPrice({
    required double originalPrice,
    required double discountValue,
    required _PromotionApplyMode type,
  }) {
    if (originalPrice <= 0) return 0;
    if (type == _PromotionApplyMode.percent) {
      final percent = discountValue.clamp(0, 100);
      return originalPrice * (1 - (percent / 100));
    }
    if (type == _PromotionApplyMode.manual) {
      final result = originalPrice - discountValue;
      return result < 0 ? 0 : result;
    }
    return originalPrice;
  }

  void _setProductManual(String productId, bool isRetail) {
    if (isRetail) {
      if (_typeRetailByProductId[productId] == _PromotionApplyMode.manual) return;
      setState(() => _typeRetailByProductId[productId] = _PromotionApplyMode.manual);
    } else {
      if (_typeWholesaleByProductId[productId] == _PromotionApplyMode.manual) return;
      setState(() => _typeWholesaleByProductId[productId] = _PromotionApplyMode.manual);
    }
  }

  void _updatePercentPrice(Product product, bool isRetail, double discount) {
    if (isRetail) {
      final original = product.priceOriginalForPromotion;
      final type = _typeRetailByProductId[product.id] ?? _PromotionApplyMode.percent;
      final value = _calculatePromotionalPrice(
        originalPrice: original,
        discountValue: discount,
        type: type,
      );
      _priceRetailControllers[product.id]?.text = _formatCurrency(value).replaceAll('R\$ ', '');
    } else {
      final original = product.priceOriginalForPromotionWholesale;
      final type = _typeWholesaleByProductId[product.id] ?? _PromotionApplyMode.percent;
      final value = _calculatePromotionalPrice(
        originalPrice: original,
        discountValue: discount,
        type: type,
      );
      _priceWholesaleControllers[product.id]?.text = _formatCurrency(value).replaceAll('R\$ ', '');
    }
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
      // VAREJO
      if (_applyToRetail) {
        final promoPrice = _parseCurrency(_priceRetailControllers[product.id]?.text ?? '');
        final original = product.priceOriginalForPromotion;
        final type = _typeRetailByProductId[product.id] ?? _modeFromProduct(product, true);
        final percent = _parseNumber(_percentRetailControllers[product.id]?.text ?? '');
        
        if (promoPrice <= 0) invalidProducts.add('${product.name} (Varejo)');
        else if (type == _PromotionApplyMode.percent && (percent < 0 || percent > 100)) invalidPercentProducts.add('${product.name} (Varejo)');
        else if (original > 0 && promoPrice > original) moreExpensiveProducts.add('${product.name} (Varejo)');
      }
      
      // ATACADO
      if (_applyToWholesale) {
        final promoPrice = _parseCurrency(_priceWholesaleControllers[product.id]?.text ?? '');
        final original = product.priceOriginalForPromotionWholesale;
        final type = _typeWholesaleByProductId[product.id] ?? _modeFromProduct(product, false);
        final percent = _parseNumber(_percentWholesaleControllers[product.id]?.text ?? '');
        
        if (promoPrice <= 0) invalidProducts.add('${product.name} (Atacado)');
        else if (type == _PromotionApplyMode.percent && (percent < 0 || percent > 100)) invalidPercentProducts.add('${product.name} (Atacado)');
        else if (original > 0 && promoPrice > original) moreExpensiveProducts.add('${product.name} (Atacado)');
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
        var p = product.copyWith(
          promotionName: name,
          promotionCollectionId: _selectedGroupId,
          promotionId: promotionId,
          promotionCreatedAt: now,
          promotionUpdatedAt: now,
          updatedAt: now,
        );
        
        if (_applyToRetail) {
          final original = product.priceOriginalForPromotion;
          final promoPrice = _parseCurrency(_priceRetailControllers[product.id]?.text ?? '');
          final type = _typeRetailByProductId[product.id] ?? _modeFromProduct(product, true);
          final percent = type == _PromotionApplyMode.percent ? _parseNumber(_percentRetailControllers[product.id]?.text ?? '') : 0.0;
          p = p.copyWith(
            promoEnabledRetail: true,
            promoPercentRetail: percent,
            priceOriginalRetail: original,
            pricePromotionRetail: promoPrice,
            promotionType: _promotionTypeValue(type),
          );
        }
        
        if (_applyToWholesale) {
          final original = product.priceOriginalForPromotionWholesale;
          final promoPrice = _parseCurrency(_priceWholesaleControllers[product.id]?.text ?? '');
          final type = _typeWholesaleByProductId[product.id] ?? _modeFromProduct(product, false);
          final percent = type == _PromotionApplyMode.percent ? _parseNumber(_percentWholesaleControllers[product.id]?.text ?? '') : 0.0;
          p = p.copyWith(
            promoEnabledWholesale: true,
            promoPercentWholesale: percent,
            priceOriginalWholesale: original,
            pricePromotionWholesale: promoPrice,
          );
        }
        return p;
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
          .map((product) {
            var p = product.copyWith(
              updatedAt: now,
              clearPromotionName: true,
              clearPromotionCollectionId: true,
              clearPromotionCreatedAt: true,
              clearPromotionUpdatedAt: true,
              clearPromotionType: true,
              clearPromotionId: true,
            );
            if (_applyToRetail) {
              p = p.copyWith(
                promoEnabledRetail: false,
                promoPercentRetail: 0,
                clearPriceOriginalRetail: true,
                clearPricePromotionRetail: true,
              );
            }
            if (_applyToWholesale) {
              p = p.copyWith(
                promoEnabledWholesale: false,
                promoPercentWholesale: 0,
                clearPriceOriginalWholesale: true,
                clearPricePromotionWholesale: true,
              );
            }
            return p;
          })
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
    final staleIds = _priceRetailControllers.keys
        .where((id) => !ids.contains(id))
        .toList(growable: false);
    for (final id in staleIds) {
      _priceRetailControllers.remove(id)?.dispose();
      _percentRetailControllers.remove(id)?.dispose();
      _typeRetailByProductId.remove(id);
      
      _priceWholesaleControllers.remove(id)?.dispose();
      _percentWholesaleControllers.remove(id)?.dispose();
      _typeWholesaleByProductId.remove(id);
    }

    for (final product in products) {
      _priceRetailControllers.putIfAbsent(product.id, () => TextEditingController(text: _formatCurrency(product.promoEnabledRetail ? product.promotionPriceRetail : product.priceRetail)));
      _percentRetailControllers.putIfAbsent(product.id, () => TextEditingController(text: _formatPercent(product.promoEnabledRetail && product.promoPercentRetail > 0 ? product.promoPercentRetail : _parseNumber(_percentRetailController.text))));
      _typeRetailByProductId.putIfAbsent(product.id, () => product.promoEnabledRetail ? _modeFromProduct(product, true) : _mode);

      _priceWholesaleControllers.putIfAbsent(product.id, () => TextEditingController(text: _formatCurrency(product.promoEnabledWholesale ? product.promotionPriceWholesaleCalculated : product.priceWholesale)));
      _percentWholesaleControllers.putIfAbsent(product.id, () => TextEditingController(text: _formatPercent(product.promoEnabledWholesale && product.promoPercentWholesale > 0 ? product.promoPercentWholesale : _parseNumber(_percentWholesaleController.text))));
      _typeWholesaleByProductId.putIfAbsent(product.id, () => product.promoEnabledWholesale ? _modeFromProduct(product, false) : _mode);
    }
  }

  void _resetPriceControllers(List<Product> products) {
    for (final c in _priceRetailControllers.values) c.dispose();
    for (final c in _percentRetailControllers.values) c.dispose();
    for (final c in _priceWholesaleControllers.values) c.dispose();
    for (final c in _percentWholesaleControllers.values) c.dispose();
    _priceRetailControllers.clear();
    _percentRetailControllers.clear();
    _typeRetailByProductId.clear();
    _priceWholesaleControllers.clear();
    _percentWholesaleControllers.clear();
    _typeWholesaleByProductId.clear();
    _syncPriceControllers(products);
  }

  double _parseNumber(String text) {
    return safeDouble(text);
  }
  
  double _parseCurrency(String text) {
    if (text.isEmpty) return 0.0;
    String cleaned = text
        .replaceAll('R\$', '')
        .replaceAll('%', '')
        .replaceAll('.', '')
        .replaceAll(',', '.')
        .trim();
    return double.tryParse(cleaned) ?? 0.0;
  }

  String _formatCurrency(double value) {
    final formatter = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    return formatter.format(value);
  }

  String _formatPercent(double value) {
    if (value % 1 == 0) return value.toInt().toString();
    return value.toStringAsFixed(2).replaceAll('.', ',');
  }

  _PromotionApplyMode _modeFromProduct(Product product, bool isRetail) {
    return (isRetail ? product.resolvedPromotionType : product.resolvedPromotionTypeWholesale) == 'manual'
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _PromotionProductRow extends StatelessWidget {
  const _PromotionProductRow({
    required this.product,
    required this.selected,
    required this.typeRetail,
    required this.typeWholesale,
    required this.priceRetailController,
    required this.percentRetailController,
    required this.priceWholesaleController,
    required this.percentWholesaleController,
    required this.onSelectedChanged,
    required this.onTypeRetailChanged,
    required this.onTypeWholesaleChanged,
    required this.onPercentRetailChanged,
    required this.onPercentWholesaleChanged,
    required this.onPromotionPriceRetailChanged,
    required this.onPromotionPriceWholesaleChanged,
  });

  final Product product;
  final bool selected;
  final _PromotionApplyMode typeRetail;
  final _PromotionApplyMode typeWholesale;
  final TextEditingController priceRetailController;
  final TextEditingController percentRetailController;
  final TextEditingController priceWholesaleController;
  final TextEditingController percentWholesaleController;
  final ValueChanged<bool> onSelectedChanged;
  final ValueChanged<_PromotionApplyMode> onTypeRetailChanged;
  final ValueChanged<_PromotionApplyMode> onTypeWholesaleChanged;
  final ValueChanged<String> onPercentRetailChanged;
  final ValueChanged<String> onPercentWholesaleChanged;
  final ValueChanged<String> onPromotionPriceRetailChanged;
  final ValueChanged<String> onPromotionPriceWholesaleChanged;

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.simpleCurrency(locale: 'pt_BR');
    final originalR = product.priceOriginalForPromotion;
    final originalW = product.priceOriginalForPromotionWholesale;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
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
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      product.ref.isEmpty ? 'Sem referencia' : product.ref,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
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
                typeRetail, 
                percentRetailController, 
                priceRetailController, 
                onTypeRetailChanged, 
                onPercentRetailChanged, 
                onPromotionPriceRetailChanged,
                product.promoEnabledRetail,
              );
              
              final wholesaleBlock = _buildPricingBlock(
                context, 
                currency, 
                'ATACADO', 
                originalW, 
                typeWholesale, 
                percentWholesaleController, 
                priceWholesaleController, 
                onTypeWholesaleChanged, 
                onPercentWholesaleChanged, 
                onPromotionPriceWholesaleChanged,
                product.promoEnabledWholesale,
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
            }
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
    _PromotionApplyMode type,
    TextEditingController percentController,
    TextEditingController priceController,
    ValueChanged<_PromotionApplyMode> onTypeChanged,
    ValueChanged<String> onPercentChanged,
    ValueChanged<String> onPriceChanged,
    bool isActive,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(12),
        color: isActive ? Colors.blue.shade50.withValues(alpha: 0.3) : Colors.transparent,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey),
              ),
              if (isActive)
                PromoBadge(
                  discountPercentage: ((original - (_parseCurrency(priceController.text))) / original * 100).round().clamp(0, 100),
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
                child: DropdownButtonFormField<_PromotionApplyMode>(
                  value: type,
                  onChanged: selected ? (value) { if (value != null) onTypeChanged(value); } : null,
                  decoration: const InputDecoration(labelText: 'Tipo', isDense: true, border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: _PromotionApplyMode.percent, child: Text('Porcentagem')),
                    DropdownMenuItem(value: _PromotionApplyMode.manual, child: Text('Manual')),
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
                  enabled: selected,
                  textAlign: TextAlign.end,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]'))],
                  onChanged: onPercentChanged,
                  decoration: InputDecoration(
                    labelText: 'Desconto', 
                    suffixText: type == _PromotionApplyMode.percent ? '%' : null, 
                    prefixText: type == _PromotionApplyMode.manual ? 'R\$ ' : null,
                    isDense: true, 
                    border: const OutlineInputBorder()
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: TextField(
                  controller: priceController,
                  enabled: selected,
                  textAlign: TextAlign.end,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [CurrencyInputFormatter()],
                  onChanged: onPriceChanged,
                  decoration: const InputDecoration(labelText: 'Por', prefixText: 'R\$ ', isDense: true, border: OutlineInputBorder()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  double _parseCurrency(String text) {
    if (text.isEmpty) return 0.0;
    String cleaned = text.replaceAll(',', '.').replaceAll(RegExp(r'[^0-9.]'), '');
    if (cleaned.split('.').length > 2) {
      final parts = cleaned.split('.');
      final decimal = parts.removeLast();
      cleaned = '${parts.join('')}.$decimal';
    }
    return double.tryParse(cleaned) ?? 0.0;
  }
}
