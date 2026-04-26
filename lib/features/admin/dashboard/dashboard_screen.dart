import 'package:catalogo_ja/viewmodels/products_viewmodel.dart';
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
import 'package:catalogo_ja/data/repositories/settings_repository.dart';
import 'package:catalogo_ja/ui/widgets/sync_progress_overlay.dart';
import 'package:catalogo_ja/viewmodels/auth_viewmodel.dart';
import 'package:intl/intl.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _greetingController;
  late Animation<double> _greetingFade;

  @override
  void initState() {
    super.initState();
    _greetingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _greetingFade = CurvedAnimation(
      parent: _greetingController,
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _greetingController.dispose();
    super.dispose();
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Bom dia';
    if (hour < 18) return 'Boa tarde';
    return 'Boa noite';
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsRepositoryProvider).watchProducts();
    final categoriesAsync = ref
        .watch(categoriesRepositoryProvider)
        .watchCategories();
    final catalogsAsync = ref.watch(catalogsRepositoryProvider).watchCatalogs();
    final syncProgress = ref.watch(syncProgressProvider);
    final settings = ref.watch(settingsRepositoryProvider).getSettings();
    final authUser = ref.watch(authViewModelProvider).valueOrNull;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!syncProgress.isSyncing && settings.isInitialSyncCompleted) {
        ref.read(globalSyncViewModelProvider.notifier).performSilentWifiSync();
      }
    });

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final firstName = authUser?.displayName?.split(' ').first ?? 'Usuário';

    return Stack(
      children: [
        AppScaffold(
          showHeader: false,
          title: 'Início',
          subtitle: 'Visão geral',
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
                          // ── Welcome Banner ──────────────────────────────
                          SliverToBoxAdapter(
                            child: FadeTransition(
                              opacity: _greetingFade,
                              child: _WelcomeBanner(
                                greeting: _greeting(),
                                firstName: firstName,
                                isDark: isDark,
                                onSync: () => ref
                                    .read(globalSyncViewModelProvider.notifier)
                                    .syncDownEverything(),
                              ),
                            ),
                          ),

                          // ── Stats Grid ──────────────────────────────────
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                            sliver: SliverToBoxAdapter(
                              child: _buildStatsSection(
                                context,
                                productCount: productCount,
                                categoryCount: categoryCount,
                                catalogCount: catalogCount,
                                isDark: isDark,
                              ),
                            ),
                          ),

                          // ── Quick Actions ────────────────────────────────
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                            sliver: SliverToBoxAdapter(
                              child: Row(
                                children: [
                                  Container(
                                    width: 4,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(
                                        AppTokens.radiusFull,
                                      ),
                                      gradient: AppTokens.primaryGradient,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Ações Rápidas',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: isDark
                                          ? Colors.white
                                          : AppTokens.textPrimary,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                            sliver: SliverGrid(
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount:
                                        MediaQuery.of(context).size.width > 600
                                        ? 4
                                        : 3,
                                    mainAxisSpacing: 12,
                                    crossAxisSpacing: 12,
                                    childAspectRatio: 1.0,
                                  ),
                              delegate: SliverChildListDelegate([
                                _QuickActionCard(
                                  label: 'Sincronizar',
                                  icon: Icons.cloud_sync_rounded,
                                  gradient: AppTokens.primaryGradient,
                                  isDark: isDark,
                                  onTap: () => ref
                                      .read(
                                        globalSyncViewModelProvider.notifier,
                                      )
                                      .syncDownEverything(),
                                ),
                                _QuickActionCard(
                                  label: 'Novo Produto',
                                  icon: Icons.add_box_rounded,
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF10B981),
                                      Color(0xFF059669),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  isDark: isDark,
                                  onTap: () => context.go('/admin/products'),
                                ),
                                _QuickActionCard(
                                  label: 'Criar Catálogo',
                                  icon: Icons.auto_awesome_motion_rounded,
                                  gradient: AppTokens.accentGradient,
                                  isDark: isDark,
                                  onTap: () => context.go('/admin/catalogs'),
                                ),
                                _QuickActionCard(
                                  label: 'Importar PDF',
                                  icon: Icons.picture_as_pdf_rounded,
                                  gradient: AppTokens.warmGradient,
                                  isDark: isDark,
                                  onTap: () =>
                                      context.go('/admin/imports/stock-update'),
                                ),
                                _QuickActionCard(
                                  label: 'Backup',
                                  icon: Icons.cloud_upload_rounded,
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF0EA5E9),
                                      Color(0xFF0284C7),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  isDark: isDark,
                                  onTap: () =>
                                      context.go('/admin/imports/backup'),
                                ),
                                _QuickActionCard(
                                  label: 'Compartilhar',
                                  icon: Icons.share_rounded,
                                  gradient: AppTokens.goldGradient,
                                  isDark: isDark,
                                  onTap: () => context.go('/admin/share'),
                                ),
                              ]),
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

  Widget _buildStatsSection(
    BuildContext context, {
    required int productCount,
    required int categoryCount,
    required int catalogCount,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 20,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppTokens.radiusFull),
                gradient: AppTokens.accentGradient,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Resumo',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : AppTokens.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 500;
            if (isWide) {
              return Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      title: 'Produtos',
                      value: productCount,
                      icon: Icons.inventory_2_rounded,
                      gradient: AppTokens.primaryGradient,
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      title: 'Coleções',
                      value: categoryCount,
                      icon: Icons.collections_bookmark_rounded,
                      gradient: AppTokens.accentGradient,
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      title: 'Catálogos',
                      value: catalogCount,
                      icon: Icons.menu_book_rounded,
                      gradient: AppTokens.warmGradient,
                      isDark: isDark,
                    ),
                  ),
                ],
              );
            }
            return Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        title: 'Produtos',
                        value: productCount,
                        icon: Icons.inventory_2_rounded,
                        gradient: AppTokens.primaryGradient,
                        isDark: isDark,
                        compact: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        title: 'Coleções',
                        value: categoryCount,
                        icon: Icons.collections_bookmark_rounded,
                        gradient: AppTokens.accentGradient,
                        isDark: isDark,
                        compact: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _StatCard(
                  title: 'Catálogos',
                  value: catalogCount,
                  icon: Icons.menu_book_rounded,
                  gradient: AppTokens.warmGradient,
                  isDark: isDark,
                  compact: true,
                  fullWidth: true,
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

// ─── Welcome Banner ───────────────────────────────────────────────────────────

class _WelcomeBanner extends StatelessWidget {
  const _WelcomeBanner({
    required this.greeting,
    required this.firstName,
    required this.isDark,
    required this.onSync,
  });

  final String greeting;
  final String firstName;
  final bool isDark;
  final VoidCallback onSync;

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat(
      "EEEE, d 'de' MMMM",
      'pt_BR',
    ).format(DateTime.now());

    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTokens.radiusXl),
        gradient: const LinearGradient(
          colors: [Color(0xFF1A3A6B), Color(0xFF0D2244), Color(0xFF051530)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTokens.electricBlue.withOpacity(0.2),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
        border: Border.all(
          color: AppTokens.electricBlue.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Stack(
        children: [
          // Decorative glow orb
          Positioned(
            right: -20,
            top: -20,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTokens.vibrantCyan.withOpacity(0.15),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date chip
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppTokens.radiusFull),
                  color: Colors.white.withOpacity(0.08),
                ),
                child: Text(
                  dateStr,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.white60,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Greeting
              Text(
                '$greeting, $firstName! 👋',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.5,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Tudo pronto para começar a vender.',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white60,
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 16),

              // Sync button
              GestureDetector(
                onTap: onSync,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppTokens.radiusFull),
                    gradient: AppTokens.primaryGradient,
                    boxShadow: [
                      BoxShadow(
                        color: AppTokens.electricBlue.withOpacity(0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.cloud_sync_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Sincronizar',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Stat Card ────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.gradient,
    required this.isDark,
    this.compact = false,
    this.fullWidth = false,
  });

  final String title;
  final int value;
  final IconData icon;
  final LinearGradient gradient;
  final bool isDark;
  final bool compact;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(compact ? 16 : 20),
      decoration: BoxDecoration(
        color: isDark ? AppTokens.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        border: Border.all(
          color: isDark ? AppTokens.borderDark : AppTokens.borderLight,
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: fullWidth
          ? Row(
              children: [
                _iconBox(),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [_valueText(), _titleText()],
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _iconBox(),
                SizedBox(height: compact ? 12 : 16),
                _valueText(),
                _titleText(),
              ],
            ),
    );
  }

  Widget _iconBox() {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: gradient,
      ),
      child: Icon(icon, color: Colors.white, size: 20),
    );
  }

  Widget _valueText() {
    return Text(
      value.toString(),
      style: TextStyle(
        fontSize: compact ? 26 : 32,
        fontWeight: FontWeight.w900,
        color: isDark ? Colors.white : AppTokens.textPrimary,
        letterSpacing: -1,
        height: 1.0,
      ),
    );
  }

  Widget _titleText() {
    return Text(
      title,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: isDark ? Colors.white : AppTokens.textMuted,
      ),
    );
  }
}

// ─── Quick Action Card ────────────────────────────────────────────────────────

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.label,
    required this.icon,
    required this.gradient,
    required this.isDark,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final LinearGradient gradient;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppTokens.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
            color: isDark ? AppTokens.cardDark : Colors.white,
            border: Border.all(
              color: isDark ? AppTokens.borderDark : AppTokens.borderLight,
            ),
            boxShadow: isDark
                ? []
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: gradient,
                  ),
                  child: Icon(icon, color: Colors.white, size: 20),
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white70 : AppTokens.textSecondary,
                    letterSpacing: -0.1,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
