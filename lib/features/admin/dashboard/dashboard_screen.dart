import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:catalogo_ja/ui/theme/app_tokens.dart';
import 'package:catalogo_ja/ui/widgets/app_scaffold.dart';
import 'package:catalogo_ja/data/repositories/products_repository.dart';
import 'package:catalogo_ja/data/repositories/categories_repository.dart';
import 'package:catalogo_ja/data/repositories/catalogs_repository.dart';
import 'package:catalogo_ja/models/product.dart';
import 'package:catalogo_ja/models/category.dart';
import 'package:catalogo_ja/models/catalog.dart';
import 'package:catalogo_ja/viewmodels/global_sync_viewmodel.dart';
import 'package:catalogo_ja/viewmodels/products_viewmodel.dart';
import 'package:catalogo_ja/data/repositories/settings_repository.dart';
import 'package:catalogo_ja/ui/widgets/sync_progress_overlay.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  Widget build(BuildContext context) {
    // ⚡️ OTIMIZAÇÃO SAAS: Usamos os repositórios LOCAIS (Hive) para as contagens do Dashboard.
    final productsAsync = ref.watch(productsRepositoryProvider).watchProducts();
    final categoriesAsync = ref
        .watch(categoriesRepositoryProvider)
        .watchCategories();
    final catalogsAsync = ref.watch(catalogsRepositoryProvider).watchCatalogs();
    final syncProgress = ref.watch(syncProgressProvider);
    final settings = ref.watch(settingsRepositoryProvider).getSettings();

    // Trigger Initial Sync Choice se for primeiro acesso: o redirecionamento é feito no main.dart!
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // ✅ Inicia sincronização silenciosa se estiver no Wi-Fi
      if (!syncProgress.isSyncing && settings.isInitialSyncCompleted) {
        ref.read(globalSyncViewModelProvider.notifier).performSilentWifiSync();
      }
    });

    return Stack(
      children: [
        AppScaffold(
          title: 'Painel de Controle',
          subtitle: 'Bem-vindo ao seu Catálogo SaaS',
          body: StreamBuilder<List<Product>>(
            stream: productsAsync,
            builder: (context, productsSnapshot) {
              return StreamBuilder<List<Category>>(
                stream: categoriesAsync,
                builder: (context, categoriesSnapshot) {
                  return StreamBuilder<List<Catalog>>(
                    stream: catalogsAsync,
                    builder: (context, catalogsSnapshot) {
                      final productCount = productsSnapshot.data?.length ?? 0;
                      final categoryCount =
                          categoriesSnapshot.data?.length ?? 0;
                      final catalogCount = catalogsSnapshot.data?.length ?? 0;

                      return CustomScrollView(
                        slivers: [
                          SliverPadding(
                            padding: const EdgeInsets.all(AppTokens.space24),
                            sliver: SliverGrid.count(
                              crossAxisCount:
                                  MediaQuery.of(context).size.width > 600
                                  ? 3
                                  : 1,
                              mainAxisSpacing: AppTokens.space16,
                              crossAxisSpacing: AppTokens.space16,
                              childAspectRatio: 1.5,
                              children: [
                                _StatCard(
                                  title: 'Produtos',
                                  value: productCount.toString(),
                                  icon: Icons.inventory_2_outlined,
                                  color: AppTokens.accentBlue,
                                ),
                                _StatCard(
                                  title: 'Coleções',
                                  value: categoryCount.toString(),
                                  icon: Icons.collections_bookmark_outlined,
                                  color: AppTokens.accentGreen,
                                ),
                                _StatCard(
                                  title: 'Catálogos',
                                  value: catalogCount.toString(),
                                  icon: Icons.menu_book_outlined,
                                  color: Colors.orange,
                                ),
                              ],
                            ),
                          ),
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppTokens.space24,
                            ),
                            sliver: SliverToBoxAdapter(
                              child: Text(
                                'Ações Rápidas',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                          ),
                          SliverPadding(
                            padding: const EdgeInsets.all(AppTokens.space24),
                            sliver: SliverGrid.count(
                              crossAxisCount:
                                  MediaQuery.of(context).size.width > 600
                                  ? 4
                                  : 2,
                              mainAxisSpacing: AppTokens.space12,
                              crossAxisSpacing: AppTokens.space12,
                              children: [
                                _QuickActionCard(
                                  label: 'Sincronizar Cloud',
                                  icon: Icons.cloud_sync,
                                  onTap: () async {
                                    ref
                                        .read(
                                          globalSyncViewModelProvider.notifier,
                                        )
                                        .syncDownEverything();
                                  },
                                ),
                                _QuickActionCard(
                                  label: 'Novo Produto',
                                  icon: Icons.add_box_outlined,
                                  onTap: () => context.go('/admin/products'),
                                ),
                                _QuickActionCard(
                                  label: 'Criar Catálogo',
                                  icon: Icons.auto_awesome_motion_outlined,
                                  onTap: () => context.go('/admin/catalogs'),
                                ),
                                _QuickActionCard(
                                  label: 'Importar PDF',
                                  icon: Icons.picture_as_pdf_outlined,
                                  onTap: () =>
                                      context.go('/admin/imports/stock-update'),
                                ),
                                _QuickActionCard(
                                  label: 'Backup Cloud',
                                  icon: Icons.cloud_upload_outlined,
                                  onTap: () =>
                                      context.go('/admin/imports/backup'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
        if (syncProgress.isSyncing)
          SyncProgressOverlay(
            progress: syncProgress.progress,
            message: syncProgress.message,
          ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTokens.space20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        border: Border.all(color: Theme.of(context).dividerColor, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              Icon(Icons.trending_up, color: color.withOpacity(0.5), size: 16),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(title, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTokens.radiusMd),
      child: Container(
        padding: const EdgeInsets.all(AppTokens.space12),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).dividerColor, width: 0.5),
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppTokens.textSecondary, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
