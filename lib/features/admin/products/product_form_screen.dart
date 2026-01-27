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
import 'package:flutter/foundation.dart' hide Category; // Added for kIsWeb
import 'package:flutter/services.dart';

class ProductFormScreen extends ConsumerStatefulWidget {
  final Product? product; // null for Create, non-null for Edit

  const ProductFormScreen({super.key, this.product});

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
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

  String? _selectedCategoryId;
  bool _isActive = true;
  bool _isOutOfStock = false;
  bool _isOnSale = false;
  List<String> _images = [];
  int _mainImageIndex = 0;

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

    _selectedCategoryId = pr?.categoryId;
    _isActive = pr?.isActive ?? true;
    _isOutOfStock = pr?.isOutOfStock ?? false;
    _isOnSale = pr?.isOnSale ?? false;
    _images = List.from(pr?.images ?? []);
    _mainImageIndex = pr?.mainImageIndex ?? 0;
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
    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Selecione uma categoria')));
      return;
    }

    final product = Product(
      id: widget.product?.id ?? const Uuid().v4(),
      name: _nameController.text,
      reference: _refController.text,
      sku: _skuController.text,
      categoryId: _selectedCategoryId!,
      retailPrice: _parsePrice(_retailController.text),
      wholesalePrice: _parsePrice(_wholesaleController.text),
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
      images: _images,
      mainImageIndex: _mainImageIndex,
      isActive: _isActive,
      isOutOfStock: _isOutOfStock,
      isOnSale: _isOnSale,
      createdAt: widget.product?.createdAt ?? DateTime.now(),
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
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao salvar: $e')));
    }
  }

  Future<void> _pickImages() async {
    try {
      debugPrint('Picking images...');
      final result = await FilePicker.pickFiles(
        allowMultiple: true,
        type: FileType
            .any, // Back to any to avoid filter issues on some Windows versions
        // allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'], // Filtered manually below
      );

      if (result != null && result.files.isNotEmpty) {
        debugPrint('Picked ${result.files.length} files');

        for (final file in result.files) {
          // Manual filtering for images
          final ext = p.extension(file.name).toLowerCase();
          if (!['.jpg', '.jpeg', '.png', '.webp'].contains(ext)) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Arquivo "${file.name}" ignorado (não é imagem).',
                  ),
                ),
              );
            }
            continue;
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
          if (resolved != null) {
            if (mounted) {
              setState(() {
                _images.add(resolved);
              });
            }
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Falha ao processar "${file.name}".')),
              );
            }
          }
        }
      }
    } catch (e, stack) {
      debugPrint('Error in _pickImages: $e\n$stack');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro crítico ao selecionar foto: $e')),
        );
      }
    }
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

    return Scaffold(
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
                          categories.any((c) => c.id == _selectedCategoryId)
                          ? _selectedCategoryId
                          : null,
                      decoration: const InputDecoration(
                        labelText: 'Categoria',
                        border: OutlineInputBorder(),
                      ),
                      items: categories
                          .map(
                            (c) => DropdownMenuItem(
                              value: c.id,
                              child: Text(c.name),
                            ),
                          )
                          .toList(),
                      onChanged: (val) =>
                          setState(() => _selectedCategoryId = val),
                    ),

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

                    const SizedBox(height: 24),

                    // Images
                    _buildSectionTitle('Imagens'),
                    ElevatedButton.icon(
                      onPressed: _pickImages,
                      icon: const Icon(Icons.upload),
                      label: const Text('Adicionar Imagens'),
                    ),
                    const SizedBox(height: 16),
                    if (_images.isNotEmpty)
                      SizedBox(
                        height: 120,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _images.length,
                          itemBuilder: (context, index) {
                            final path = _images[index];
                            final isMain = index == _mainImageIndex;
                            return Stack(
                              children: [
                                Container(
                                  margin: const EdgeInsets.only(right: 8),
                                  width: 100,
                                  height: 100,
                                  decoration: BoxDecoration(
                                    border: isMain
                                        ? Border.all(
                                            color: Colors.blue,
                                            width: 3,
                                          )
                                        : null,
                                    color: Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: kIsWeb
                                      ? const Center(
                                          child: Text('Imagens não renderizadas no navegador'),
                                        )
                                      : Image.file(
                                          File(path),
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
                                  top: 0,
                                  right: 8,
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    child: IconButton(
                                      icon: const Icon(
                                        Icons.close,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                      onPressed: () => setState(() {
                                        _images.removeAt(index);
                                        if (_mainImageIndex >= _images.length)
                                          _mainImageIndex = 0;
                                      }),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  left: 0,
                                  bottom: 0,
                                  child: IconButton(
                                    icon: Icon(
                                      isMain ? Icons.star : Icons.star_border,
                                      color: Colors.yellow,
                                      shadows: const [
                                        Shadow(
                                          blurRadius: 2,
                                          color: Colors.black,
                                        ),
                                      ],
                                    ),
                                    onPressed: () =>
                                        setState(() => _mainImageIndex = index),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
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
