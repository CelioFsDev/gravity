import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:gravity/ui/theme/app_tokens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gravity/core/services/catalog_pdf_service.dart';
import 'package:gravity/viewmodels/settings_viewmodel.dart';
import 'package:gravity/core/services/whatsapp_share_service.dart';
import 'package:gravity/data/repositories/products_repository.dart';
import 'package:gravity/models/catalog.dart';
import 'package:gravity/models/category.dart';
import 'package:gravity/models/product.dart';
import 'package:gravity/viewmodels/products_viewmodel.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class CatalogShareHelper {
  static Future<void> showShareOptions({
    required BuildContext context,
    required WidgetRef ref,
    required Catalog catalog,
  }) async {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.picture_as_pdf),
            title: const Text('Gerar PDF e Enviar'),
            subtitle: const Text('Gera um arquivo PDF com os produtos'),
            onTap: () async {
              Navigator.pop(sheetContext);
              await generateAndSharePdf(context, ref, catalog);
            },
          ),
          ListTile(
            leading: const Icon(Icons.link),
            title: const Text('Compartilhar Link'),
            subtitle: const Text('Envia o link do catálogo online'),
            onTap: () async {
              Navigator.pop(sheetContext);
              await shareCatalogLink(context, ref, catalog);
            },
          ),
          ListTile(
            leading: const Icon(Icons.download),
            title: const Text('Salvar PDF no dispositivo'),
            subtitle: const Text(
              'Cria uma cópia do catálogo em PDF nos documentos',
            ),
            onTap: () async {
              Navigator.pop(sheetContext);
              await saveCatalogPdf(context, ref, catalog);
            },
          ),
        ],
      ),
    );
  }

  static Future<void> generateAndSharePdf(
    BuildContext context,
    WidgetRef ref,
    Catalog catalog,
  ) async {
    try {
      // 1. Fetch relevant collections for the catalog
      final availableCollections = await _getRelevantCollections(ref, catalog);

      final options = await _selectExportOptions(
        context,
        catalog,
        availableCollections,
      );
      if (options == null) return;

      final width = MediaQuery.of(context).size.width;
      final columnsCount = width < 600 ? 1 : 2;

      final pdfBytes = await _runWithLoadingDialog(
        context,
        () => _generatePdfBytes(
          ref,
          catalog,
          columnsCount: columnsCount,
          mode: options.mode,
          showPrice: options.showPrice,
          coverTypeOverride: options.coverType,
          collectionIdOverride: options.collectionId,
        ),
      );

      await WhatsAppShareService.shareFile(
        bytes: pdfBytes,
        fileName:
            'catalogo_${catalog.slug.isNotEmpty ? catalog.slug : "doc"}.pdf',
        text: 'Confira nosso catálogo ${catalog.name}!',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao gerar PDF: $e')));
      }
    }
  }

  static Future<void> shareCatalogLink(
    BuildContext context,
    WidgetRef ref,
    Catalog catalog,
  ) async {
    try {
      final settings = ref.read(settingsViewModelProvider);
      final baseUrl = settings.publicBaseUrl.isEmpty
          ? 'https://gravity.app'
          : settings.publicBaseUrl;
      final shareUrl = '$baseUrl/c/${catalog.slug}';
      await WhatsAppShareService.shareCatalog(
        catalogName: catalog.name,
        catalogUrl: shareUrl,
        mode: catalog.mode,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao compartilhar link: $e')),
        );
      }
    }
  }

  static Future<void> saveCatalogPdf(
    BuildContext context,
    WidgetRef ref,
    Catalog catalog,
  ) async {
    try {
      // 1. Fetch relevant collections for the catalog
      final availableCollections = await _getRelevantCollections(ref, catalog);

      final options = await _selectExportOptions(
        context,
        catalog,
        availableCollections,
      );
      if (options == null) return;

      final width = MediaQuery.of(context).size.width;
      final columnsCount = width < 600 ? 1 : 2;

      final pdfBytes = await _runWithLoadingDialog(
        context,
        () => _generatePdfBytes(
          ref,
          catalog,
          columnsCount: columnsCount,
          mode: options.mode,
          showPrice: options.showPrice,
          coverTypeOverride: options.coverType,
          collectionIdOverride: options.collectionId,
        ),
      );
      final documentsDirectory =
          await getDownloadsDirectory() ??
          await getApplicationDocumentsDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final safeName = catalog.slug.isNotEmpty ? catalog.slug : 'catalogo';
      final filename = 'gravity_catalogo_${safeName}_$timestamp.pdf';
      final filePath = p.join(documentsDirectory.path, filename);
      final file = File(filePath);
      await file.writeAsBytes(pdfBytes);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Catálogo salvo em ${file.path}')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao salvar PDF: $e')));
      }
    }
  }

  static Future<Uint8List> _generatePdfBytes(
    WidgetRef ref,
    Catalog catalog, {
    int columnsCount = 1,
    required CatalogMode mode,
    bool showPrice = true,
    String? coverTypeOverride,
    String? collectionIdOverride,
  }) async {
    // Wait for products to load if they haven't yet
    final productsState = await ref.read(productsViewModelProvider.future);
    final allProducts = productsState.allProducts;

    final catalogProducts = allProducts
        .where((p) => catalog.productIds.contains(p.id))
        .toList();
    final bannerImagePath = catalog.banners.isNotEmpty
        ? catalog.banners.first.imagePath
        : null;
    final coverInfo = _resolveCollectionCover(
      catalogProducts,
      productsState.categories,
    );

    // Resolve which cover to show based on settings or override
    bool resolvedIncludeCover;
    CollectionCover? resolvedCollectionCover;
    String? mainCoverCollectionId;

    // Use override if provided, otherwise fallback to catalog settings
    final effectiveCoverType = coverTypeOverride ?? catalog.coverType;

    if (effectiveCoverType != null) {
      if (effectiveCoverType == 'none') {
        resolvedIncludeCover = false;
        resolvedCollectionCover = null;
      } else if (effectiveCoverType == 'standard') {
        resolvedIncludeCover = true;
        resolvedCollectionCover = null; // Forces text standard cover
      } else {
        // 'collection' or default
        resolvedIncludeCover = true;
        var cover = coverInfo.cover; // Default cover (first match)
        var usedCollectionId = coverInfo.collectionId;

        // NEW: If user selected a specific collection, try to find it
        if (collectionIdOverride != null) {
          final requestedCollection = productsState.categories.firstWhere(
            (c) => c.id == collectionIdOverride,
            orElse: () => productsState.categories.firstWhere(
              (c) => c.type == CategoryType.collection,
              orElse: () => productsState.categories.first,
            ), // fallback
          );
          if (requestedCollection.type == CategoryType.collection &&
              requestedCollection.cover != null) {
            cover = requestedCollection.cover;
            usedCollectionId = requestedCollection.id;
          }
        }

        // Fix: If user selected 'collection', ensure we try to show the image
        // even if the saved mode is 'template', provided an image exists.
        if (effectiveCoverType == 'collection' && cover != null) {
          final hasImage =
              (cover.coverImagePath?.isNotEmpty ?? false) ||
              (cover.coverMiniPath?.isNotEmpty ?? false) ||
              (cover.coverPagePath?.isNotEmpty ?? false);
          if (hasImage && cover.mode != CollectionCoverMode.image) {
            cover = cover.copyWith(mode: CollectionCoverMode.image);
          }
        }

        resolvedCollectionCover = cover;
        mainCoverCollectionId = usedCollectionId;
      }
    } else {
      // Legacy fallback
      resolvedIncludeCover = catalog.includeCover;
      resolvedCollectionCover = coverInfo.cover;
      // If legacy true, we still want to avoid dup, so track ID if we have a cover
      if (resolvedIncludeCover && resolvedCollectionCover != null) {
        mainCoverCollectionId = coverInfo.collectionId;
      }
    }

    final collectionsMap = {
      for (final c in productsState.categories)
        if (c.type == CategoryType.collection) c.id: c,
    };

    if (catalogProducts.isEmpty) {
      if (catalog.productIds.isEmpty) {
        throw Exception('Este catálogo não possui produtos selecionados.');
      }

      // Fallback: try to fetch directly from repo in case state is stale
      final repository = ref.read(productsRepositoryProvider);
      final freshProducts = await repository.getProducts();
      final fallbackProducts = freshProducts
          .where((p) => catalog.productIds.contains(p.id))
          .toList();

      if (fallbackProducts.isEmpty) {
        throw Exception(
          'Os produtos deste catálogo não foram encontrados no banco de dados.',
        );
      }

      final fallbackCoverInfo = _resolveCollectionCover(
        fallbackProducts,
        productsState.categories,
      );
      final catalogName = catalog.name.isEmpty ? 'Meu Catálogo' : catalog.name;

      // Re-resolve for fallback (simplified)
      CollectionCover? fbCover;
      String? fbId;

      // Use override logic for fallback too
      final effectiveFallbackCoverType = coverTypeOverride ?? catalog.coverType;

      if (resolvedIncludeCover) {
        if (effectiveFallbackCoverType == 'standard') {
          fbCover = null;
        } else {
          fbCover = fallbackCoverInfo.cover;
          fbId = fallbackCoverInfo.collectionId;
        }
      }

      return CatalogPdfService.generateCatalogPdf(
        catalogName: catalogName,
        products: fallbackProducts,
        columnsCount: columnsCount,
        mode: mode,
        showPrice: showPrice,
        bannerImagePath: bannerImagePath,
        collectionCover: fbCover,
        collectionName: fallbackCoverInfo.name,
        includeCover: resolvedIncludeCover,
        collectionsMap: collectionsMap,
        mainCoverCollectionId: fbId,
      );
    }

    final catalogName = catalog.name.isEmpty ? 'Meu Catálogo' : catalog.name;
    return CatalogPdfService.generateCatalogPdf(
      catalogName: catalogName,
      products: catalogProducts,
      columnsCount: columnsCount,
      mode: mode,
      showPrice: showPrice,
      bannerImagePath: bannerImagePath,
      collectionCover: resolvedCollectionCover,
      collectionName: coverInfo.name,
      includeCover: resolvedIncludeCover,
      collectionsMap: collectionsMap,
      mainCoverCollectionId: mainCoverCollectionId,
    );
  }

  static Future<T> _runWithLoadingDialog<T>(
    BuildContext context,
    Future<T> Function() action,
  ) async {
    BuildContext? dialogContext;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        dialogContext = ctx;
        return const Center(child: CircularProgressIndicator());
      },
    );

    try {
      return await action();
    } finally {
      if (dialogContext != null && dialogContext!.mounted) {
        Navigator.of(dialogContext!, rootNavigator: true).pop();
      }
    }
  }

  static Future<CatalogExportOptions?> _selectExportOptions(
    BuildContext context,
    Catalog catalog,
    List<Category> availableCollections,
  ) async {
    CatalogMode selectedMode = CatalogMode.varejo;
    bool showPrice = true;
    String selectedCoverType =
        'collection'; // Default to collection/custom if available
    String? selectedCollectionId = availableCollections.isNotEmpty
        ? availableCollections.first.id
        : null;

    return showModalBottomSheet<CatalogExportOptions>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            final theme = Theme.of(context);

            return Container(
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(AppTokens.radiusLg),
                ),
              ),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                top: 8,
                left: 24,
                right: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: theme.dividerColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    'Opções de Exportação',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),

                  // PRICE SECTION
                  _buildSubHeader(context, 'Preço no PDF'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildOptionCard(
                        context,
                        label: 'Varejo',
                        isSelected:
                            showPrice && selectedMode == CatalogMode.varejo,
                        onTap: () => setState(() {
                          showPrice = true;
                          selectedMode = CatalogMode.varejo;
                        }),
                      ),
                      const SizedBox(width: 8),
                      _buildOptionCard(
                        context,
                        label: 'Atacado',
                        isSelected:
                            showPrice && selectedMode == CatalogMode.atacado,
                        onTap: () => setState(() {
                          showPrice = true;
                          selectedMode = CatalogMode.atacado;
                        }),
                      ),
                      const SizedBox(width: 8),
                      _buildOptionCard(
                        context,
                        label: 'Off',
                        isSelected: !showPrice,
                        onTap: () => setState(() => showPrice = false),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // COVER SECTION
                  _buildSubHeader(context, 'Capa do Catálogo'),
                  const SizedBox(height: 12),
                  _buildCoverTypeTile(
                    context,
                    title: 'Capa da Coleção (Com Foto)',
                    subtitle: 'Usa a imagem principal da coleção',
                    isSelected: selectedCoverType == 'collection',
                    icon: Icons.image_outlined,
                    onTap: () =>
                        setState(() => selectedCoverType = 'collection'),
                  ),
                  if (selectedCoverType == 'collection' &&
                      availableCollections.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(
                        top: 8,
                        left: 12,
                        right: 12,
                      ),
                      child: DropdownButtonFormField<String>(
                        value: selectedCollectionId,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'Selecione a Coleção',
                          filled: true,
                          fillColor: theme.colorScheme.surfaceContainerHighest,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                          ),
                        ),
                        items: availableCollections.map((c) {
                          return DropdownMenuItem(
                            value: c.id,
                            child: Text(c.name ?? 'Coleção sem nome'),
                          );
                        }).toList(),
                        onChanged: (v) =>
                            setState(() => selectedCollectionId = v),
                      ),
                    ),
                  const SizedBox(height: 8),
                  _buildCoverTypeTile(
                    context,
                    title: 'Capa Padrão (Texto)',
                    subtitle: 'Apenas logo e título centralizado',
                    isSelected: selectedCoverType == 'standard',
                    icon: Icons.text_fields,
                    onTap: () => setState(() => selectedCoverType = 'standard'),
                  ),
                  const SizedBox(height: 8),
                  _buildCoverTypeTile(
                    context,
                    title: 'Sem Capa',
                    subtitle: 'Inicia direto na lista de produtos',
                    isSelected: selectedCoverType == 'none',
                    icon: Icons.block,
                    onTap: () => setState(() => selectedCoverType = 'none'),
                  ),

                  const SizedBox(height: 32),

                  // ACTIONS
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          child: const Text('Cancelar'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: theme.colorScheme.onPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () => Navigator.pop(
                            sheetContext,
                            CatalogExportOptions(
                              selectedMode,
                              selectedCoverType,
                              selectedCollectionId,
                              showPrice,
                            ),
                          ),
                          child: const Text(
                            'Gerar PDF',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  static Widget _buildSubHeader(BuildContext context, String title) {
    return Text(
      title.toUpperCase(),
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        letterSpacing: 1.2,
        fontWeight: FontWeight.w800,
        color: Theme.of(context).colorScheme.primary.withOpacity(0.8),
      ),
    );
  }

  static Widget _buildOptionCard(
    BuildContext context, {
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.dividerColor,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.onSurface,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  static Widget _buildCoverTypeTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required bool isSelected,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? theme.colorScheme.primary : theme.dividerColor,
            width: isSelected ? 2 : 1,
          ),
          color: isSelected
              ? theme.colorScheme.primary.withOpacity(0.05)
              : null,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 20,
                color: isSelected
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isSelected ? theme.colorScheme.primary : null,
                    ),
                  ),
                  Text(subtitle, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: theme.colorScheme.primary,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  /// Fetches and filters collections that have products in the given [catalog].
  static Future<List<Category>> _getRelevantCollections(
    WidgetRef ref,
    Catalog catalog,
  ) async {
    final productsState = await ref.read(productsViewModelProvider.future);
    final allProducts = productsState.allProducts;
    final catalogProducts = allProducts
        .where((p) => catalog.productIds.contains(p.id))
        .toList();

    // Filter collections that have products in this catalog
    final catalogCollectionIds = catalogProducts
        .expand((p) => p.categoryIds)
        .toSet();

    return productsState.categories
        .where(
          (c) =>
              c.type == CategoryType.collection &&
              catalogCollectionIds.contains(c.id),
        )
        .toList();
  }
}

