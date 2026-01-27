import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gravity/core/services/catalog_pdf_service.dart';
import 'package:gravity/core/services/whatsapp_share_service.dart';
import 'package:gravity/data/repositories/settings_repository.dart';
import 'package:gravity/models/catalog.dart';
import 'package:gravity/viewmodels/products_viewmodel.dart';

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
                  const SnackBar(content: Text('Salve o catálogo primeiro para gerar um link.')),
                );
                return;
              }
              
              final settingsRepo = ref.read(settingsRepositoryProvider);
              final settings = await settingsRepo.getSettings();
              final baseUrl = settings.publicBaseUrl?.isNotEmpty == true ? settings.publicBaseUrl! : 'https://gravity.app';
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
        ],
      ),
    );
  }

  static Future<void> generateAndSharePdf(BuildContext context, WidgetRef ref, Catalog catalog) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final productsState = ref.read(productsViewModelProvider);
      final allProducts = productsState.value?.allProducts ?? [];
      final catalogProducts = allProducts.where((p) => catalog.productIds.contains(p.id)).toList();

      if (catalogProducts.isEmpty) {
        throw Exception('Nenhum produto selecionado.');
      }

      final pdfBytes = await CatalogPdfService.generateCatalogPdf(
        catalogName: catalog.name.isEmpty ? 'Meu Catálogo' : catalog.name,
        products: catalogProducts,
      );

      // Close loading dialog safely
      if (context.mounted) {
         Navigator.of(context, rootNavigator: true).pop();
      }

      await WhatsAppShareService.shareFile(
        bytes: pdfBytes,
        fileName: 'catalogo_${catalog.slug.isNotEmpty ? catalog.slug : "doc"}.pdf',
        text: 'Confira nosso catálogo ${catalog.name}!',
      );
    } catch (e) {
      // Close loading dialog safely if still open
      if (context.mounted) {
        try {
           Navigator.of(context, rootNavigator: true).pop();
        } catch (_) {}
      }
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao gerar PDF: $e')),
        );
      }
    }
  }
}
