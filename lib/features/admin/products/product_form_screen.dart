import 'dart:io';
import 'package:gravity/core/widgets/responsive_scaffold.dart';
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
import 'package:flutter/foundation.dart' hide Category; // Added for kIsWeb
import 'package:flutter/services.dart';
import 'package:gravity/core/utils/price_calculator.dart';

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

  String? _selectedCollectionId;
  List<String> _selectedTypeIds = [];
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
    if (_selectedTypeIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione ao menos uma categoria')),
      );
      return;
    }

    final photosForSave = _normalizePhotosForSave();
    final imagesForSave = _imagesFromPhotos(photosForSave);
    final mainImageIndex = _mainIndexFromPhotos(photosForSave);
    final categoryIds = <String>[
      if (_selectedCollectionId != null) _selectedCollectionId!,
      ..._selectedTypeIds,
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

  Future<void> _addPhoto() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.any,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      final resolved = await _processPickedImage(file);
      if (resolved == null || !mounted) return;

      final meta = await _showPhotoMetaDialog(context);
      if (meta == null || !mounted) return;

      setState(() {
        if (meta.isPrimary) {
          _photos = _photos
              .map((p) => p.copyWith(isPrimary: false))
              .toList();
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
            isPrimary: meta.isPrimary || _photos.isEmpty,
          ),
        );
      });
    } catch (e, stack) {
      debugPrint('Error in _addPhoto: $e\n$stack');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao selecionar foto: $e')),
        );
      }
    }
  }

  Future<_PhotoMetaResult?> _showPhotoMetaDialog(
    BuildContext context,
  ) async {
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
                value: selected,
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

  void _setPrimaryPhoto(int index) {
    setState(() {
      _photos = _photos.asMap().entries.map((entry) {
        return entry.value.copyWith(isPrimary: entry.key == index);
      }).toList();
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
    final collections = categories
        .where((c) => c.type == CategoryType.collection)
        .toList();
    final productTypes = categories
        .where((c) => c.type == CategoryType.productType)
        .toList();

    if (!_categorySelectionInitialized && categories.isNotEmpty) {
      final collectionMatches = collections
          .where((c) => _initialCategoryIds.contains(c.id))
          .map((c) => c.id)
          .toList();
      _selectedCollectionId = collectionMatches.isNotEmpty
          ? collectionMatches.first
          : null;
      _selectedTypeIds = productTypes
          .where((c) => _initialCategoryIds.contains(c.id))
          .map((c) => c.id)
          .toList();
      _categorySelectionInitialized = true;
    }

    return ResponsiveScaffold(
      maxWidth: 900,
      appBar: AppBar(
        title: Text(widget.product == null ? 'Novo Produto' : 'Editar Produto'),
        actions: [IconButton(icon: const Icon(Icons.check), onPressed: _save)],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 600;
            return Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Basic Info
                    _buildSectionTitle('Informações Básicas'),
                    if (isMobile) ...[
                      _buildTextField(
                        _nameController,
                        'Nome',
                        validator: (v) => v!.isEmpty ? 'Obrigatório' : null,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        _refController,
                        'REF',
                        validator: (v) => v!.isEmpty ? 'Obrigatório' : null,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(_skuController, 'SKU'),
                    ] else
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: _buildTextField(
                              _nameController,
                              'Nome',
                              validator: (v) =>
                                  v!.isEmpty ? 'Obrigatório' : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildTextField(
                              _refController,
                              'REF',
                              validator: (v) =>
                                  v!.isEmpty ? 'Obrigatório' : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildTextField(_skuController, 'SKU'),
                          ),
                        ],
                      ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue:
                          collections.any((c) => c.id == _selectedCollectionId)
                          ? _selectedCollectionId
                          : null,
                      decoration: const InputDecoration(labelText: 'Colecao'),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('Sem colecao'),
                        ),
                        ...collections.map(
                          (c) => DropdownMenuItem(
                            value: c.id,
                            child: Text(c.name),
                          ),
                        ),
                      ],
                      onChanged: (val) =>
                          setState(() => _selectedCollectionId = val),
                    ),
                    const SizedBox(height: 16),
                    _buildSectionTitle('Categorias'),
                    _buildCategoryMultiSelect(context, productTypes),

                    const SizedBox(height: 24),

                    // Pricing
                    _buildSectionTitle('Preços e Estoque'),
                    if (isMobile) ...[
                      _buildTextField(
                        _retailController,
                        'Varejo (R\$)',
                        isPrice: true,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        _wholesaleController,
                        'Atacado (R\$)',
                        isPrice: true,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        _minQtyController,
                        'Mín. Atacado',
                        isNumber: true,
                      ),
                    ] else
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              _retailController,
                              'Varejo (R\$)',
                              isPrice: true,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildTextField(
                              _wholesaleController,
                              'Atacado (R\$)',
                              isPrice: true,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildTextField(
                              _minQtyController,
                              'Mín. Atacado',
                              isNumber: true,
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 24),
                    Text(
                      'Preço atacado pode ser ajustado conforme sua política.',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 16),

                    // Attributes
                    _buildSectionTitle('Atributos'),
                    _buildTextField(
                      _sizesController,
                      'Tamanhos (separados por vírgula)',
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      _colorsController,
                      'Cores (separados por vírgula)',
                    ),

                    const SizedBox(height: 24),

                    // Status
                    _buildSectionTitle('Status'),
                    SwitchListTile(
                      title: const Text('Ativo'),
                      value: _isActive,
                      onChanged: (v) => setState(() => _isActive = v),
                    ),
                    SwitchListTile(
                      title: const Text('Esgotado'),
                      value: _isOutOfStock,
                      onChanged: (v) => setState(() => _isOutOfStock = v),
                    ),
                    SwitchListTile(
                      title: const Text('Em Promoção'),
                      value: _isOnSale,
                      onChanged: (v) => setState(() => _isOnSale = v),
                    ),
                    if (_isOnSale) ...[
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: TextFormField(
                          controller: _discountController,
                          decoration: const InputDecoration(
                            labelText: 'Desconto (%)',
                            hintText: 'Ex: 10 para 10% OFF',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          validator: (v) {
                            if (_isOnSale && (v == null || v.isEmpty)) {
                              return 'Informe o desconto';
                            }
                            final val = int.tryParse(v ?? '0') ?? 0;
                            if (val < 0 || val > 100) {
                              return 'Desconto deve estar entre 0 e 100';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _buildPromoPreview(),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Images
                    _buildSectionTitle('Imagens'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: _photos.asMap().entries.map((entry) {
                        return _buildPhotoTile(entry.key, entry.value);
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _addPhoto,
                      icon: const Icon(Icons.upload),
                      label: const Text('Adicionar foto'),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCategoryMultiSelect(
    BuildContext context,
    List<Category> productTypes,
  ) {
    final selected = productTypes
        .where((c) => _selectedTypeIds.contains(c.id))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: selected.isEmpty
              ? [
                  Text(
                    'Nenhuma categoria selecionada',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ]
              : selected.map((c) => Chip(label: Text(c.name))).toList(),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => _selectProductTypes(context, productTypes),
          icon: const Icon(Icons.tune),
          label: const Text('Selecionar categorias'),
        ),
      ],
    );
  }

  Future<void> _selectProductTypes(
    BuildContext context,
    List<Category> productTypes,
  ) async {
    final tempSelected = Set<String>.from(_selectedTypeIds);
    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ListTile(
                  title: Text(
                    'Categorias',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: productTypes.map((category) {
                      final checked = tempSelected.contains(category.id);
                      return CheckboxListTile(
                        value: checked,
                        onChanged: (value) {
                          setModalState(() {
                            if (value == true) {
                              tempSelected.add(category.id);
                            } else {
                              tempSelected.remove(category.id);
                            }
                          });
                        },
                        title: Text(category.name),
                      );
                    }).toList(),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () =>
                          Navigator.pop(sheetContext, tempSelected),
                      child: const Text('Aplicar'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (result != null && mounted) {
      setState(() => _selectedTypeIds = result.toList());
    }
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildPromoPreview() {
    final retail = _parsePrice(_retailController.text);
    final wholesale = _parsePrice(_wholesaleController.text);
    final percent = double.tryParse(_discountController.text) ?? 0;
    final retailFinal = PriceCalculator.effectiveRetail(
      retail,
      _isOnSale,
      percent,
    );
    final wholesaleFinal = PriceCalculator.effectiveWholesale(
      wholesale,
      _isOnSale,
      percent,
    );
    final currency = NumberFormat.simpleCurrency(locale: 'pt_BR');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Varejo final: ${currency.format(retailFinal)}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'Atacado final: ${currency.format(wholesaleFinal)}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildPhotoTile(int index, ProductPhoto photo) {
    final colorLabel = photo.colorKey?.toUpperCase() ?? 'GERAL';
    return SizedBox(
      width: 110,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: photo.isPrimary ? Colors.blue : Colors.transparent,
                    width: 2,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: kIsWeb
                    ? const Center(child: Text('Sem preview'))
                    : Image.file(
                        File(photo.path),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Center(
                          child: Icon(
                            Icons.broken_image,
                            color: Colors.red,
                          ),
                        ),
                      ),
              ),
              Positioned(
                top: 6,
                right: 6,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        photo.isPrimary ? Icons.star : Icons.star_border,
                        color: Colors.white,
                        size: 18,
                      ),
                      onPressed: () => _setPrimaryPhoto(index),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black54,
                        padding: const EdgeInsets.all(4),
                        minimumSize: const Size(28, 28),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.white,
                        size: 18,
                      ),
                      onPressed: () => _removePhoto(index),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black54,
                        padding: const EdgeInsets.all(4),
                        minimumSize: const Size(28, 28),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            colorLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          if (photo.isPrimary)
            const Text(
              'principal',
              style: TextStyle(fontSize: 11, color: Colors.blueGrey),
            ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    bool isNumber = false,
    bool isPrice = false,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        helperText: isPrice ? 'Ex: 10,50' : null,
      ),
      keyboardType: isPrice
          ? const TextInputType.numberWithOptions(decimal: true)
          : (isNumber ? TextInputType.number : TextInputType.text),
      validator: validator,
    );
  }
}

