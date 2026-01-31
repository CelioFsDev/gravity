import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gravity/core/services/catalog_pdf_service.dart';
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
  static const _defaultBaseUrl = 'https://gravity.app';

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
            leading: const Icon(Icons.link),
            title: const Text('Enviar Link'),
            subtitle: const Text('Compartilha o link do catálogo web'),
            onTap: () async {
              Navigator.pop(sheetContext);
              if (!catalog.isPublic || catalog.shareCode.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Marque o catálogo como público e salve para gerar um link.',
                    ),
                  ),
                );
                return;
              }

              final url = '$_defaultBaseUrl/c/${catalog.shareCode}';

              await WhatsAppShareService.shareCatalog(
                catalogName: catalog.name,
                catalogUrl: url,
                mode: catalog.mode,
              );
            },
          ),
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
      final selectedMode = await _selectPriceMode(context);
      if (selectedMode == null) return;

      final width = MediaQuery.of(context).size.width;
      final columnsCount = width < 600 ? 1 : 2;

      final pdfBytes = await _runWithLoadingDialog(
        context,
        () => _generatePdfBytes(
          ref,
          catalog,
          columnsCount: columnsCount,
          mode: selectedMode,
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

  static Future<void> saveCatalogPdf(
    BuildContext context,
    WidgetRef ref,
    Catalog catalog,
  ) async {
    try {
      final selectedMode = await _selectPriceMode(context);
      if (selectedMode == null) return;

      final width = MediaQuery.of(context).size.width;
      final columnsCount = width < 600 ? 1 : 2;

      final pdfBytes = await _runWithLoadingDialog(
        context,
        () => _generatePdfBytes(
          ref,
          catalog,
          columnsCount: columnsCount,
          mode: selectedMode,
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
      return CatalogPdfService.generateCatalogPdf(
        catalogName: catalogName,
        products: fallbackProducts,
        columnsCount: columnsCount,
        mode: mode,
        bannerImagePath: bannerImagePath,
        collectionCover: fallbackCoverInfo.cover,
        collectionName: fallbackCoverInfo.name,
        includeCover: catalog.includeCover,
      );
    }

    final catalogName = catalog.name.isEmpty ? 'Meu Catálogo' : catalog.name;
    return CatalogPdfService.generateCatalogPdf(
      catalogName: catalogName,
      products: catalogProducts,
      columnsCount: columnsCount,
      mode: mode,
      bannerImagePath: bannerImagePath,
      collectionCover: coverInfo.cover,
      collectionName: coverInfo.name,
      includeCover: catalog.includeCover,
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

  static Future<CatalogMode?> _selectPriceMode(BuildContext context) async {
    return showDialog<CatalogMode>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Escolha o preço do catálogo'),
          content: const Text(
            'Deseja exportar com preço de varejo ou atacado?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, CatalogMode.varejo),
              child: const Text('Varejo'),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, CatalogMode.atacado),
              child: const Text('Atacado'),
            ),
          ],
        );
      },
    );
  }
}

class _CollectionCoverResult {
  final CollectionCover? cover;
  final String? name;

  const _CollectionCoverResult(this.cover, this.name);
}

_CollectionCoverResult _resolveCollectionCover(
  List<Product> products,
  List<Category> categories,
) {
  if (products.isEmpty || categories.isEmpty) {
    return const _CollectionCoverResult(null, null);
  }

  final collections = {
    for (final category in categories)
      if (category.type == CategoryType.collection) category.id: category,
  };

  if (collections.isEmpty) return const _CollectionCoverResult(null, null);

  final matchedIds = <String>{};
  for (final product in products) {
    for (final id in product.categoryIds) {
      if (collections.containsKey(id)) {
        matchedIds.add(id);
      }
    }
  }

  if (matchedIds.length != 1) {
    return const _CollectionCoverResult(null, null);
  }

  final collection = collections[matchedIds.first];
  if (collection == null) return const _CollectionCoverResult(null, null);

  return _CollectionCoverResult(collection.cover, collection.name);
}





