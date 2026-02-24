import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:catalogo_ja/models/category.dart';
import 'package:catalogo_ja/ui/theme/app_tokens.dart';
import 'package:catalogo_ja/ui/widgets/app_primary_button.dart';
import 'package:catalogo_ja/ui/widgets/app_scaffold.dart';
import 'package:catalogo_ja/ui/widgets/section_card.dart';
import 'package:catalogo_ja/viewmodels/categories_viewmodel.dart';
import 'package:catalogo_ja/core/services/image_optimizer_service.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class CollectionFormScreen extends ConsumerStatefulWidget {
  final String? collectionId;

  const CollectionFormScreen({super.key, this.collectionId});

  @override
  ConsumerState<CollectionFormScreen> createState() =>
      _CollectionFormScreenState();
}

class _CollectionFormScreenState extends ConsumerState<CollectionFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _slugController;

  bool _isActive = true;
  bool _isEdit = false;
  String? _coverMiniPath;
  String? _coverPagePath;
  bool _slugTouched = false;

  @override
  void initState() {
    super.initState();
    _isEdit = widget.collectionId != null;
    _nameController = TextEditingController();
    _slugController = TextEditingController();

    if (_isEdit) {
      _loadCollectionData();
    }

    _nameController.addListener(_onNameChanged);
  }

  void _loadCollectionData() {
    // We need to wait for provider to be ready or fetch data.
    // Since we are likely navigating from list, data might be available.
    // Recommended: Use ref.read in addPostFrameCallback or watch in build.
    // Here using after build approach to populate controllers
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = ref.read(categoriesViewModelProvider);
      if (state.value != null && widget.collectionId != null) {
        final collection = state.value!.categories.firstWhere(
          (c) => c.id == widget.collectionId,
          orElse: () => throw Exception('Collection not found'),
        );

        setState(() {
          _nameController.text = collection.safeName;
          _slugController.text = collection.safeSlug;
          _isActive = collection.isActive;
          _coverMiniPath = collection.cover?.coverMiniPath;
          _coverPagePath = collection.cover?.coverPagePath;
          _slugTouched = true; // Don't auto-update if editing existing
        });
      }
    });
  }

  @override
  void dispose() {
    _nameController.removeListener(_onNameChanged);
    _nameController.dispose();
    _slugController.dispose();
    super.dispose();
  }

  void _onNameChanged() {
    if (!_slugTouched && !_isEdit) {
      final slug = Category.generateSlug(_nameController.text);
      _slugController.text = slug;
    }
  }

  Future<void> _pickImage(bool isMini) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        if (!await file.exists()) return;

        // Compress image
        final optimizer = ref.read(imageOptimizerServiceProvider.notifier);
        final compressedFile = await optimizer.compressImage(file);
        final fileToSave = compressedFile ?? file;

        // Copy to app storage
        final appDir = await getApplicationDocumentsDirectory();
        final fileName = '${const Uuid().v4()}${p.extension(fileToSave.path)}';
        final savedImage = await fileToSave.copy('${appDir.path}/$fileName');

        setState(() {
          if (isMini) {
            _coverMiniPath = savedImage.path;
          } else {
            _coverPagePath = savedImage.path;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao selecionar imagem: $e')),
        );
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_coverMiniPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A mini capa \u00e9 obrigat\u00f3ria.')),
      );
      return;
    }

    try {
      final notifier = ref.read(categoriesViewModelProvider.notifier);
      String? error;
      String? successId;

      if (_isEdit) {
        error = await notifier.updateCollection(
          id: widget.collectionId!,
          name: _nameController.text,
          slug: _slugController.text,
          coverMiniPath: _coverMiniPath!,
          coverPagePath: _coverPagePath,
          isActive: _isActive,
        );
        successId = widget.collectionId;
      } else {
        final newId = const Uuid().v4();
        error = await notifier.addCollection(
          id: newId,
          name: _nameController.text,
          slug: _slugController.text,
          coverMiniPath: _coverMiniPath!,
          coverPagePath: _coverPagePath,
          isActive: _isActive,
        );
        successId = newId;
      }

      if (error != null) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(error)));
        }
      } else {
        if (mounted) {
          context.pop(successId);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro inesperado: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: _isEdit ? 'Editar Cole\u00e7\u00e3o' : 'Nova Cole\u00e7\u00e3o',
      subtitle: 'Crie a cole\u00e7\u00e3o e defina as capas do cat\u00e1logo',
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppTokens.space24),
          child: Column(
            children: [
              const SizedBox(height: AppTokens.space24),

              // Se\u00e7\u00e3o A - Dados da Cole\u00e7\u00e3o
              SectionCard(
                title: 'Dados da Cole\u00e7\u00e3o',
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nome da Cole\u00e7\u00e3o',
                        hintText: 'Ex: Ver\u00e3o 2026',
                        filled: true,
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Obrigat\u00f3rio' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _slugController,
                      decoration: const InputDecoration(
                        labelText: 'Slug (URL amig\u00e1vel)',
                        hintText: 'ex: verao-2026',
                        filled: true,
                        helperText: 'Identificador \u00fanico na URL',
                      ),
                      onChanged: (_) => _slugTouched = true,
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Obrigat\u00f3rio' : null,
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Cole\u00e7\u00e3o Ativa'),
                      subtitle: const Text(
                        'Exibir esta cole\u00e7\u00e3o no cat\u00e1logo e permitir vendas',
                      ),
                      value: _isActive,
                      activeColor: AppTokens.accentBlue,
                      onChanged: (v) => setState(() => _isActive = v),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppTokens.space24),

              // Se\u00e7\u00e3o C - Capas da Cole\u00e7\u00e3o
              SectionCard(
                title: 'Capas da Cole\u00e7\u00e3o',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCoverSection(
                      title: 'Mini Capa',
                      subtitle:
                          'Obrigat\u00f3ria. Usada no topo do cat\u00e1logo (1365\u00c3—420).',
                      path: _coverMiniPath,
                      onPick: () => _pickImage(true),
                      onRemove: () => setState(() => _coverMiniPath = null),
                      aspectRatio: 1365 / 420,
                      height: 140, // Fixed height for preview
                    ),
                    const Divider(height: 32),
                    _buildCoverSection(
                      title: 'Imagem Editorial',
                      subtitle:
                          'Opcional. Preenche o restante da p\u00e1gina de abertura.',
                      path: _coverPagePath,
                      onPick: () => _pickImage(false),
                      onRemove: () => setState(() => _coverPagePath = null),
                      aspectRatio: 3 / 4, // Portrait aspect
                      height: 300, // Fixed height for preview
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppTokens.space48),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
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
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => context.pop(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: AppPrimaryButton(
                  label: 'Salvar Cole\u00e7\u00e3o',
                  onPressed: _save,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCoverSection({
    required String title,
    required String subtitle,
    required String? path,
    required VoidCallback onPick,
    required VoidCallback onRemove,
    required double aspectRatio,
    required double height,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(color: AppTokens.textMuted, fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (path == null)
              FilledButton.tonal(
                onPressed: onPick,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add_photo_alternate, size: 18),
                    const SizedBox(width: 8),
                    const Text('Adicionar'),
                  ],
                ),
              )
            else
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton.icon(
                    onPressed: onPick,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Alterar'),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: onRemove,
                    icon: const Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: AppTokens.accentRed,
                    ),
                    tooltip: 'Remover Imagem',
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (path != null)
          GestureDetector(
            onTap: onPick,
            child: Container(
              height: height,
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).dividerColor),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(path),
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      errorBuilder: (_, _, _) => const Center(
                        child: Icon(
                          Icons.broken_image,
                          size: 48,
                          color: AppTokens.textMuted,
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.0),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.35),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.refresh,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          GestureDetector(
            onTap: onPick,
            child: Container(
              height: height / 2.5,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                border: Border.all(
                  color: Theme.of(context).dividerColor,
                  style: BorderStyle.solid,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 32,
                    color: AppTokens.textMuted.withOpacity(0.5),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Clique para selecionar',
                    style: TextStyle(
                      color: AppTokens.textMuted.withOpacity(0.5),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
