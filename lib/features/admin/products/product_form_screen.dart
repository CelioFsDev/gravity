import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gravity/models/product.dart';
import 'package:gravity/models/category.dart';
import 'package:gravity/viewmodels/products_viewmodel.dart';
import 'package:uuid/uuid.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter/services.dart';
import 'package:gravity/ui/theme/app_tokens.dart';
import 'package:gravity/ui/widgets/app_scaffold.dart';
import 'package:gravity/ui/widgets/section_card.dart';
import 'package:gravity/ui/widgets/app_primary_button.dart';
import 'package:gravity/features/admin/categories/widgets/category_create_modal.dart';
import 'package:go_router/go_router.dart';
import 'package:gravity/core/services/ai_description_service.dart';
import 'package:gravity/data/repositories/settings_repository.dart';

class ProductFormScreen extends ConsumerStatefulWidget {
  final Product? product; // null for Create, non-null for Edit

  const ProductFormScreen({super.key, this.product});

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _PhotoMetaResult {
  final String? colorKey;
  final bool isPrimary;
  final bool isNewColor;

  const _PhotoMetaResult({
    required this.colorKey,
    required this.isPrimary,
    required this.isNewColor,
  });
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  late TextEditingController _nameController;
  late TextEditingController _refController;
  late TextEditingController _skuController;
  late TextEditingController _retailController;
  late TextEditingController _wholesaleController;
  late TextEditingController _minQtyController;
  late TextEditingController _sizesController;
  late TextEditingController _colorsController;
  late TextEditingController _discountController;
  late TextEditingController _descriptionController;

  List<String> _selectedCategoryIds = [];
  String? _selectedCollectionId;
  List<String> _initialCategoryIds = [];
  bool _categorySelectionInitialized = false;
  bool _isActive = true;
  bool _isOutOfStock = false;
  bool _isOnSale = false;
  List<ProductPhoto> _photos = [];

  @override
  void initState() {
    super.initState();
    final pr = widget.product;
    _nameController = TextEditingController(text: pr?.name ?? '');
    _refController = TextEditingController(text: pr?.reference ?? '');
    _skuController = TextEditingController(text: pr?.sku ?? '');
    final f = NumberFormat.decimalPattern('pt_BR');
    _retailController = TextEditingController(
      text: pr != null ? f.format(pr.retailPrice) : '',
    );
    _wholesaleController = TextEditingController(
      text: pr != null ? f.format(pr.wholesalePrice) : '',
    );
    _minQtyController = TextEditingController(
      text: pr?.minWholesaleQty.toString() ?? '1',
    );
    _sizesController = TextEditingController(text: pr?.sizes.join(', ') ?? '');
    _colorsController = TextEditingController(
      text: pr?.colors.join(', ') ?? '',
    );
    _discountController = TextEditingController(
      text: pr?.saleDiscountPercent.toString() ?? '0',
    );
    _descriptionController = TextEditingController(text: pr?.description ?? '');

    _initialCategoryIds = pr?.categoryIds ?? [];
    _isActive = pr?.isActive ?? true;
    _isOutOfStock = pr?.isOutOfStock ?? false;
    _isOnSale = pr?.isOnSale ?? false;
    if (pr != null && pr.photos.isNotEmpty) {
      _photos = List<ProductPhoto>.from(pr.photos);
    } else if (pr != null && pr.images.isNotEmpty) {
      final safeIndex = pr.mainImageIndex.clamp(0, pr.images.length - 1);
      _photos = pr.images.asMap().entries.map((entry) {
        return ProductPhoto(
          path: entry.value,
          colorKey: null,
          isPrimary: entry.key == safeIndex,
        );
      }).toList();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _refController.dispose();
    _skuController.dispose();
    _retailController.dispose();
    _wholesaleController.dispose();
    _minQtyController.dispose();
    _sizesController.dispose();
    _colorsController.dispose();
    _discountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  double _parsePrice(String text) {
    if (text.isEmpty) return 0.0;
    // Replace comma with dot and remove other non-numeric chars except dot
    String cleaned = text
        .replaceAll(',', '.')
        .replaceAll(RegExp(r'[^0-9.]'), '');
    // Handle cases like "1.000.50" -> "1000.50"
    if (cleaned.split('.').length > 2) {
      final parts = cleaned.split('.');
      final decimal = parts.removeLast();
      cleaned = '${parts.join('')}.$decimal';
    }
    return double.tryParse(cleaned) ?? 0.0;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCollectionId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('A coleção é obrigatória')));
      return;
    }

    final photosForSave = _normalizePhotosForSave();
    final imagesForSave = _imagesFromPhotos(photosForSave);
    final mainImageIndex = _mainIndexFromPhotos(photosForSave);

    // Combine Collection + Categories
    final categoryIds = <String>[
      _selectedCollectionId!,
      ..._selectedCategoryIds,
    ];
    final product = Product(
      id: widget.product?.id ?? const Uuid().v4(),
      name: _nameController.text,
      ref: _refController.text,
      sku: _skuController.text,
      categoryIds: categoryIds.toSet().toList(),
      priceRetail: _parsePrice(_retailController.text),
      priceWholesale: _parsePrice(_wholesaleController.text),
      minWholesaleQty: int.tryParse(_minQtyController.text) ?? 1,
      sizes: _sizesController.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(),
      colors: _colorsController.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(),
      images: imagesForSave,
      mainImageIndex: mainImageIndex,
      photos: photosForSave,
      isActive: _isActive,
      isOutOfStock: _isOutOfStock,
      promoEnabled: _isOnSale,
      createdAt: widget.product?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
      promoPercent: _isOnSale
          ? (int.tryParse(_discountController.text) ?? 0).toDouble()
          : 0.0,
      description: _descriptionController.text,
    );

    try {
      if (widget.product == null) {
        await ref.read(productsViewModelProvider.notifier).addProduct(product);
      } else {
        await ref
            .read(productsViewModelProvider.notifier)
            .updateProduct(product);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao salvar: $e')));
      }
    }
  }

