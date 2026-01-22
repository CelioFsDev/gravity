import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gravity/models/product.dart';
import 'package:gravity/models/category.dart';
import 'package:gravity/viewmodels/products_viewmodel.dart';
import 'package:uuid/uuid.dart';
import 'package:file_picker/file_picker.dart';

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
    final p = widget.product;
    _nameController = TextEditingController(text: p?.name ?? '');
    _refController = TextEditingController(text: p?.reference ?? '');
    _skuController = TextEditingController(text: p?.sku ?? '');
    _retailController = TextEditingController(text: p?.retailPrice.toString() ?? '');
    _wholesaleController = TextEditingController(text: p?.wholesalePrice.toString() ?? '');
    _minQtyController = TextEditingController(text: p?.minWholesaleQty.toString() ?? '1');
    _sizesController = TextEditingController(text: p?.sizes.join(', ') ?? '');
    _colorsController = TextEditingController(text: p?.colors.join(', ') ?? '');
    
    _selectedCategoryId = p?.categoryId;
    _isActive = p?.isActive ?? true;
    _isOutOfStock = p?.isOutOfStock ?? false;
    _isOnSale = p?.isOnSale ?? false;
    _images = List.from(p?.images ?? []);
    _mainImageIndex = p?.mainImageIndex ?? 0;
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecione uma categoria')));
      return;
    }

    final product = Product(
      id: widget.product?.id ?? const Uuid().v4(),
      name: _nameController.text,
      reference: _refController.text,
      sku: _skuController.text,
      categoryId: _selectedCategoryId!,
      retailPrice: double.tryParse(_retailController.text) ?? 0.0,
      wholesalePrice: double.tryParse(_wholesaleController.text) ?? 0.0,
      minWholesaleQty: int.tryParse(_minQtyController.text) ?? 1,
      sizes: _sizesController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
      colors: _colorsController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
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
        await ref.read(productsViewModelProvider.notifier).updateProduct(product);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao salvar: $e')));
    }
  }

  Future<void> _pickImages() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.image,
    );
    if (result != null) {
       setState(() {
         _images.addAll(result.files.map((f) => f.path!).toList());
       });
    }
  }

  @override
  Widget build(BuildContext context) {
    final productsState = ref.read(productsViewModelProvider);
    final categories = productsState.hasValue ? productsState.value!.categories : <Category>[];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.product == null ? 'Novo Produto' : 'Editar Produto'),
        actions: [
          IconButton(icon: const Icon(Icons.check), onPressed: _save),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Basic Info
              _buildSectionTitle('Informações Básicas'),
              Row(
                children: [
                   Expanded(flex: 2, child: _buildTextField(_nameController, 'Nome', validator: (v) => v!.isEmpty ? 'Obrigatório' : null)),
                   const SizedBox(width: 16),
                   Expanded(child: _buildTextField(_refController, 'REF', validator: (v) => v!.isEmpty ? 'Obrigatório' : null)),
                   const SizedBox(width: 16),
                   Expanded(child: _buildTextField(_skuController, 'SKU')),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue:
                    categories.any((c) => c.id == _selectedCategoryId)
                        ? _selectedCategoryId
                        : null,
                decoration: const InputDecoration(labelText: 'Categoria', border: OutlineInputBorder()),
                items: categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                onChanged: (val) => setState(() => _selectedCategoryId = val),
                 // Basic add category button integration could go here
              ),
              
              const SizedBox(height: 24),
              
              // Pricing
              _buildSectionTitle('Preços e Estoque'),
              Row(
                children: [
                  Expanded(child: _buildTextField(_retailController, 'Varejo (R\$)', isNumber: true)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildTextField(_wholesaleController, 'Atacado (R\$)', isNumber: true)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildTextField(_minQtyController, 'Mín. Atacado', isNumber: true)),
                ],
              ),
              const SizedBox(height: 24),
              
              // Attributes
              _buildSectionTitle('Atributos'),
              _buildTextField(_sizesController, 'Tamanhos (separados por vírgula)'),
              const SizedBox(height: 16),
              _buildTextField(_colorsController, 'Cores (separados por vírgula)'),
              
              const SizedBox(height: 24),
              
              // Status
              _buildSectionTitle('Status'),
              SwitchListTile(title: const Text('Ativo'), value: _isActive, onChanged: (v) => setState(() => _isActive = v)),
              SwitchListTile(title: const Text('Esgotado'), value: _isOutOfStock, onChanged: (v) => setState(() => _isOutOfStock = v)),
              SwitchListTile(title: const Text('Em Promoção'), value: _isOnSale, onChanged: (v) => setState(() => _isOnSale = v)),

              const SizedBox(height: 24),

              // Images
              _buildSectionTitle('Imagens'),
              ElevatedButton.icon(onPressed: _pickImages, icon: const Icon(Icons.upload), label: const Text('Adicionar Imagens')),
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
                              border: isMain ? Border.all(color: Colors.blue, width: 3) : null,
                              image: DecorationImage(image: FileImage(File(path)), fit: BoxFit.cover),
                            ),
                          ),
                          Positioned(
                            right: 0,
                            child: IconButton(
                              icon: const Icon(Icons.close, color: Colors.red),
                              onPressed: () => setState(() {
                                _images.removeAt(index);
                                if (_mainImageIndex >= _images.length) _mainImageIndex = 0;
                              }),
                            ),
                          ),
                          Positioned(
                            left: 0,
                            bottom: 0,
                            child: IconButton(
                              icon: Icon(isMain ? Icons.star : Icons.star_border, color: Colors.yellow),
                              onPressed: () => setState(() => _mainImageIndex = index),
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
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, {bool isNumber = false, String? Function(String?)? validator}) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      validator: validator,
    );
  }
}
