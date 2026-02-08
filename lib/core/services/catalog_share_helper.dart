import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
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
    String selectedCoverType =
        'collection'; // Default to collection/custom if available
    String? selectedCollectionId = availableCollections.isNotEmpty
        ? availableCollections.first.id
        : null;

    return showDialog<CatalogExportOptions>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Opções de Exportação'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Preço',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: RadioListTile<CatalogMode>(
                            title: const Text(
                              'Varejo',
                              style: TextStyle(fontSize: 14),
                            ),
                            value: CatalogMode.varejo,
                            groupValue: selectedMode,
                            contentPadding: EdgeInsets.zero,
                            onChanged: (v) => setState(() => selectedMode = v!),
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<CatalogMode>(
                            title: const Text(
                              'Atacado',
                              style: TextStyle(fontSize: 14),
                            ),
                            value: CatalogMode.atacado,
                            groupValue: selectedMode,
                            contentPadding: EdgeInsets.zero,
                            onChanged: (v) => setState(() => selectedMode = v!),
                          ),
                        ),
                      ],
                    ),
                    const Divider(),
                    const Text(
                      'Capa',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    RadioListTile<String>(
                      title: const Text('Capa da Coleção (Com Foto)'),
                      subtitle: const Text('Usa a imagem da coleção'),
                      value: 'collection',
                      groupValue: selectedCoverType,
                      onChanged: (v) => setState(() => selectedCoverType = v!),
                    ),
                    if (selectedCoverType == 'collection' &&
                        availableCollections.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(
                          left: 16,
                          right: 16,
                          bottom: 8,
                        ),
                        child: DropdownButtonFormField<String>(
                          initialValue: selectedCollectionId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Selecione a Coleção',
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            border: OutlineInputBorder(),
                          ),
                          items: availableCollections.map((c) {
                            return DropdownMenuItem(
                              value: c.id,
                              child: Text(
                                c.name ?? 'Sem Nome',
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (v) {
                            if (v != null) {
                              setState(() => selectedCollectionId = v);
                            }
                          },
                        ),
                      ),
                    RadioListTile<String>(
                      title: const Text('Capa Padrão (Texto)'),
                      subtitle: const Text('Apenas logo e título'),
                      value: 'standard',
                      groupValue: selectedCoverType,
                      onChanged: (v) => setState(() => selectedCoverType = v!),
                    ),
                    RadioListTile<String>(
                      title: const Text('Sem Capa'),
                      value: 'none',
                      groupValue: selectedCoverType,
                      onChanged: (v) => setState(() => selectedCoverType = v!),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(
                    dialogContext,
                    CatalogExportOptions(
                      selectedMode,
                      selectedCoverType,
                      selectedCollectionId,
                    ),
                  ),
                  child: const Text('Gerar PDF'),
                ),
              ],
            );
          },
        );
      },
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
  CatalogExportOptions(this.mode, this.coverType, this.collectionId);
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