  Future<void> _addPrimaryPhoto() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.image,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      final resolved = await _processPickedImage(file);
      if (resolved == null || !mounted) return;

      setState(() {
        // Clear previous primary and set this one
        _photos = _photos.map((p) => p.copyWith(isPrimary: false)).toList();
        _photos.insert(
          0,
          ProductPhoto(path: resolved, colorKey: null, isPrimary: true),
        );
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao selecionar foto: $e')));
      }
    }
  }

  Future<void> _addSecondaryPhotos() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.image,
      );
      if (result == null || result.files.isEmpty) return;

      for (var file in result.files) {
        final resolved = await _processPickedImage(file);
        if (resolved == null || !mounted) continue;

        final meta = await _showPhotoMetaDialog(context);
        if (meta == null || !mounted) break;

        setState(() {
          if (meta.isPrimary) {
            _photos = _photos.map((p) => p.copyWith(isPrimary: false)).toList();
          }
          if (meta.isNewColor && meta.colorKey != null) {
            final current = _parseColorOptions().toSet();
            if (!current.contains(meta.colorKey)) {
              final sep = _colorsController.text.trim().isEmpty ? '' : ', ';
              _colorsController.text =
                  '${_colorsController.text.trim()}$sep${meta.colorKey}';
            }
          }
          _photos.add(
            ProductPhoto(
              path: resolved,
              colorKey: meta.colorKey,
              isPrimary: meta.isPrimary,
            ),
          );
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao selecionar fotos: $e')));
      }
    }
  }

  Future<_PhotoMetaResult?> _showPhotoMetaDialog(BuildContext context) async {
    final colors = _parseColorOptions();
    String selected = '__none__';
    final newColorController = TextEditingController();
    bool isPrimary = false;

    final result = await showDialog<_PhotoMetaResult>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Text('Vincular foto a cor'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: selected,
                decoration: const InputDecoration(labelText: 'Cor'),
                items: [
                  const DropdownMenuItem(
                    value: '__none__',
                    child: Text('Sem cor (geral)'),
                  ),
                  const DropdownMenuItem(
                    value: '__new__',
                    child: Text('Adicionar nova cor'),
                  ),
                  ...colors.map(
                    (c) => DropdownMenuItem(value: c, child: Text(c)),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setModalState(() => selected = value);
                },
              ),
              if (selected == '__new__') ...[
                const SizedBox(height: 12),
                TextField(
                  controller: newColorController,
                  decoration: const InputDecoration(
                    labelText: 'Nova cor',
                    hintText: 'Ex: PRETO',
                  ),
                ),
              ],
              const SizedBox(height: 12),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: isPrimary,
                onChanged: (value) =>
                    setModalState(() => isPrimary = value ?? false),
                title: const Text('Foto principal'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                String? colorKey;
                bool isNewColor = false;
                if (selected == '__new__') {
                  final text = newColorController.text.trim();
                  if (text.isEmpty) return;
                  colorKey = text.toUpperCase();
                  isNewColor = true;
                } else if (selected == '__none__') {
                  colorKey = null;
                } else {
                  colorKey = selected.toUpperCase();
                }
                Navigator.pop(
                  dialogContext,
                  _PhotoMetaResult(
                    colorKey: colorKey,
                    isPrimary: isPrimary,
                    isNewColor: isNewColor,
                  ),
                );
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      newColorController.dispose();
    });
    return result;
  }

  List<String> _parseColorOptions() {
    final values = _colorsController.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .map((e) => e.toUpperCase())
        .toSet()
        .toList();
    values.sort();
    return values;
  }

  Future<String?> _processPickedImage(PlatformFile file) async {
    final ext = p.extension(file.name).toLowerCase();
    if (!['.jpg', '.jpeg', '.png', '.webp'].contains(ext)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Arquivo "${file.name}" ignorado (não é imagem).'),
          ),
        );
      }
      return null;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Copiando ${file.name}...'),
          duration: const Duration(milliseconds: 500),
        ),
      );
    }

    final resolved = await _copyFileToPersistentStorage(file);
    if (resolved == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Falha ao processar "${file.name}".')),
      );
    }
    return resolved;
  }

  List<ProductPhoto> _normalizePhotosForSave() {
    if (_photos.isEmpty) return const [];
    final hasPrimary = _photos.any((p) => p.isPrimary);
    if (hasPrimary) return List<ProductPhoto>.from(_photos);
    final updated = <ProductPhoto>[];
    for (var i = 0; i < _photos.length; i++) {
      updated.add(_photos[i].copyWith(isPrimary: i == 0));
    }
    return updated;
  }

  List<String> _imagesFromPhotos(List<ProductPhoto> photos) {
    return photos.map((p) => p.path).toList();
  }

  int _mainIndexFromPhotos(List<ProductPhoto> photos) {
    final index = photos.indexWhere((p) => p.isPrimary);
    return index >= 0 ? index : 0;
  }

  void _setPrimaryPhoto(String path) {
    setState(() {
      _photos = _photos.map((p) {
        return p.copyWith(isPrimary: p.path == path);
      }).toList();

      // Move primary to front of the list
      final pIndex = _photos.indexWhere((p) => p.isPrimary);
      if (pIndex > 0) {
        final primary = _photos.removeAt(pIndex);
        _photos.insert(0, primary);
      }
    });
  }

  void _removePhoto(int index) {
    setState(() {
      final removedPrimary = _photos[index].isPrimary;
      _photos.removeAt(index);
      if (removedPrimary && _photos.isNotEmpty) {
        _photos = _photos.asMap().entries.map((entry) {
          return entry.value.copyWith(isPrimary: entry.key == 0);
        }).toList();
      }
    });
  }

  Future<String?> _copyFileToPersistentStorage(PlatformFile file) async {
    try {
      // Windows/Desktop priority: use path if available
      if (!kIsWeb && file.path != null) {
        final baseDir = await getApplicationDocumentsDirectory();
        final imagesDir = Directory(p.join(baseDir.path, 'product_images'));
        if (!await imagesDir.exists()) {
          await imagesDir.create(recursive: true);
        }

        final extension = p.extension(file.name).isNotEmpty
            ? p.extension(file.name).toLowerCase()
            : '.jpg';
        final String fileName = '${const Uuid().v4()}$extension';
        final String targetPath = p.join(imagesDir.path, fileName);
        final File targetFile = File(targetPath);

        debugPrint('Reading from path: ${file.path}');
        final sourceFile = File(file.path!);
        if (!await sourceFile.exists()) {
          debugPrint('Error: Source file does not exist');
          return null;
        }
        final bytes = await sourceFile.readAsBytes();
        await targetFile.writeAsBytes(bytes);

        if (await targetFile.exists()) {
          debugPrint('Successfully saved to: $targetPath');
          return targetPath;
        }
      } else if (file.bytes != null) {
        // Fallback for Web or byte-only results
        debugPrint('Processing from bytes (length: ${file.bytes!.length})');
        if (kIsWeb) {
          // On Web, we can't save to a local File path.
          // However, we can return a data URL or just a placeholder for now
          // For this app, persistence on Web would require a different approach (e.g. IndexedDB via Hive)
          // If you need real persistence, run as a Windows Desktop app.
          return 'web_placeholder_${const Uuid().v4()}';
        }

        final baseDir = await getApplicationDocumentsDirectory();
        final imagesDir = Directory(p.join(baseDir.path, 'product_images'));
        if (!await imagesDir.exists()) {
          await imagesDir.create(recursive: true);
        }
        final extension = p.extension(file.name).isNotEmpty
            ? p.extension(file.name).toLowerCase()
            : '.jpg';
        final String targetPath = p.join(
          imagesDir.path,
          '${const Uuid().v4()}$extension',
        );
        await File(targetPath).writeAsBytes(file.bytes!);
        return targetPath;
      } else {
        debugPrint('Error: Both path and bytes are null');
        return null;
      }

      return null;
    } on MissingPluginException catch (e) {
      debugPrint(
        'Plugin missing: $e. Usually happens when not restarted after adding path_provider or running on Web.',
      );
      if (kIsWeb && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Atenção: O salvamento de fotos não é suportado no Navegador. Use a versão Windows Desktop.',
            ),
          ),
        );
      }
      return null;
    } catch (e, stack) {
      debugPrint('Error copying file: $e\n$stack');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final productsState = ref.watch(productsViewModelProvider);
    final categories = productsState.hasValue
        ? productsState.value!.categories
        : <Category>[];

    final productTypes = categories
        .where((c) => c.type == CategoryType.productType)
        .toList();

    final collections = categories
        .where((c) => c.type == CategoryType.collection)
        .toList(); // Added collections list

    if (!_categorySelectionInitialized && categories.isNotEmpty) {
      // Find collection
      final foundCol = collections.where(
        (c) => _initialCategoryIds.contains(c.id),
      );
      if (foundCol.isNotEmpty) {
        _selectedCollectionId = foundCol.first.id;
      }

      // Find categories
      _selectedCategoryIds = productTypes
          .where((c) => _initialCategoryIds.contains(c.id))
          .map((c) => c.id)
          .toList();
      _categorySelectionInitialized = true;
    }

    return AppScaffold(
      title: widget.product == null ? 'Novo Produto' : 'Editar Produto',
      subtitle: widget.product == null
          ? 'Preencha os dados do novo item'
          : 'Atualize as informações do produto',
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTokens.space24,
                ),
                children: [
                  const SizedBox(height: AppTokens.space24),
                  SectionCard(
                    title: 'Informações Básicas',
                    child: Column(
                      children: [
                        _buildTextField(
                          _nameController,
                          'Nome do Produto',
                          validator: (v) => v!.isEmpty ? 'Obrigatório' : null,
                        ),
                        const SizedBox(height: AppTokens.space16),
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                _refController,
                                'REF (Código)',
                                validator: (v) {
                                  if (v == null || v.isEmpty) {
                                    return 'Obrigatório';
                                  }
                                  final state = ref
                                      .read(productsViewModelProvider)
                                      .value;
                                  if (state != null) {
                                    final exists = state.allProducts.any(
                                      (p) =>
                                          p.ref.toUpperCase() ==
                                              v.toUpperCase() &&
                                          p.id != widget.product?.id,
                                    );
                                    if (exists) return 'Indisponível';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: AppTokens.space12),
                            Expanded(
                              child: _buildTextField(_skuController, 'SKU'),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppTokens.space16),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppTokens.space24),
                  SectionCard(
                    title: 'Organização',
                    child: _buildOrganizationSection(
                      context,
                      collections,
                      productTypes,
                    ),
                  ),
                  const SizedBox(height: AppTokens.space24),
                  SectionCard(
                    title: 'Preços e Estoque',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                _retailController,
                                'Preço Varejo',
                                isPrice: true,
                              ),
                            ),
                            const SizedBox(width: AppTokens.space12),
                            Expanded(
                              child: _buildTextField(
                                _wholesaleController,
                                'Preço Atacado',
                                isPrice: true,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppTokens.space16),
                        _buildTextField(
                          _minQtyController,
                          'Quantidade Mínima para Atacado',
                          isNumber: true,
                        ),
                        const SizedBox(height: AppTokens.space12),
                        Text(
                          'O preço atacado será aplicado automaticamente no carrinho para quantidades maiores que o mínimo.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppTokens.space24),
                  SectionCard(
                    title: 'Variações (Opcional)',
                    child: Column(
                      children: [
                        _buildTextField(
                          _sizesController,
                          'Tamanhos (ex: P, M, G ou 38, 40)',
                        ),
                        const SizedBox(height: AppTokens.space16),
                        _buildTextField(
                          _colorsController,
                          'Cores (ex: Preto, Branco, Azul)',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppTokens.space24),
                  const SizedBox(height: AppTokens.space24),
                  SectionCard(
                    title: 'Descrição do Produto',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildTextField(
                          _descriptionController,
                          'Descrição Detalhada',
                          maxLines: 5,
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _generateAiDescription,
                          icon: const Icon(Icons.auto_awesome),
                          label: const Text('Gerar Descrição com IA'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.purple,
                            side: const BorderSide(color: Colors.purple),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppTokens.space24),
                  SectionCard(
                    title: 'Disponibilidade e Promoção',
                    child: Column(
                      children: [
                        _buildSwitchTile(
                          'Produto Ativo no Catálogo',
                          _isActive,
                          (v) => setState(() => _isActive = v),
                        ),
                        const Divider(),
                        _buildSwitchTile(
                          'Produto Esgotado',
                          _isOutOfStock,
                          (v) => setState(() => _isOutOfStock = v),
                        ),
                        const Divider(),
                        _buildSwitchTile(
                          'Em Promoção',
                          _isOnSale,
                          (v) => setState(() => _isOnSale = v),
                        ),
                        if (_isOnSale) ...[
                          const SizedBox(height: AppTokens.space16),
                          _buildTextField(
                            _discountController,
                            'Porcentagem de Desconto (%)',
                            isNumber: true,
                            validator: (v) {
                              if (_isOnSale && (v == null || v.isEmpty)) {
                                return 'Informe o desconto';
                              }
                              final val = int.tryParse(v ?? '0') ?? 0;
                              if (val < 0 || val > 100) return '0 a 100%';
                              return null;
                            },
                          ),
                          const SizedBox(height: AppTokens.space12),
                          _buildPromoPreview(),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppTokens.space24),
                  const SizedBox(height: AppTokens.space24),
                  _buildImagesSection(),
                  const SizedBox(height: AppTokens.space24),
                  const SizedBox(height: AppTokens.space48),
                ],
              ),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(AppTokens.space24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: AppPrimaryButton(
          label: widget.product == null ? 'Criar Produto' : 'Salvar Alterações',
          onPressed: _save,
          icon: Icons.check_circle_outline,
        ),
      ),
    );
  }

  Future<void> _generateAiDescription() async {
    final name = _nameController.text;
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe o nome do produto primeiro')),
      );
      return;
    }

    final category = _selectedCollectionId != null
        ? ref
                  .read(productsViewModelProvider)
                  .value
                  ?.categories
                  .firstWhere((c) => c.id == _selectedCollectionId)
                  .name ??
              ''
        : '';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final desc = await ref
          .read(aiDescriptionServiceProvider.notifier)
          .generateDescription(
            productName: name,
            category: category,
            details:
                'Cores: ${_colorsController.text}, Tamanhos: ${_sizesController.text}',
          );

      if (mounted) {
        Navigator.pop(context); // Close loading
        if (desc != null) {
          setState(() => _descriptionController.text = desc);
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro IA: $e')));
      }
    }
  }

  Widget _buildImagesSection() {
    final primaryIndex = _photos.indexWhere((p) => p.isPrimary);
    final primaryPhoto = primaryIndex >= 0 ? _photos[primaryIndex] : null;
    final secondaryPhotos = _photos.where((p) => !p.isPrimary).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Primary Photo
        SectionCard(
          title: 'Foto Principal (Capa)',
          child: Column(
            children: [
              if (primaryPhoto != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SizedBox(
                    width: 140,
                    height: 140,
                    child: _buildPhotoTile(
                      primaryPhoto,
                      key: ValueKey('primary_${primaryPhoto.path}'),
                    ),
                  ),
                ),
              Center(
                child: OutlinedButton.icon(
                  onPressed: _addPrimaryPhoto,
                  icon: Icon(
                    primaryPhoto == null ? Icons.add_a_photo : Icons.refresh,
                  ),
                  label: Text(
                    primaryPhoto == null ? 'Adicionar Capa' : 'Trocar Capa',
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTokens.space24),
        // Secondary Photos
        SectionCard(
          title: 'Detalhes e Cores',
          child: SizedBox(
            height: 110,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildAddSecondaryTile(),
                const SizedBox(width: 12),
                ...secondaryPhotos.map((photo) {
                  return Padding(
                    key: ValueKey('secondary_${photo.path}'),
                    padding: const EdgeInsets.only(right: 12),
                    child: SizedBox(
                      width: 110,
                      child: _buildPhotoTile(
                        photo,
                        key: ValueKey('tile_${photo.path}'),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAddSecondaryTile() {
    return InkWell(
      onTap: _addSecondaryPhotos,
      borderRadius: BorderRadius.circular(AppTokens.radiusMd),
      child: Container(
        width: 110,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          border: Border.all(
            color: Theme.of(context).dividerColor,
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_a_photo_outlined, color: AppTokens.accentBlue),
            const SizedBox(height: 4),
            Text(
              'Adicionar',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchTile(
    String title,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
            Switch.adaptive(
              value: value,
              onChanged: onChanged,
              activeColor: AppTokens.accentBlue,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    String? Function(String?)? validator,
    bool isPrice = false,
    bool isNumber = false,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            labelText: label,
            floatingLabelBehavior: FloatingLabelBehavior.never,
            filled: true,
            fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTokens.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTokens.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTokens.accentBlue, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTokens.accentRed),
            ),
          ),
          style: const TextStyle(fontSize: 15),
          validator: validator,
          keyboardType: (isPrice || isNumber)
              ? const TextInputType.numberWithOptions(decimal: true)
              : null,
          inputFormatters: [
            if (isPrice) FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            if (isNumber && !isPrice) FilteringTextInputFormatter.digitsOnly,
          ],
        ),
      ],
    );
  }

  Widget _buildPhotoTile(ProductPhoto photo, {Key? key}) {
    return Stack(
      key: key,
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
            border: Border.all(
              color: photo.isPrimary
                  ? AppTokens.accentBlue
                  : Theme.of(context).dividerColor,
              width: photo.isPrimary ? 2 : 1,
            ),
            image: DecorationImage(
              image: photo.path.startsWith('http')
                  ? NetworkImage(photo.path)
                  : FileImage(File(photo.path)) as ImageProvider,
              fit: BoxFit.cover,
            ),
          ),
        ),
        if (photo.colorKey != null)
          Positioned(
            top: 4,
            left: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                photo.colorKey!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        Positioned(
          top: -10,
          right: -10,
          child: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                shape: BoxShape.circle,
                boxShadow: [AppTokens.shadowSm],
              ),
              child: const Icon(
                Icons.close,
                size: 14,
                color: AppTokens.accentRed,
              ),
            ),
            onPressed: () => _removePhoto(_photos.indexOf(photo)),
          ),
        ),
        if (!photo.isPrimary)
          Positioned(
            bottom: 4,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: () => _setPrimaryPhoto(photo.path),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(AppTokens.radiusFull),
                    boxShadow: const [AppTokens.shadowSm],
                  ),
                  child: const Text(
                    'Tornar Principal',
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          )
        else
          Positioned(
            bottom: 4,
            right: 4,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: AppTokens.accentBlue,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.star, size: 12, color: Colors.white),
            ),
          ),
      ],
    );
  }

  Widget _buildPromoPreview() {
    final retail = _parsePrice(_retailController.text);
    final discount = int.tryParse(_discountController.text) ?? 0;
    if (retail <= 0 || discount <= 0) return const SizedBox.shrink();

    final value = retail * (1 - (discount / 100));
    final f = NumberFormat.currency(symbol: 'R\$', locale: 'pt_BR');

    return Container(
      padding: const EdgeInsets.all(AppTokens.space12),
      decoration: BoxDecoration(
        color: AppTokens.accentOrange.withOpacity(0.05),
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        border: Border.all(color: AppTokens.accentOrange.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.local_offer_outlined,
            size: 16,
            color: AppTokens.accentOrange,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Preço Promocional: ${f.format(value)}',
              style: const TextStyle(
                color: AppTokens.accentOrange,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrganizationSection(
    BuildContext context,
    List<Category> collections,
    List<Category> categories,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- COLLECTIONS ---
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _selectedCollectionId,
                decoration: const InputDecoration(
                  labelText: 'Coleção (Obrigatório)',
                  filled: true,
                ),
                items: collections
                    .map(
                      (c) => DropdownMenuItem(
                        value: c.id,
                        child: Text(c.safeName),
                      ),
                    )
                    .toList(),
                onChanged: (val) => setState(() => _selectedCollectionId = val),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              onPressed: () async {
                // Push CollectionFormScreen as a "modal" (full screen but returns value)
                final newId = await context.push<String>(
                  '/admin/collections/new',
                );
                if (newId != null && mounted) {
                  setState(() => _selectedCollectionId = newId);
                  // Refresh categories/collections handled by ViewModel?
                  // The collections list comes from ref.watch, so it should update if VM updates.
                }
              },
              icon: const Icon(Icons.add),
              tooltip: 'Nova Coleção',
            ),
          ],
        ),
        const SizedBox(height: 16),

        // --- CATEGORIES ---
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Categorias', style: Theme.of(context).textTheme.titleSmall),
            TextButton.icon(
              onPressed: () async {
                // Open CategoryCreateModal
                final newId = await showDialog<String>(
                  context: context,
                  builder: (context) => const CategoryCreateModal(),
                );
                if (newId != null && mounted) {
                  setState(() {
                    if (!_selectedCategoryIds.contains(newId)) {
                      _selectedCategoryIds.add(newId);
                    }
                  });
                }
              },
              icon: const Icon(Icons.add_circle_outline, size: 16),
              label: const Text('Criar Categoria'),
            ),
          ],
        ),
        if (categories.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Nenhuma categoria disponível.',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: categories.map((cat) {
            final isSelected = _selectedCategoryIds.contains(cat.id);
            return FilterChip(
              label: Text(cat.safeName),
              selected: isSelected,
              onSelected: (val) {
                setState(() {
                  if (val) {
                    _selectedCategoryIds.add(cat.id);
                  } else {
                    _selectedCategoryIds.remove(cat.id);
                  }
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }
}
