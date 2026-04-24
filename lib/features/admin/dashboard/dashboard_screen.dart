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
          showHeader: true,
          title: 'In\u00edcio',
          subtitle: 'Vis\u00e3o geral do seu neg\u00f3cio',
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
                                _QuickActionCard(
                                  label: 'Catálogo Público',
                                  icon: Icons.public_rounded,
                                  onTap: () => context.go('/admin/catalogs'),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.03) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
          width: 1,
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: color.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color, color.withOpacity(0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : Colors.black87,
              letterSpacing: -1,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white54 : Colors.black45,
              fontWeight: FontWeight.w600,
            ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.02) : AppTokens.deepNavy.withOpacity(0.03),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ShaderMask(
                shaderCallback: (bounds) => AppTokens.primaryGradient.createShader(bounds),
                child: Icon(icon, color: Colors.white, size: 32),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white70 : Colors.black87,
                  letterSpacing: -0.2,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
