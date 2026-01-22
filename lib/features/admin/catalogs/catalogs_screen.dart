import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gravity/viewmodels/catalogs_viewmodel.dart';
import 'package:gravity/features/admin/catalogs/catalog_editor_screen.dart';

class CatalogsScreen extends ConsumerWidget {
  const CatalogsScreen({super.key});

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
                               onPressed: () {
                                  // Mock copy
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Link copiado: /c/${catalog.slug}')));
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