class CatalogExportOptions {
  final CatalogMode mode;
  final String coverType;
  final String? collectionId;
  final bool showPrice;
  CatalogExportOptions(
    this.mode,
    this.coverType,
    this.collectionId,
    this.showPrice,
  );
}

class _CollectionCoverResult {
  final CollectionCover? cover;
  final String? name;
  final String? collectionId;

  const _CollectionCoverResult(this.cover, this.name, this.collectionId);
}

_CollectionCoverResult _resolveCollectionCover(
  List<Product> products,
  List<Category> categories,
) {
  if (products.isEmpty || categories.isEmpty) {
    return const _CollectionCoverResult(null, null, null);
  }

  final collections = {
    for (final category in categories)
      if (category.type == CategoryType.collection) category.id: category,
  };

  if (collections.isEmpty) {
    return const _CollectionCoverResult(null, null, null);
  }

  final matchedIds = <String>{};
  for (final product in products) {
    for (final id in product.categoryIds) {
      if (collections.containsKey(id)) {
        matchedIds.add(id);
      }
    }
  }

  if (matchedIds.isEmpty) {
    return const _CollectionCoverResult(null, null, null);
  }

  // Use the first matched collection cover
  final collectionId = matchedIds.first;
  final collection = collections[collectionId];
  if (collection == null) return const _CollectionCoverResult(null, null, null);

  return _CollectionCoverResult(
    collection.cover,
    collection.name,
    collectionId,
  );
}
