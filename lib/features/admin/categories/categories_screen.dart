import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:gravity/models/category.dart';
import 'package:gravity/core/services/local_media_service.dart';
import 'package:gravity/viewmodels/categories_viewmodel.dart';
import 'package:gravity/ui/theme/app_tokens.dart';
import 'package:gravity/ui/widgets/app_scaffold.dart';
import 'package:gravity/ui/widgets/app_search_field.dart';
import 'package:gravity/ui/widgets/app_empty_state.dart';
import 'package:gravity/ui/widgets/section_card.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  final _searchController = TextEditingController();
  final _categoryNameController = TextEditingController();
  final _categoryNameFocus = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _categoryNameFocus.dispose();
    _categoryNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(categoriesViewModelProvider);
    final notifier = ref.read(categoriesViewModelProvider.notifier);

    return AppScaffold(
      title: 'Categorias',
      subtitle: 'Organize as categorias do catálogo',
      actions: [
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: () => _showCategoryDialog(context, notifier),
          tooltip: 'Nova Categoria',
        ),
      ],
      body: state.when(
        data: (data) => _buildContent(context, data, notifier),
        error: (e, s) => Center(child: Text('Erro: $e')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    CategoriesState state,
    CategoriesViewModel notifier,
  ) {
    if (_searchController.text != state.searchQuery) {
      _searchController.value = TextEditingValue(
        text: state.searchQuery,
        selection: TextSelection.collapsed(offset: state.searchQuery.length),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTokens.space24),
          child: AppSearchField(
            controller: _searchController,
            hintText: 'Buscar categorias...',
            onChanged: notifier.setSearchQuery,
            onClear: () {
              notifier.setSearchQuery('');
              _searchController.clear();
            },
          ),
        ),
        const SizedBox(height: AppTokens.space8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTokens.space24),
          child: Row(
            children: [
              ActionChip(
                label: Text(_sortLabel(state.sortOption)),
                onPressed: () => _selectSort(context, state, notifier),
                avatar: const Icon(Icons.sort, size: 16),
              ),
              if (state.searchQuery.isNotEmpty ||
                  state.sortOption != CategorySortOption.manual) ...[
                const SizedBox(width: 8),
                ActionChip(
                  label: const Text('Limpar'),
                  onPressed: () {
                    notifier.setSearchQuery('');
                    notifier.setSortOption(CategorySortOption.manual);
                    _searchController.clear();
                  },
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppTokens.space16),
        Expanded(
          child: state.categories.isEmpty
              ? const AppEmptyState(
                  icon: Icons.folder_open,
                  title: 'Nenhuma categoria',
                  message: 'Toque no + para criar sua primeira categoria.',
                )
              : _buildCategoriesList(state, notifier),
        ),
      ],
    );
  }

  Widget _buildCategoriesList(
    CategoriesState state,
    CategoriesViewModel notifier,
  ) {
    final isManual =
        state.sortOption == CategorySortOption.manual &&
        state.searchQuery.isEmpty;

    final query = state.searchQuery.trim().toLowerCase();
    final filtered = query.isEmpty
        ? state.categories
        : state.categories
              .where((c) => c.name.toLowerCase().contains(query))
              .toList();

    final collections = filtered
        .where((c) => c.type == CategoryType.collection)
        .toList();
    final productTypes = filtered
        .where((c) => c.type == CategoryType.productType)
        .toList();

    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.space24,
        vertical: AppTokens.space12,
      ),
      children: [
        if (collections.isNotEmpty) ...[
          _buildSectionTitle('Coleções'),
          const SizedBox(height: 12),
          _buildSectionList(
            context,
            state,
            notifier,
            collections,
            isManual: isManual,
          ),
          const SizedBox(height: 24),
        ],
        if (productTypes.isNotEmpty) ...[
          _buildSectionTitle('Categorias de Produtos'),
          const SizedBox(height: 12),
          _buildSectionList(
            context,
            state,
            notifier,
            productTypes,
            isManual: isManual,
          ),
        ],
      ],
    );
  }

  Widget _buildSectionList(
    BuildContext context,
    CategoriesState state,
    CategoriesViewModel notifier,
    List<Category> categories, {
    required bool isManual,
  }) {
    if (categories.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'Nenhum item nesta secao.',
          style: TextStyle(color: Colors.grey.shade600),
        ),
      );
    }

    if (isManual) {
      final indices = categories
          .map((c) => state.categories.indexWhere((e) => e.id == c.id))
          .toList();
      return ReorderableListView.builder(
        buildDefaultDragHandles: false,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: categories.length,
        onReorder: (oldIndex, newIndex) {
          final oldFull = indices[oldIndex];
          final newFull = indices[math.min(newIndex, indices.length - 1)];
          notifier.reorder(oldFull, newFull);
        },
        itemBuilder: (context, index) {
          return _buildListItem(
            context,
            state,
            notifier,
            categories[index],
            indices[index],
            isManual: true,
          );
        },
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        return _buildListItem(
          context,
          state,
          notifier,
          categories[index],
          index,
          isManual: false,
        );
      },
    );
  }

  Widget _buildSectionTitle(String text) {
    return Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildListItem(
    BuildContext context,
    CategoriesState state,
    CategoriesViewModel notifier,
    Category category,
    int index, {
    required bool isManual,
  }) {
    return Container(
      key: ValueKey(category.id),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: ListTile(
        leading: isManual
            ? ReorderableDragStartListener(
                index: index,
                child: const Icon(Icons.drag_handle, color: Colors.grey),
              )
            : const Icon(Icons.folder_outlined, color: Colors.grey),
        title: Text(
          category.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('${state.productCounts[category.id] ?? 0} produtos'),
        trailing: PopupMenuButton<_CategoryAction>(
          tooltip: 'Ações',
          onSelected: (value) {
            if (value == _CategoryAction.edit) {
              _showCategoryDialog(context, notifier, category: category);
            } else if (value == _CategoryAction.delete) {
              _handleDelete(context, notifier, category);
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: _CategoryAction.edit, child: Text('Editar')),
            PopupMenuItem(
              value: _CategoryAction.delete,
              child: Text('Excluir'),
            ),
          ],
        ),
      ),
    );
  }

  String _sortLabel(CategorySortOption option) {
    switch (option) {
      case CategorySortOption.manual:
        return 'Ordem: Manual';
      case CategorySortOption.aToZ:
        return 'Ordem: A-Z';
      case CategorySortOption.zToA:
        return 'Ordem: Z-A';
    }
  }

  Future<void> _selectSort(
    BuildContext context,
    CategoriesState state,
    CategoriesViewModel notifier,
  ) async {
    final result = await showModalBottomSheet<CategorySortOption>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text(
                'Ordenar categorias',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            ...CategorySortOption.values.map(
              (option) => RadioListTile<CategorySortOption>(
                title: Text(_sortLabel(option)),
                value: option,
                groupValue: state.sortOption,
                onChanged: (value) => Navigator.pop(sheetContext, value),
              ),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      notifier.setSortOption(result);
    }
  }

  Future<String?> _pickCoverImage(
    BuildContext context, {
    required String collectionId,
    required String fileName,
  }) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.any,
      );
      if (result == null || result.files.isEmpty) return null;
      return _processPickedCoverImage(
        result.files.first,
        context,
        collectionId: collectionId,
        fileName: fileName,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao selecionar imagem: $e')),
        );
      }
      return null;
    }
  }

  Future<String?> _processPickedCoverImage(
    PlatformFile file,
    BuildContext context, {
    required String collectionId,
    required String fileName,
  }) async {
    final ext = p.extension(file.name).toLowerCase();
    if (!['.jpg', '.jpeg', '.png', '.webp'].contains(ext)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Arquivo "${file.name}" ignorado (nao e imagem).'),
          ),
        );
      }
      return null;
    }

    final resolved = await _copyCoverFileToStorage(
      file,
      collectionId: collectionId,
      fileName: fileName,
    );
    if (resolved == null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Falha ao processar "${file.name}".')),
      );
    }
    return resolved;
  }

  Future<String?> _copyCoverFileToStorage(
    PlatformFile file, {
    required String collectionId,
    required String fileName,
  }) async {
    try {
      final extension = p.extension(file.name).isNotEmpty
          ? p.extension(file.name).toLowerCase()
          : '.jpg';
      final targetFileName = '$fileName$extension';

      if (!kIsWeb && file.path != null) {
        final sourceFile = File(file.path!);
        if (!await sourceFile.exists()) return null;
        return await LocalMediaService.savePickedImage(
          sourceFile,
          folder: p.join('media', 'covers', collectionId),
          fileName: targetFileName,
        );
      }

      if (!kIsWeb && file.bytes != null) {
        final tempDir = Directory.systemTemp;
        final tempPath = p.join(tempDir.path, '${const Uuid().v4()}$extension');
        final tempFile = File(tempPath);
        await tempFile.writeAsBytes(file.bytes!);
        return await LocalMediaService.savePickedImage(
          tempFile,
          folder: p.join('media', 'covers', collectionId),
          fileName: targetFileName,
        );
      }

      if (kIsWeb) {
        return 'web_placeholder_${const Uuid().v4()}';
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  Future<void> _showCategoryDialog(
    BuildContext context,
    CategoriesViewModel notifier, {
    Category? category,
  }) async {
    final isEdit = category != null;
    CategoryType selectedType = category?.type ?? CategoryType.productType;
    final collectionId = category?.id ?? const Uuid().v4();
    _categoryNameController.text = category?.name ?? '';
    _categoryNameController.selection = TextSelection.collapsed(
      offset: _categoryNameController.text.length,
    );
    final existingCover = category?.cover;
    CollectionCoverMode coverMode =
        existingCover?.mode ?? CollectionCoverMode.template;
    String? coverImagePath = existingCover?.coverImagePath;
    bool coverImageError = false;
    final coverTitleController = TextEditingController(
      text: existingCover?.title ?? CollectionCover.defaultTitle,
    );
    final coverBrandController = TextEditingController(
      text: existingCover?.brand ?? CollectionCover.defaultBrand,
    );
    final coverSubtitleController = TextEditingController(
      text: existingCover?.subtitle ?? (category?.name ?? ''),
    );

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          scrollable: false,
          title: Text(isEdit ? 'Editar Categoria' : 'Nova Categoria'),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.82,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: SizedBox(
                      width: 420,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextField(
                            controller: _categoryNameController,
                            focusNode: _categoryNameFocus,
                            textInputAction: TextInputAction.done,
                            decoration: const InputDecoration(
                              labelText: 'Nome',
                              hintText: 'Ex: Camisetas',
                            ),
                            autofocus: true,
                          ),
                          const SizedBox(height: 16),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Tipo',
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ToggleButtons(
                            isSelected: [
                              selectedType == CategoryType.collection,
                              selectedType == CategoryType.productType,
                            ],
                            onPressed: isEdit
                                ? null
                                : (index) {
                                    setState(() {
                                      selectedType = index == 0
                                          ? CategoryType.collection
                                          : CategoryType.productType;
                                    });
                                  },
                            borderRadius: BorderRadius.circular(8),
                            constraints: const BoxConstraints(minHeight: 40),
                            children: const [
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16),
                                child: Text('Coleção'),
                              ),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16),
                                child: Text('Categoria'),
                              ),
                            ],
                          ),
                          if (isEdit)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                'O tipo nao pode ser alterado.',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          if (selectedType == CategoryType.collection) ...[
                            const SizedBox(height: 20),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Capa do catalogo',
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                            ),
                            const SizedBox(height: 8),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: ToggleButtons(
                                isSelected: [
                                  coverMode == CollectionCoverMode.image,
                                  coverMode == CollectionCoverMode.template,
                                ],
                                onPressed: (index) {
                                  setState(() {
                                    coverMode = index == 0
                                        ? CollectionCoverMode.image
                                        : CollectionCoverMode.template;
                                    if (coverMode !=
                                        CollectionCoverMode.image) {
                                      coverImageError = false;
                                    }
                                  });
                                },
                                borderRadius: BorderRadius.circular(8),
                                constraints: const BoxConstraints(
                                  minHeight: 40,
                                ),
                                children: const [
                                  Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    child: Text('Capa personalizada'),
                                  ),
                                  Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    child: Text('Capa automática'),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (coverMode == CollectionCoverMode.image) ...[
                              const Divider(height: 32),
                              SectionCard(
                                title: 'Imagem de capa',
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        ElevatedButton.icon(
                                          onPressed: () async {
                                            final picked =
                                                await _pickCoverImage(
                                                  context,
                                                  collectionId: collectionId,
                                                  fileName: 'cover',
                                                );
                                            if (picked != null) {
                                              setState(() {
                                                coverImagePath = picked;
                                                coverImageError = false;
                                              });
                                            }
                                          },
                                          icon: const Icon(
                                            Icons.image_outlined,
                                          ),
                                          label: const Text('Selecionar capa'),
                                        ),
                                        if (coverImagePath != null) ...[
                                          const SizedBox(width: 8),
                                          IconButton(
                                            onPressed: () => setState(() {
                                              coverImagePath = null;
                                            }),
                                            icon: const Icon(
                                              Icons.delete_outline,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    if (coverImageError)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 6),
                                        child: Text(
                                          'Selecione uma imagem de capa.',
                                          style: TextStyle(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.error,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    if (coverImagePath != null && !kIsWeb)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 12),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          child: AspectRatio(
                                            aspectRatio: 16 / 9,
                                            child: Image.file(
                                              File(coverImagePath!),
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) =>
                                                  Container(
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .surfaceContainerHighest,
                                                    alignment: Alignment.center,
                                                    child: const Icon(
                                                      Icons.broken_image,
                                                    ),
                                                  ),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ] else ...[
                              TextField(
                                controller: coverSubtitleController,
                                decoration: const InputDecoration(
                                  labelText: 'Subtitulo',
                                  hintText: 'Ex: CAPSULA 2026',
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: coverTitleController,
                                decoration: const InputDecoration(
                                  labelText: 'Titulo',
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: coverBrandController,
                                decoration: const InputDecoration(
                                  labelText: 'Marca',
                                ),
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = _categoryNameController.text.trim();
                if (name.isEmpty) return;
                if (selectedType == CategoryType.collection &&
                    coverMode == CollectionCoverMode.image &&
                    coverImagePath == null) {
                  setState(() => coverImageError = true);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Selecione uma imagem de capa para salvar.',
                        ),
                      ),
                    );
                  }
                  return;
                }

                CollectionCover? cover;
                if (selectedType == CategoryType.collection) {
                  final subtitle =
                      coverSubtitleController.text.trim().isNotEmpty
                      ? coverSubtitleController.text.trim()
                      : name;
                  final title = coverTitleController.text.trim().isNotEmpty
                      ? coverTitleController.text.trim()
                      : CollectionCover.defaultTitle;
                  final brand = coverBrandController.text.trim().isNotEmpty
                      ? coverBrandController.text.trim()
                      : CollectionCover.defaultBrand;
                  cover = CollectionCover(
                    mode: coverMode,
                    coverImagePath: coverImagePath,
                    title: title,
                    brand: brand,
                    subtitle: subtitle,
                    backgroundColor: existingCover?.backgroundColor,
                    overlayOpacity: existingCover?.overlayOpacity,
                  );
                }

                String? error;
                if (isEdit) {
                  error = await notifier.updateCategory(
                    category.id,
                    name,
                    cover: cover,
                  );
                } else {
                  error = await notifier.addCategory(
                    name,
                    selectedType,
                    cover: cover,
                    id: collectionId,
                  );
                }

                if (context.mounted) {
                  if (error != null) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(error)));
                  } else {
                    Navigator.pop(context);
                  }
                }
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );

    coverTitleController.dispose();
    coverBrandController.dispose();
    coverSubtitleController.dispose();

    if (mounted) {
      _categoryNameController.clear();
      _categoryNameFocus.unfocus();
    }
  }

  Future<void> _handleDelete(
    BuildContext context,
    CategoriesViewModel notifier,
    Category category,
  ) async {
    final result = await notifier.checkDelete(category.id);
    if (!context.mounted) return;

    if (result.success) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Categoria excluida')));
      return;
    }

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Categoria?'),
        content: const Text(
          'Esta categoria possui produtos vinculados.\nO que deseja fazer?',
        ),
        actions: [
          TextButton(
            child: const Text('Cancelar'),
            onPressed: () => Navigator.pop(context),
          ),
          OutlinedButton(
            child: const Text('Mover para "Sem Categoria"'),
            onPressed: () async {
              await notifier.deleteAndUncategorize(category.id);
              if (context.mounted) Navigator.pop(context);
            },
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Excluir Mesmo Assim'),
            onPressed: () async {
              await notifier.deleteAndUncategorize(category.id);
              if (context.mounted) Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}

enum _CategoryAction { edit, delete }

class _ScrollLabel extends StatelessWidget {
  final String text;

  const _ScrollLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Text(text),
      ),
    );
  }
}
