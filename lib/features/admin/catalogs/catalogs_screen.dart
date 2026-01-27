import 'package:gravity/core/services/whatsapp_share_service.dart';
import 'package:gravity/core/services/catalog_pdf_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gravity/viewmodels/catalogs_viewmodel.dart';
import 'package:gravity/viewmodels/products_viewmodel.dart';
import 'package:flutter/services.dart';
import 'package:gravity/features/admin/catalogs/catalog_editor_screen.dart';
import 'package:gravity/data/repositories/settings_repository.dart';
import 'package:gravity/models/catalog.dart';

class CatalogsScreen extends ConsumerWidget {
  const CatalogsScreen({super.key});

  void _safePop(BuildContext context) {
    if (!context.mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      final navigator = Navigator.of(context, rootNavigator: true);
      if (navigator.canPop()) {
        navigator.pop();
      }
    });
  }

  Future<void> _showShareOptions(BuildContext context, WidgetRef ref, Catalog catalog) async {
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
              await _generateAndSharePdf(context, ref, catalog);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _generateAndSharePdf(BuildContext context, WidgetRef ref, Catalog catalog) async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    // Let the dialog push finish before doing heavy work.
    await Future<void>.delayed(Duration.zero);

    try {
      final productsState = ref.read(productsViewModelProvider);
      final allProducts = productsState.value?.allProducts ?? [];
      final catalogProducts = allProducts.where((p) => catalog.productIds.contains(p.id)).toList();

      final pdfBytes = await CatalogPdfService.generateCatalogPdf(
        catalogName: catalog.name,
        products: catalogProducts,
      );

      // Close loading
      _safePop(context);

      await WhatsAppShareService.shareFile(
        bytes: pdfBytes,
        fileName: 'catalogo_${catalog.slug}.pdf',
        text: 'Confira nosso catálogo ${catalog.name}!',
      );
    } catch (e) {
      _safePop(context); // Close loading if still open
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao gerar PDF: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(catalogsViewModelProvider);
    final notifier = ref.read(catalogsViewModelProvider.notifier);

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Catálogos', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                    Text('Gerencie seus catálogos digitais', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey)),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () {
                     Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CatalogEditorScreen()));
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Novo Catálogo'),
                ),
              ],
            ),
            const SizedBox(height: 24),

            state.when(
              data: (catalogs) {
                if (catalogs.isEmpty) {
                   return const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('Nenhum catálogo encontrado.')));
                }
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: catalogs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final catalog = catalogs[index];
                    return Card(
                      child: ListTile(
                         title: Text(catalog.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                         subtitle: Text('/c/${catalog.slug} • ${catalog.productIds.length} produtos • ${catalog.active ? 'Ativo' : 'Inativo'}'),
                         trailing: Row(
                           mainAxisSize: MainAxisSize.min,
                           children: [
                             IconButton(
                               icon: const Icon(Icons.copy),
                               tooltip: 'Copiar Link',
                               onPressed: () async {
                                  final settingsRepo = ref.read(settingsRepositoryProvider);
                                  final settings = await settingsRepo.getSettings();
                                  final baseUrl = settings.publicBaseUrl?.isNotEmpty == true ? settings.publicBaseUrl! : 'https://gravity.app';
                                  final url = '$baseUrl/c/${catalog.slug}';
                                  
                                  await Clipboard.setData(ClipboardData(text: url));
                                  if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Link copiado: $url')));
                                  }
                               },
                             ),
                              IconButton(
                               icon: const Icon(Icons.share),
                               tooltip: 'Compartilhar',
                               onPressed: () async {
                                  await _showShareOptions(context, ref, catalog);
                               },
                             ),
                             IconButton(
                               icon: const Icon(Icons.edit),
                               onPressed: () {
                                 Navigator.of(context).push(MaterialPageRoute(builder: (_) => CatalogEditorScreen(catalog: catalog)));
                               },
                             ),
                             IconButton(
                               icon: const Icon(Icons.delete, color: Colors.red),
                               onPressed: () {
                                 // Confirm?
                                 notifier.deleteCatalog(catalog.id);
                               },
                             ),
                           ],
                         ),
                      ),
                    );
                  },
                );
              },
              error: (e, s) => Center(child: Text('Erro: $e')),
              loading: () => const Center(child: CircularProgressIndicator()),
            ),
          ],
        ),
      ),
    );
  }
}
