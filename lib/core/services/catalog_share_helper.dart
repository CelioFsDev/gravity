import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gravity/core/services/catalog_pdf_service.dart';
import 'package:gravity/core/services/whatsapp_share_service.dart';
import 'package:gravity/data/repositories/products_repository.dart';
import 'package:gravity/data/repositories/settings_repository.dart';
import 'package:gravity/models/catalog.dart';
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
            leading: const Icon(Icons.link),
            title: const Text('Enviar Link'),
            subtitle: const Text('Compartilha o link do catálogo web'),
            onTap: () async {
              Navigator.pop(sheetContext);
              if (catalog.slug.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Salve o catálogo primeiro para gerar um link.',
                    ),
                  ),
                );
                return;
              }

              final settingsRepo = ref.read(settingsRepositoryProvider);
              final settings = await settingsRepo.getSettings();
              final baseUrl = settings.publicBaseUrl?.isNotEmpty == true
                  ? settings.publicBaseUrl!
                  : 'https://gravity.app';
              final url = '$baseUrl/c/${catalog.slug}';

              await WhatsAppShareService.shareCatalog(
                catalogName: catalog.name,
                catalogUrl: url,
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
      final pdfBytes = await _runWithLoadingDialog(
        context,
        () => _generatePdfBytes(ref, catalog),
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
      final pdfBytes = await _runWithLoadingDialog(
        context,
        () => _generatePdfBytes(ref, catalog),
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
    Catalog catalog,
  ) async {
    // Wait for products to load if they haven't yet
    final productsState = await ref.read(productsViewModelProvider.future);
    final allProducts = productsState.allProducts;

    final catalogProducts = allProducts
        .where((p) => catalog.productIds.contains(p.id))
        .toList();

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

      final catalogName = catalog.name.isEmpty ? 'Meu Catálogo' : catalog.name;
      return CatalogPdfService.generateCatalogPdf(
        catalogName: catalogName,
        products: fallbackProducts,
      );
    }

    final catalogName = catalog.name.isEmpty ? 'Meu Catálogo' : catalog.name;
    return CatalogPdfService.generateCatalogPdf(
      catalogName: catalogName,
      products: catalogProducts,
    );
  }

  static Future<T> _runWithLoadingDialog<T>(
    BuildContext context,
    Future<T> Function() action,
  ) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) =>
          const Center(child: CircularProgressIndicator()),
    );

    try {
      return await action();
    } finally {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }
  }
}
