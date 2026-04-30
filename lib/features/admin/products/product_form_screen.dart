import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:catalogo_ja/core/services/saas_photo_storage_service.dart';
import 'package:catalogo_ja/models/product.dart';
import 'package:catalogo_ja/models/category.dart';
import 'package:catalogo_ja/models/product_image.dart';
import 'package:catalogo_ja/viewmodels/products_viewmodel.dart';
import 'package:uuid/uuid.dart';
import 'package:file_picker/file_picker.dart';
import 'package:catalogo_ja/core/services/photo_classification_service.dart';
import 'package:catalogo_ja/core/services/image_optimizer_service.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter/services.dart';
import 'package:catalogo_ja/ui/theme/app_tokens.dart';
import 'package:catalogo_ja/ui/widgets/app_scaffold.dart';
import 'package:catalogo_ja/ui/widgets/section_card.dart';
import 'package:catalogo_ja/ui/widgets/app_primary_button.dart';
import 'package:catalogo_ja/features/admin/categories/widgets/category_create_modal.dart';
import 'package:go_router/go_router.dart';
import 'package:catalogo_ja/ui/widgets/app_error_view.dart';
import 'package:catalogo_ja/core/error/app_failure.dart';
import 'package:catalogo_ja/viewmodels/tenant_viewmodel.dart';
import 'package:catalogo_ja/viewmodels/auth_viewmodel.dart';
import 'package:catalogo_ja/features/admin/products/widgets/store_override_controls.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProductFormScreen extends ConsumerStatefulWidget {
  final Product? product; // null for Create, non-null for Edit

  const ProductFormScreen({super.key, this.product});

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _PhotoMetaResult {
  final String photoType;
  final String? colorKey;
  final bool isNewColor;

  const _PhotoMetaResult({
    required this.photoType,
    required this.colorKey,
    required this.isNewColor,
  });
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  static const Set<String> _supportedImageExtensions = {
    '.jpg',
    '.jpeg',
    '.png',
    '.webp',
    '.gif',
    '.bmp',
    '.tif',
    '.tiff',
    '.heic',
    '.heif',
    '.avif',
  };

  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();

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

  List<String> _selectedCategoryIds = [];
  String? _selectedCollectionId;
  List<String> _initialCategoryIds = [];
  bool _categorySelectionInitialized = false;
  bool _isActive = true;
  bool _isOutOfStock = false;
  bool _isOnSale = false;
  List<ProductPhoto> _photos = [];
  late final String _draftProductId;
  final Set<String> _pendingWebUploadUrls = <String>{};
  bool _didPersistProduct = false;
  bool _isUploadingWebPhoto = false;
  String _webPhotoUploadMessage = 'Enviando foto...';

  // Multi-Store SaaS Overrides
  bool _isIndividualStoreConfig = false;
  List<String> _unavailableSizes = [];
  List<String> _unavailableColors = [];
  String? _currentStoreId;

  @override
  void initState() {
    super.initState();
    final pr = widget.product;
    _draftProductId = pr?.id ?? const Uuid().v4();
    _nameController = TextEditingController(text: pr?.name ?? '');
    _refController = TextEditingController(text: pr?.ref ?? '');
    _skuController = TextEditingController(text: pr?.sku ?? '');
    final f = NumberFormat.decimalPattern('pt_BR');
    _retailController = TextEditingController(
      text: pr != null ? f.format(pr.priceRetail) : '',
    );
    _wholesaleController = TextEditingController(
      text: pr != null ? f.format(pr.priceWholesale) : '',
    );
    _minQtyController = TextEditingController(
      text: pr?.minWholesaleQty.toString() ?? '1',
    );
    _sizesController = TextEditingController(text: pr?.sizes.join(', ') ?? '');
    _colorsController = TextEditingController(
      text: pr?.colors.join(', ') ?? '',
    );
    _discountController = TextEditingController(
      text: pr?.promoPercent.toString() ?? '0',
    );

    _initialCategoryIds = pr?.categoryIds ?? [];
    _isActive = pr?.isActive ?? true;
    _isOutOfStock = pr?.isOutOfStock ?? false;
    _isOnSale = pr?.promoEnabled ?? false;
    if (pr != null && pr.photos.isNotEmpty) {
      _photos = List<ProductPhoto>.from(pr.photos);
    } else if (pr != null && pr.images.isNotEmpty) {
      final safeIndex = pr.mainImageIndex.clamp(0, pr.images.length - 1);
      _photos = pr.images.asMap().entries.map((entry) {
        final img = entry.value;
        return ProductPhoto(
          path: img.uri,
          colorKey: img.colorTag,
          isPrimary: entry.key == safeIndex || img.label == 'principal',
          photoType: img.label,
        );
      }).toList();
    }
    _photos = _prioritizePrimaryPhoto(_photos);
  }

  void _loadOverrides(String storeId) {
    final pr = widget.product;
    if (pr == null) return;

    final override = pr.storeOverrides[storeId];
    if (override != null) {
      setState(() {
        _isIndividualStoreConfig = true;
        _unavailableSizes = List<String>.from(
          override['unavailableSizes'] ?? [],
        );
        _unavailableColors = List<String>.from(
          override['unavailableColors'] ?? [],
        );

        final f = NumberFormat.decimalPattern('pt_BR');
        if (override['priceRetail'] != null) {
          _retailController.text = f.format(override['priceRetail']);
        }
        if (override['priceWholesale'] != null) {
          _wholesaleController.text = f.format(override['priceWholesale']);
        }
        if (override['isActive'] != null) {
          _isActive = override['isActive'];
        }
      });
    }
  }

  List<String> _getUnavailableSizes(List<String> allSizes) {
    return _unavailableSizes;
  }

  List<String> _getUnavailableColors(List<String> allColors) {
    return _unavailableColors;
  }

  @override
  void dispose() {
    if (kIsWeb && !_didPersistProduct && _pendingWebUploadUrls.isNotEmpty) {
      unawaited(_cleanupPendingWebUploads());
    }
    _nameController.dispose();
    _refController.dispose();
    _skuController.dispose();
    _retailController.dispose();
    _wholesaleController.dispose();
    _minQtyController.dispose();
    _sizesController.dispose();
    _colorsController.dispose();
    _discountController.dispose();
    _scrollController.dispose();
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
    if (!_formKey.currentState!.validate()) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
      return;
    }

    final currentTenant = ref.read(currentTenantProvider).value;
    final tenantId = currentTenant?.id;

    final requiresCollection = widget.product == null;
    if (requiresCollection && _selectedCollectionId == null) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A cole\u00e7\u00e3o \u00e9 obrigat\u00f3ria'),
        ),
      );
      return;
    }

    final photosForSave = _normalizePhotosForSave();
    final imagesForSave = _imagesFromPhotos(photosForSave);
    final mainImageIndex = _mainIndexFromPhotos(photosForSave);

    // Combine Collection + Categories
    final categoryIds = <String>[
      ?_selectedCollectionId,
      ..._selectedCategoryIds,
    ];
    var product = Product(
      id: _draftProductId,
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
      description: widget.product?.description,
      tenantId: tenantId ?? widget.product?.tenantId,
      storeOverrides: widget.product?.storeOverrides ?? {},
    );

    // SaaS Overrides Logic
    if (_isIndividualStoreConfig && _currentStoreId != null) {
      final override = {
        'priceRetail': product.priceRetail,
        'priceWholesale': product.priceWholesale,
        'isActive': _isActive,
        'unavailableSizes': _getUnavailableSizes(product.sizes),
        'unavailableColors': _getUnavailableColors(product.colors),
        'updatedAt': DateTime.now().toIso8601String(),
      };

      final newOverrides = Map<String, Map<String, dynamic>>.from(
        product.storeOverrides,
      );
      newOverrides[_currentStoreId!] = override;

      product = product.copyWith(storeOverrides: newOverrides);
    }

    try {
      if (kIsWeb && _pendingWebUploadUrls.isNotEmpty) {
        await _finalizePendingWebUploads();
      }
      if (widget.product == null) {
        await ref.read(productsViewModelProvider.notifier).addProduct(product);
      } else {
        await ref
            .read(productsViewModelProvider.notifier)
            .updateProduct(product);
      }
      _didPersistProduct = true;
      _pendingWebUploadUrls.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Salvo localmente! Lembre-se de Sincronizar para enviar à nuvem.',
            ),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 4),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        final failure = e is AppFailure
            ? e
            : e.toAppFailure(action: 'save', entity: 'Product');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(failure.message),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _addPrimaryPhoto() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.any,
        withData: kIsWeb,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;

      final rawClassification = ref
          .read(photoClassificationServiceProvider.notifier)
          .classifyFileName(file.name);
      final classification = rawClassification?.photoType == 'P'
          ? rawClassification
          : null;

      final resolved = await _processPickedImage(
        file,
        classification: classification,
      );
      if (resolved == null || !mounted) return;

      await _replacePhotosWithCleanup((currentPhotos) {
        final nextPhotos = currentPhotos
            .map((p) => p.copyWith(isPrimary: false))
            .toList();

        final newPhoto = ProductPhoto(
          path: resolved,
          photoType: 'P',
          isPrimary: true,
        );

        final existingIdx = nextPhotos.indexWhere((p) => p.photoType == 'P');
        if (existingIdx != -1) {
          nextPhotos[existingIdx] = newPhoto;
        } else {
          nextPhotos.insert(0, newPhoto);
        }
        return nextPhotos;
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
        type: FileType.any,
        withData: kIsWeb,
      );
      if (result == null || result.files.isEmpty) return;

      for (var file in result.files) {
        final classification = ref
            .read(photoClassificationServiceProvider.notifier)
            .classifyFileName(file.name);

        final resolved = await _processPickedImage(
          file,
          classification: classification,
        );
        if (resolved == null || !mounted) continue;

        String? colorKey;
        bool isPrimary = false;
        String? photoType;

        if (classification != null) {
          photoType = classification.photoType;
          colorKey = classification.colorName;
          isPrimary = photoType == 'P';
        } else {
          final meta = await _showPhotoMetaDialog(context, initialType: 'D1');
          if (meta == null || !mounted) continue;
          photoType = meta.photoType;
          colorKey = meta.colorKey;
          isPrimary = photoType == 'P';

          if (meta.isNewColor && meta.colorKey != null) {
            _appendColorOption(meta.colorKey!);
          }

          if (photoType == 'C') {
            photoType = _nextAvailableColorSlot();
          }
        }

        await _replacePhotosWithCleanup((currentPhotos) {
          var nextPhotos = List<ProductPhoto>.from(currentPhotos);
          if (isPrimary) {
            nextPhotos = nextPhotos
                .map((p) => p.copyWith(isPrimary: false))
                .toList();
          }

          final newPhoto = ProductPhoto(
            path: resolved,
            colorKey: colorKey,
            photoType: photoType,
            isPrimary: isPrimary,
          );

          if (photoType != null && photoType.startsWith('C')) {
            nextPhotos = ref
                .read(photoClassificationServiceProvider.notifier)
                .organizeColors(nextPhotos, newPhoto);
          } else if (photoType != null) {
            final existingIdx = nextPhotos.indexWhere(
              (p) => p.photoType == photoType,
            );
            if (existingIdx != -1) {
              nextPhotos[existingIdx] = newPhoto;
            } else {
              nextPhotos.add(newPhoto);
            }
          } else {
            nextPhotos.add(newPhoto);
          }
          return nextPhotos;
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

  /// Adiciona fotos de detalhe (D1 / D2) sem mostrar o diálogo de meta.
  Future<void> _addDetailPhotos() async {
    final currentDetails = _photos.where(_isDetailPhoto).length;
    if (currentDetails >= 2) return;

    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: currentDetails == 0,
        type: FileType.any,
        withData: kIsWeb,
      );
      if (result == null || result.files.isEmpty) return;

      for (var file in result.files) {
        final rawClassification = ref
            .read(photoClassificationServiceProvider.notifier)
            .classifyFileName(file.name);
        final classification =
            rawClassification?.photoType == 'D1' ||
                rawClassification?.photoType == 'D2'
            ? rawClassification
            : null;

        final resolved = await _processPickedImage(
          file,
          classification: classification,
        );
        if (resolved == null || !mounted) break;

        final existingDetails = _photos.where(_isDetailPhoto).length;
        if (existingDetails >= 2) break;

        final classifiedType = classification?.photoType;
        final nextType = classifiedType == 'D1' || classifiedType == 'D2'
            ? classifiedType
            : (existingDetails == 0 ? 'D1' : 'D2');
        await _replacePhotosWithCleanup((currentPhotos) {
          final nextPhotos = List<ProductPhoto>.from(currentPhotos);
          final newPhoto = ProductPhoto(
            path: resolved,
            photoType: nextType,
            isPrimary: false,
          );
          final existingIdx = nextPhotos.indexWhere(
            (p) => p.photoType == nextType,
          );
          if (existingIdx != -1) {
            nextPhotos[existingIdx] = newPhoto;
          } else {
            nextPhotos.add(newPhoto);
          }
          return nextPhotos;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao adicionar foto de detalhe: $e')),
        );
      }
    }
  }

  /// Adiciona fotos de cor (C1 – C4) solicitando o nome da cor.
  Future<void> _addColorPhotos() async {
    final currentColors = _photos.where(_isColorPhoto).length;
    if (currentColors >= 4) return;

    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.any,
        withData: kIsWeb,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;

      // Try to auto-classify first
      final rawClassification = ref
          .read(photoClassificationServiceProvider.notifier)
          .classifyFileName(file.name);
      final classification =
          rawClassification?.photoType.startsWith('C') == true
          ? rawClassification
          : null;

      String? colorKey = classification?.colorName;
      String? photoType = classification?.photoType;
      PhotoClassification? effectiveClassification = classification;

      // If auto-classification didn't give a color type, ask the user
      if (photoType == null || !photoType.startsWith('C')) {
        final meta = await _showPhotoMetaDialog(
          context,
          initialType: 'C',
          allowTypeSelection: false,
        );
        if (meta == null || !mounted) return;
        colorKey = meta.colorKey;

        if (meta.isNewColor && meta.colorKey != null) {
          _appendColorOption(meta.colorKey!);
        }

        photoType = _nextAvailableColorSlot();
        effectiveClassification = _buildManualClassification(
          fileName: file.name,
          photoType: photoType,
          colorKey: colorKey,
        );
      }

      final resolved = await _processPickedImage(
        file,
        classification: effectiveClassification,
      );
      if (resolved == null || !mounted) return;

      await _replacePhotosWithCleanup((currentPhotos) {
        final newPhoto = ProductPhoto(
          path: resolved,
          colorKey: colorKey,
          photoType: photoType,
          isPrimary: false,
        );
        return ref
            .read(photoClassificationServiceProvider.notifier)
            .organizeColors(List<ProductPhoto>.from(currentPhotos), newPhoto);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao adicionar foto de cor: $e')),
        );
      }
    }
  }

  Future<_PhotoMetaResult?> _showPhotoMetaDialog(
    BuildContext context, {
    String initialType = 'C',
    bool allowTypeSelection = true,
  }) async {
    final colors = _parseColorOptions();
    String selectedType = initialType;
    String selectedColor = colors.isNotEmpty ? colors.first : '__new__';
    final newColorController = TextEditingController();

    final result = await showDialog<_PhotoMetaResult>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Text('Configurar foto'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (allowTypeSelection) ...[
                DropdownButtonFormField<String>(
                  initialValue: selectedType,
                  decoration: const InputDecoration(labelText: 'Tipo da foto'),
                  items: const [
                    DropdownMenuItem(value: 'P', child: Text('Foto principal')),
                    DropdownMenuItem(value: 'D1', child: Text('Detalhe 1')),
                    DropdownMenuItem(value: 'D2', child: Text('Detalhe 2')),
                    DropdownMenuItem(value: 'C', child: Text('Foto de cor')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setModalState(() => selectedType = value);
                  },
                ),
                const SizedBox(height: 12),
              ],
              if (selectedType == 'C')
                DropdownButtonFormField<String>(
                  initialValue: selectedColor,
                  decoration: const InputDecoration(labelText: 'Cor'),
                  items: [
                    ...colors.map(
                      (c) => DropdownMenuItem(value: c, child: Text(c)),
                    ),
                    const DropdownMenuItem(
                      value: '__new__',
                      child: Text('Adicionar nova cor'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setModalState(() => selectedColor = value);
                  },
                ),
              if (selectedType == 'C' && selectedColor == '__new__') ...[
                const SizedBox(height: 12),
                TextField(
                  controller: newColorController,
                  decoration: const InputDecoration(
                    labelText: 'Nova cor',
                    hintText: 'Ex: PRETO',
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                final photoType = selectedType;
                String? colorKey;
                bool isNewColor = false;
                if (photoType == 'C') {
                  if (selectedColor == '__new__') {
                    final text = newColorController.text.trim();
                    if (text.isEmpty) return;
                    colorKey = text.toUpperCase();
                    isNewColor = true;
                  } else {
                    colorKey = selectedColor.toUpperCase();
                  }
                }
                Navigator.pop(
                  dialogContext,
                  _PhotoMetaResult(
                    photoType: photoType,
                    colorKey: colorKey,
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

  String _nextAvailableColorSlot() {
    final usedTypes = _photos
        .where((p) => p.photoType?.startsWith('C') ?? false)
        .map((p) => p.photoType!)
        .toSet();
    const slots = ['C1', 'C2', 'C3', 'C4'];
    return slots.firstWhere((s) => !usedTypes.contains(s), orElse: () => 'C4');
  }

  void _appendColorOption(String colorKey) {
    final current = _parseColorOptions().toSet();
    if (current.contains(colorKey)) return;
    final sep = _colorsController.text.trim().isEmpty ? '' : ', ';
    _colorsController.text = '${_colorsController.text.trim()}$sep$colorKey';
  }

  PhotoClassification _buildManualClassification({
    required String fileName,
    required String photoType,
    String? colorKey,
  }) {
    final extension = p.extension(fileName).toLowerCase().replaceFirst('.', '');
    final productRef = _refController.text.trim().isNotEmpty
        ? _refController.text.trim()
        : const Uuid().v4().substring(0, 8);
    final service = ref.read(photoClassificationServiceProvider.notifier);
    return PhotoClassification(
      ref: productRef,
      photoType: photoType,
      colorName: colorKey,
      standardName: service.buildInternalName(
        productRef,
        photoType,
        colorKey,
        extension.isEmpty ? 'jpg' : extension,
      ),
    );
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

  Future<String?> _processPickedImage(
    PlatformFile file, {
    PhotoClassification? classification,
  }) async {
    try {
      final ext = (file.extension?.toLowerCase() ?? 'jpg').replaceAll('.', '');
      final isImage = _supportedImageExtensions.contains('.$ext');

      if (!isImage) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Arquivo "${file.name}" ignorado (não é imagem).'),
            ),
          );
        }
        return null;
      }

      if (kIsWeb) {
        final bytes = file.bytes;
        if (bytes == null) return null;

        final tenantId = ref.read(currentTenantProvider).value?.id;
        if (tenantId == null || tenantId.isEmpty) {
          throw Exception('Empresa não identificada para enviar imagem.');
        }

        final storageService = ref.read(saasPhotoStorageProvider);
        if (mounted) {
          setState(() {
            _isUploadingWebPhoto = true;
            _webPhotoUploadMessage = 'Enviando ${file.name}...';
          });
        }
        final uploadedUrl = await storageService.uploadProductImage(
          tenantId: tenantId,
          productId: _draftProductId,
          localPath: file.name,
          bytes: bytes,
          label: classification?.photoType,
          temporary: true,
        );
        _pendingWebUploadUrls.add(uploadedUrl);
        if (mounted) {
          setState(() {
            _isUploadingWebPhoto = false;
            _webPhotoUploadMessage = 'Enviando foto...';
          });
        }
        return uploadedUrl;
      }

      // 📱 MOBILE/DESKTOP: Salvamento em arquivo local persistente
      final resolved = await _copyFileToPersistentStorage(
        file,
        classification: classification,
      );
      return resolved;
    } catch (e) {
      if (mounted && _isUploadingWebPhoto) {
        setState(() {
          _isUploadingWebPhoto = false;
          _webPhotoUploadMessage = 'Enviando foto...';
        });
      }
      debugPrint('Erro ao processar imagem escolhida: $e');
      return null;
    }
  }

  List<ProductImage> _imagesFromPhotos(List<ProductPhoto> photos) {
    return photos.map((p) => p.toProductImage()).toList();
  }

  List<ProductPhoto> _normalizePhotosForSave() {
    if (_photos.isEmpty) return const [];
    return _prioritizePrimaryPhoto(_dedupePhotosByPath(_photos));
  }

  int _mainIndexFromPhotos(List<ProductPhoto> photos) {
    final typePrimaryIndex = photos.indexWhere((p) => p.photoType == 'P');
    if (typePrimaryIndex >= 0) return typePrimaryIndex;
    final index = photos.indexWhere((p) => p.isPrimary);
    return index >= 0 ? index : 0;
  }

  List<ProductPhoto> _prioritizePrimaryPhoto(List<ProductPhoto> photos) {
    if (photos.isEmpty) return const [];
    final updated = List<ProductPhoto>.from(photos);

    // 1. Tenta encontrar a foto explicitamente marcada como 'P' (Principal)
    var primaryIndex = updated.indexWhere((p) => p.photoType == 'P');

    // 2. Se não achar 'P', tenta encontrar qualquer uma marcada como isPrimary
    if (primaryIndex < 0) {
      primaryIndex = updated.indexWhere((p) => p.isPrimary);
    }

    // 🚀 MUDANÇA CRUCIAL: Se não houver nenhuma marcada, NÃO force a primeira (índice 0).
    // Deixe o slot principal vazio até que o usuário adicione uma.
    if (primaryIndex < 0) {
      return updated.map((p) => p.copyWith(isPrimary: false)).toList();
    }

    // Garante que apenas a escolhida seja isPrimary
    for (var i = 0; i < updated.length; i++) {
      updated[i] = updated[i].copyWith(isPrimary: i == primaryIndex);
    }

    // Move a principal para o topo da lista interna para facilitar o processamento
    if (primaryIndex > 0) {
      final primary = updated.removeAt(primaryIndex);
      updated.insert(0, primary);
    }
    return updated;
  }

  bool _isPrimaryPhoto(ProductPhoto photo) {
    return photo.photoType == 'P' || photo.isPrimary;
  }

  bool _isDetailPhoto(ProductPhoto photo) {
    return photo.photoType == 'D1' || photo.photoType == 'D2';
  }

  bool _isColorPhoto(ProductPhoto photo) {
    final type = photo.photoType?.trim().toUpperCase();
    if (type == null) return false;
    return RegExp(r'^C[1-4]$').hasMatch(type) || type == 'C';
  }

  List<ProductPhoto> _dedupePhotosByPath(List<ProductPhoto> photos) {
    final unique = <String, ProductPhoto>{};
    for (final photo in photos) {
      unique.putIfAbsent(photo.path, () => photo);
    }
    return unique.values.toList();
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

  Future<void> _removePhoto(int index) async {
    if (index < 0 || index >= _photos.length) return;
    final removedPhoto = _photos[index];
    setState(() {
      final removedPrimary = removedPhoto.isPrimary;
      _photos.removeAt(index);
      if (removedPrimary && _photos.isNotEmpty) {
        _photos = _photos.asMap().entries.map((entry) {
          return entry.value.copyWith(isPrimary: entry.key == 0);
        }).toList();
      }
    });

    if (kIsWeb && _pendingWebUploadUrls.remove(removedPhoto.path)) {
      try {
        await ref
            .read(saasPhotoStorageProvider)
            .deleteFileByUrl(removedPhoto.path);
      } catch (e) {
        debugPrint('Erro ao apagar upload temporário: $e');
      }
    }
  }

  Future<void> _replacePhotosWithCleanup(
    List<ProductPhoto> Function(List<ProductPhoto>) transform,
  ) async {
    final previousPhotos = List<ProductPhoto>.from(_photos);
    final nextPhotos = transform(previousPhotos);
    final nextPaths = nextPhotos.map((p) => p.path).toSet();

    setState(() {
      _photos = nextPhotos;
    });

    for (final photo in previousPhotos) {
      if (!nextPaths.contains(photo.path)) {
        await _deletePendingWebUploadIfNeeded(photo.path);
      }
    }
  }

  Future<void> _deletePendingWebUploadIfNeeded(String path) async {
    if (!kIsWeb || !_pendingWebUploadUrls.remove(path)) return;
    try {
      await ref.read(saasPhotoStorageProvider).deleteFileByUrl(path);
    } catch (e) {
      debugPrint('Erro ao apagar upload temporário: $e');
    }
  }

  Future<void> _finalizePendingWebUploads() async {
    final storageService = ref.read(saasPhotoStorageProvider);
    for (final url in _pendingWebUploadUrls.toList()) {
      await storageService.finalizeProductImage(url);
    }
  }

  Future<void> _cleanupPendingWebUploads() async {
    final storageService = ref.read(saasPhotoStorageProvider);
    for (final url in _pendingWebUploadUrls.toList()) {
      try {
        await storageService.deleteFileByUrl(url);
      } catch (e) {
        debugPrint('Erro ao limpar upload temporário: $e');
      }
    }
  }

  Future<String?> _copyFileToPersistentStorage(
    PlatformFile file, {
    PhotoClassification? classification,
  }) async {
    try {
      Future<Directory> resolveImagesDir() async {
        final baseDir = await getApplicationDocumentsDirectory();
        final imagesDir = Directory(p.join(baseDir.path, 'product_images'));
        if (!await imagesDir.exists()) {
          await imagesDir.create(recursive: true);
        }
        return imagesDir;
      }

      // Windows/Desktop priority: use path if available
      if (!kIsWeb && file.path != null) {
        final imagesDir = await resolveImagesDir();

        final extension = p.extension(file.name).isNotEmpty
            ? p.extension(file.name).toLowerCase()
            : '.jpg';

        final String fileName =
            classification?.standardName ?? '${const Uuid().v4()}$extension';
        final String targetPath = p.join(imagesDir.path, fileName);

        debugPrint('Reading from path: ${file.path}');
        final sourceFile = File(file.path!);
        if (!await sourceFile.exists()) {
          debugPrint('Error: Source file does not exist');
          return null;
        }

        final normalizedSourceDir = p.normalize(p.dirname(sourceFile.path));
        final normalizedImagesDir = p.normalize(imagesDir.path);
        if (normalizedSourceDir == normalizedImagesDir) {
          return sourceFile.path;
        }

        // Usa o serviço centralizado para comprimir a imagem
        final optimizer = ref.read(imageOptimizerServiceProvider.notifier);
        final compressedFile = await optimizer.compressImage(sourceFile);
        final fileToSave = compressedFile ?? sourceFile;

        try {
          await fileToSave.copy(targetPath);
        } catch (_) {
          if (fileToSave.path != sourceFile.path) {
            await sourceFile.copy(targetPath);
          } else {
            rethrow;
          }
        }

        if (await File(targetPath).exists()) {
          debugPrint('Successfully saved (optimized) to: $targetPath');
          return targetPath;
        }
      } else if (file.bytes != null) {
        // Fallback for Web or byte-only results
        debugPrint('Processing from bytes (length: ${file.bytes!.length})');
        if (kIsWeb) {
          final mimeType = _inferMimeType(file.name);
          final encoded = base64Encode(file.bytes!);
          return 'data:$mimeType;base64,$encoded';
        }

        final imagesDir = await resolveImagesDir();

        final optimizer = ref.read(imageOptimizerServiceProvider.notifier);
        final compressedBytes = await optimizer.compressBytes(file.bytes!);
        final bytesToSave = compressedBytes ?? file.bytes!;

        final extension = p.extension(file.name).isNotEmpty
            ? p.extension(file.name).toLowerCase()
            : '.jpg';
        final String targetPath = p.join(
          imagesDir.path,
          '${const Uuid().v4()}$extension',
        );

        await File(targetPath).writeAsBytes(bytesToSave);
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
              'Aten\u00e7\u00e3o: O salvamento de fotos n\u00e3o \u00e9 suportado no Navegador. Use a vers\u00e3o Windows Desktop.',
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

  String _inferMimeType(String fileName) {
    switch (p.extension(fileName).toLowerCase()) {
      case '.png':
        return 'image/png';
      case '.webp':
        return 'image/webp';
      case '.gif':
        return 'image/gif';
      case '.bmp':
        return 'image/bmp';
      case '.svg':
        return 'image/svg+xml';
      case '.avif':
        return 'image/avif';
      case '.heic':
      case '.heif':
        return 'image/heic';
      case '.tif':
      case '.tiff':
        return 'image/tiff';
      case '.jpg':
      case '.jpeg':
      default:
        return 'image/jpeg';
    }
  }

  @override
  Widget build(BuildContext context) {
    final productsState = ref.watch(productsViewModelProvider);
    final syncProgress = ref.watch(syncProgressProvider);

    // 🤫 Só mostramos se estiver sincronizando E NÃO for um download de fundo (Baixando...)
    final shouldShowOverlay =
        syncProgress.isSyncing && !syncProgress.message.contains('Baixando');

    productsState.showSnackbarOnError(context);

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

    return Stack(
      children: [
        AppScaffold(
          title: widget.product == null ? 'Novo Produto' : 'Editar Produto',
          subtitle: widget.product == null
              ? 'Preencha os dados do novo item'
              : 'Atualize as informa\u00e7\u00f5es do produto',
          useAppBar: true,
          actions: [
            IconButton(
              tooltip: 'Menu principal',
              icon: const Icon(Icons.home_outlined),
              onPressed: () => context.go('/admin/products'),
            ),
          ],
          body: Form(
            key: _formKey,
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTokens.space24,
                    ),
                    children: [
                      const SizedBox(height: AppTokens.space24),
                      if (_currentStoreId == null)
                        Builder(
                          builder: (context) {
                            final userEmail = ref
                                .watch(authViewModelProvider)
                                .valueOrNull
                                ?.email;
                            if (userEmail != null) {
                              FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(userEmail.toLowerCase().trim())
                                  .get()
                                  .then((doc) {
                                    final sid =
                                        doc.data()?['currentStoreId']
                                            as String?;
                                    if (sid != null && mounted) {
                                      setState(() {
                                        _currentStoreId = sid;
                                        _loadOverrides(sid);
                                      });
                                    }
                                  });
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      if (_currentStoreId != null)
                        StoreOverrideControls(
                          storeId: _currentStoreId!,
                          isIndividual: _isIndividualStoreConfig,
                          onToggleIndividual: (v) =>
                              setState(() => _isIndividualStoreConfig = v),
                          allSizes: _sizesController.text
                              .split(',')
                              .map((e) => e.trim())
                              .where((e) => e.isNotEmpty)
                              .toList(),
                          allColors: _colorsController.text
                              .split(',')
                              .map((e) => e.trim())
                              .where((e) => e.isNotEmpty)
                              .toList(),
                          unavailableSizes: _unavailableSizes,
                          unavailableColors: _unavailableColors,
                          onToggleSize: (size, unavailable) {
                            setState(() {
                              if (unavailable) {
                                if (!_unavailableSizes.contains(size)) {
                                  _unavailableSizes.add(size);
                                }
                              } else {
                                _unavailableSizes.remove(size);
                              }
                            });
                          },
                          onToggleColor: (color, unavailable) {
                            setState(() {
                              if (unavailable) {
                                if (!_unavailableColors.contains(color)) {
                                  _unavailableColors.add(color);
                                }
                              } else {
                                _unavailableColors.remove(color);
                              }
                            });
                          },
                        ),
                      SectionCard(
                        title: 'Informa\u00e7\u00f5es B\u00e1sicas',
                        child: Column(
                          children: [
                            _buildTextField(
                              _nameController,
                              'Nome do Produto',
                              validator: (v) =>
                                  v!.isEmpty ? 'Obrigat\u00f3rio' : null,
                            ),
                            const SizedBox(height: AppTokens.space16),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildTextField(
                                    _refController,
                                    'REF (C\u00f3digo)',
                                    validator: (v) {
                                      if (v == null || v.isEmpty) {
                                        return 'Obrigat\u00f3rio';
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
                                        if (exists) return 'Indispon\u00edvel';
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
                        title: 'Organiza\u00e7\u00e3o',
                        child: _buildOrganizationSection(
                          context,
                          collections,
                          productTypes,
                        ),
                      ),
                      const SizedBox(height: AppTokens.space24),
                      SectionCard(
                        title: 'Pre\u00e7os e Estoque',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _buildTextField(
                                    _retailController,
                                    'Pre\u00e7o Varejo',
                                    isPrice: true,
                                  ),
                                ),
                                const SizedBox(width: AppTokens.space12),
                                Expanded(
                                  child: _buildTextField(
                                    _wholesaleController,
                                    'Pre\u00e7o Atacado',
                                    isPrice: true,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppTokens.space16),
                            _buildTextField(
                              _minQtyController,
                              'Quantidade M\u00ednima para Atacado',
                              isNumber: true,
                            ),
                            const SizedBox(height: AppTokens.space12),
                            Text(
                              'O pre\u00e7o atacado ser\u00e1 aplicado automaticamente no carrinho para quantidades maiores que o m\u00ednimo.',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppTokens.space24),
                      SectionCard(
                        title: 'Varia\u00e7\u00f5es (Opcional)',
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
                      SectionCard(
                        title: 'Disponibilidade e Promo\u00e7\u00e3o',
                        child: Column(
                          children: [
                            _buildSwitchTile(
                              'Produto Ativo no Cat\u00e1logo',
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
                              'Em Promo\u00e7\u00e3o',
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
        ),
        if (shouldShowOverlay) _buildSavingOverlay(syncProgress),
        if (_isUploadingWebPhoto) _buildWebPhotoUploadOverlay(),
      ],
    );
  }

  Widget _buildWebPhotoUploadOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.35),
      child: Center(
        child: SectionCard(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTokens.space24,
              vertical: AppTokens.space16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: AppTokens.accentBlue,
                  ),
                ),
                const SizedBox(height: AppTokens.space16),
                Text(
                  _webPhotoUploadMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: AppTokens.space8),
                Text(
                  'A foto está sendo enviada para o Firebase.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSavingOverlay(SyncProgress progress) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      color: Colors.black.withOpacity(0.7),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 40),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: isDark ? AppTokens.surfaceDark : Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(
                  strokeWidth: 4,
                  valueColor: AlwaysStoppedAnimation(AppTokens.electricBlue),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                progress.message,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: progress.progress,
                  backgroundColor: (isDark ? Colors.white : Colors.black)
                      .withOpacity(0.05),
                  valueColor: const AlwaysStoppedAnimation(
                    AppTokens.electricBlue,
                  ),
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '${(progress.progress * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.95),
        border: Border(
          top: BorderSide(
            color: (isDark ? Colors.white : Colors.black).withOpacity(0.08),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: AppPrimaryButton(
          label: widget.product == null ? 'CRIAR PRODUTO' : 'SALVAR ALTERAÇÕES',
          onPressed: _save,
          icon: Icons.check_circle_outline_rounded,
        ),
      ),
    );
  }

  Widget _buildImagesSection() {
    // Detect primary by type 'P' first, fallback to isPrimary flag
    final photoP =
        _photos.where((p) => p.photoType == 'P').firstOrNull ??
        _photos.where((p) => p.isPrimary).firstOrNull;
    final primaryPath = photoP?.path;

    final detailPhotos = _photos
        .where((photo) => _isDetailPhoto(photo) && photo.path != primaryPath)
        .toList();

    final colorPhotos = _photos
        .where((photo) => _isColorPhoto(photo) && photo.path != primaryPath)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // --- 1. Foto Principal ---
        SectionCard(
          title: 'Foto Principal',
          child: Column(
            children: [
              if (photoP != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SizedBox(
                    width: 140,
                    height: 140,
                    child: _buildPhotoTile(
                      photoP,
                      key: ValueKey('primary_${photoP.path}'),
                      onRemove: () => _removePhoto(_photos.indexOf(photoP)),
                    ),
                  ),
                ),
              Center(
                child: AppPrimaryButton(
                  onPressed: _addPrimaryPhoto,
                  icon: photoP == null
                      ? Icons.add_a_photo_rounded
                      : Icons.refresh_rounded,
                  label: photoP == null ? 'ADICIONAR FOTO' : 'TROCAR FOTO',
                ),
              ),
              if (photoP == null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Foto frontal do produto — aparece como capa no catálogo.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppTokens.space24),

        // --- 2. Fotos de Detalhes ---
        SectionCard(
          title: 'Fotos de Detalhes (D1 / D2)',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Fotos secundárias do produto (ex: costas, lateral). Máx. 2.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 110,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    if (detailPhotos.length < 2)
                      _buildAddTile(
                        label: '+ Detalhe',
                        onTap: _addDetailPhotos,
                      ),
                    if (detailPhotos.isNotEmpty) const SizedBox(width: 12),
                    ...detailPhotos.asMap().entries.map((entry) {
                      final photo = entry.value;
                      final globalIndex = _photos.indexOf(photo);
                      return Padding(
                        key: ValueKey('detail_${photo.path}_${entry.key}'),
                        padding: const EdgeInsets.only(right: 12),
                        child: SizedBox(
                          width: 110,
                          child: _buildPhotoTile(
                            photo,
                            key: ValueKey('tile_d_${photo.path}'),
                            onRemove: () => _removePhoto(globalIndex),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTokens.space24),

        // --- 3. Fotos de Cores ---
        SectionCard(
          title: 'Fotos de Cores (C1 – C4)',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Fotos de variações de cor. Máx. 4 (aparecem como miniaturas no catálogo).',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 110,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    if (colorPhotos.length < 4)
                      _buildAddTile(label: '+ Cor', onTap: _addColorPhotos),
                    if (colorPhotos.isNotEmpty) const SizedBox(width: 12),
                    ...colorPhotos.asMap().entries.map((entry) {
                      final photo = entry.value;
                      // Encontra o índice real na lista global _photos
                      final globalIndex = _photos.indexOf(photo);
                      return Padding(
                        key: ValueKey('color_${photo.path}_${entry.key}'),
                        padding: const EdgeInsets.only(right: 12),
                        child: SizedBox(
                          width: 110,
                          child: _buildPhotoTile(
                            photo,
                            key: ValueKey('tile_c_${photo.path}'),
                            onRemove: () => _removePhoto(globalIndex),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAddSecondaryTile() {
    return _buildAddTile(label: '+ Foto', onTap: _addSecondaryPhotos);
  }

  Widget _buildAddTile({required String label, required VoidCallback onTap}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 110,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    Colors.white.withOpacity(0.05),
                    Colors.white.withOpacity(0.02),
                  ]
                : [
                    AppTokens.electricBlue.withOpacity(0.05),
                    AppTokens.electricBlue.withOpacity(0.01),
                  ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark
                ? Colors.white10
                : AppTokens.electricBlue.withOpacity(0.1),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark
                    ? AppTokens.vibrantCyan.withOpacity(0.1)
                    : AppTokens.electricBlue.withOpacity(0.1),
              ),
              child: Icon(
                Icons.add_a_photo_rounded,
                color: isDark ? AppTokens.vibrantCyan : AppTokens.electricBlue,
                size: 20,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white60 : Colors.black54,
                letterSpacing: 0.5,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 10,
            color: isDark ? Colors.white38 : Colors.black38,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: 'Digite $label...',
            hintStyle: TextStyle(
              color: isDark ? Colors.white24 : Colors.black26,
              fontSize: 14,
            ),
            filled: true,
            fillColor: isDark ? Colors.white.withOpacity(0.03) : Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: isDark ? Colors.white10 : Colors.black12,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: AppTokens.electricBlue,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: AppTokens.accentRed,
                width: 1,
              ),
            ),
          ),
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black87,
          ),
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

  Widget _buildPhotoTile(
    ProductPhoto photo, {
    Key? key,
    VoidCallback? onRemove,
  }) {
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
          ),
          clipBehavior: Clip.antiAlias,
          child: _buildPhotoPreview(photo.path),
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
          top: 0,
          right: 0,
          child: GestureDetector(
            onTap: onRemove ?? () => _removePhoto(_photos.indexOf(photo)),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTokens.accentRed.withOpacity(0.9),
                shape: BoxShape.circle,
                boxShadow: [AppTokens.shadowSm],
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(Icons.close, size: 16, color: Colors.white),
            ),
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

  Widget _buildPhotoPreview(String path) {
    if (path.startsWith('data:')) {
      final commaIndex = path.indexOf(',');
      if (commaIndex != -1 && commaIndex + 1 < path.length) {
        try {
          final bytes = base64Decode(path.substring(commaIndex + 1));
          return Image.memory(
            bytes,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (_, _, _) => _buildPhotoPlaceholder(),
          );
        } catch (_) {
          return _buildPhotoPlaceholder();
        }
      }
      return _buildPhotoPlaceholder();
    }

    if (path.startsWith('http://') ||
        path.startsWith('https://') ||
        path.startsWith('blob:')) {
      return Image.network(
        path,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, _, _) => _buildPhotoPlaceholder(),
      );
    }

    if (!kIsWeb) {
      return Image.file(
        File(path),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, _, _) => _buildPhotoPlaceholder(),
      );
    }

    return _buildPhotoPlaceholder();
  }

  Widget _buildPhotoPlaceholder() {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Icon(
        Icons.image_not_supported_outlined,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
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
              'Pre\u00e7o Promocional: ${f.format(value)}',
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
                  labelText: 'Cole\u00e7\u00e3o (Obrigat\u00f3rio)',
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
              tooltip: 'Nova Cole\u00e7\u00e3o',
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
              'Nenhuma categoria dispon\u00edvel.',
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
