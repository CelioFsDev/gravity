import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:catalogo_ja/features/theme/theme_providers.dart';
import 'package:catalogo_ja/ui/theme/app_tokens.dart';
import 'package:catalogo_ja/viewmodels/auth_viewmodel.dart';
import 'package:catalogo_ja/viewmodels/tenant_viewmodel.dart';
import 'package:catalogo_ja/core/auth/user_role.dart';

class AdminShellScreen extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const AdminShellScreen({super.key, required this.navigationShell});

  static final _destinations = [
    _NavItem(
      branchIndex: 0,
      icon: Icons.home_rounded,
      iconOutlined: Icons.home_outlined,
      label: 'Início',
      color: AppTokens.electricBlue,
    ),
    _NavItem(
      branchIndex: 1,
      icon: Icons.inventory_2_rounded,
      iconOutlined: Icons.inventory_2_outlined,
      label: 'Produtos',
      color: AppTokens.accentGreen,
    ),
    _NavItem(
      branchIndex: 2,
      icon: Icons.collections_bookmark_rounded,
      iconOutlined: Icons.collections_bookmark_outlined,
      label: 'Coleções',
      color: AppTokens.softPurple,
    ),
    _NavItem(
      branchIndex: 3,
      icon: Icons.category_rounded,
      iconOutlined: Icons.category_outlined,
      label: 'Categorias',
      color: AppTokens.accentOrange,
    ),
    _NavItem(
      branchIndex: 4,
      icon: Icons.menu_book_rounded,
      iconOutlined: Icons.menu_book_outlined,
      label: 'Catálogos',
      color: AppTokens.vibrantPink,
    ),
    _NavItem(
      branchIndex: 5,
      icon: Icons.cloud_download_rounded,
      iconOutlined: Icons.cloud_download_outlined,
      label: 'Importações',
      color: AppTokens.vibrantCyan,
    ),
    _NavItem(
      branchIndex: 6,
      icon: Icons.person_rounded,
      iconOutlined: Icons.person_outline,
      label: 'Meu Perfil',
      color: AppTokens.electricBlue,
    ),
    _NavItem(
      branchIndex: 7,
      icon: Icons.campaign_rounded,
      iconOutlined: Icons.campaign_outlined,
      label: 'Divulgação',
      color: AppTokens.accentGold,
    ),
    _NavItem(
      branchIndex: 8,
      icon: Icons.settings_rounded,
      iconOutlined: Icons.settings_outlined,
      label: 'Ajustes',
      color: AppTokens.textSecondaryDark,
    ),
    _NavItem(
      branchIndex: 9,
      icon: Icons.backup_rounded,
      iconOutlined: Icons.backup_outlined,
      label: 'Backup',
      color: AppTokens.accentGreen,
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void onAdminNavigation(int index) {
      navigationShell.goBranch(
        index,
        initialLocation: index == navigationShell.currentIndex,
      );
    }

    final authUser = ref.watch(authViewModelProvider).valueOrNull;
    final currentRole = ref.watch(currentRoleProvider);
    final visibleDestinations = _destinations
        .where((item) => item.isVisibleFor(currentRole))
        .toList();

    final tenantAsync = ref.watch(currentTenantProvider);
    final tenant = tenantAsync.valueOrNull;

    final displayTitle = tenant?.name ?? authUser?.displayName ?? 'Admin';
    final logoUrl = tenant?.logoUrl ?? authUser?.photoURL;

    final state = GoRouterState.of(context);
    final location = state.matchedLocation;

    final isRootPage = [
      '/admin/dashboard',
      '/admin/products',
      '/admin/collections',
      '/admin/categories',
      '/admin/catalogs',
      '/admin/imports',
      '/admin/profile',
      '/admin/share',
      '/admin/settings',
      '/admin/backup',
    ].contains(location);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;
        final isDark = Theme.of(context).brightness == Brightness.dark;

        // Bottom nav: Início, Produtos, Catálogos, Divulgação, Ajustes
        final bottomNavIndices = [0, 1, 4, 7, 8];

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          drawer: isWide
              ? null
              : Drawer(
                  backgroundColor: AppTokens.deepNavy,
                  child: _Sidebar(
                    currentIndex: navigationShell.currentIndex,
                    onDestinationSelected: (index) {
                      onAdminNavigation(index);
                      Navigator.pop(context);
                    },
                    displayTitle: displayTitle,
                    logoUrl: logoUrl,
                    visibleDestinations: visibleDestinations,
                    authEmail: authUser?.email,
                    ref: ref,
                  ),
                ),
          body: isWide
              ? Row(
                  children: [
                    _Sidebar(
                      currentIndex: navigationShell.currentIndex,
                      onDestinationSelected: onAdminNavigation,
                      displayTitle: displayTitle,
                      logoUrl: logoUrl,
                      visibleDestinations: visibleDestinations,
                      authEmail: authUser?.email,
                      ref: ref,
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(32),
                          bottomLeft: Radius.circular(32),
                        ),
                        child: Container(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          child: navigationShell,
                        ),
                      ),
                    ),
                  ],
                )
              : Column(
                  children: [
                    Expanded(
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: Container(
                              color: Theme.of(context).scaffoldBackgroundColor,
                              padding: EdgeInsets.only(
                                bottom: isRootPage ? 96 : 0,
                              ),
                              child: navigationShell,
                            ),
                          ),
                          if (isRootPage)
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: SafeArea(
                                top: false,
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    0,
                                    16,
                                    12,
                                  ),
                                  child: _FloatingBottomNav(
                                    currentIndex: navigationShell.currentIndex,
                                    onDestinationSelected: onAdminNavigation,
                                    visibleIndices: bottomNavIndices
                                        .where(
                                          (index) => visibleDestinations.any(
                                            (item) => item.branchIndex == index,
                                          ),
                                        )
                                        .toList(),
                                    isDark: isDark,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}

// ─── Sidebar ──────────────────────────────────────────────────────────────────

class _Sidebar extends ConsumerWidget {
  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;
  final String displayTitle;
  final String? logoUrl;
  final List<_NavItem> visibleDestinations;
  final String? authEmail;
  final WidgetRef ref;

  const _Sidebar({
    required this.currentIndex,
    required this.onDestinationSelected,
    required this.displayTitle,
    required this.visibleDestinations,
    required this.authEmail,
    required this.ref,
    this.logoUrl,
  });

  @override
  Widget build(BuildContext context, WidgetRef widgetRef) {
    final isDark = widgetRef.watch(themeModeProvider) == ThemeMode.dark;

    return Container(
      width: 268,
      decoration: const BoxDecoration(
        color: AppTokens.deepNavy,
        border: Border(right: BorderSide(color: Color(0xFF0E1B38), width: 1)),
      ),
      child: Column(
        children: [
          // ── Top: Logo + Company ────────────────────────────────────────
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: Column(
                children: [
                  // App logo row
                  Row(
                    children: [
                      // Logo box
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          gradient: logoUrl == null
                              ? AppTokens.primaryGradient
                              : null,
                          image: logoUrl != null
                              ? DecorationImage(
                                  image: NetworkImage(logoUrl!),
                                  fit: BoxFit.cover,
                                )
                              : null,
                          boxShadow: [
                            BoxShadow(
                              color: AppTokens.electricBlue.withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: logoUrl == null
                            ? Image.asset(
                                'assets/branding/icons/catalogoja_icons_glass_1024x1024.png',
                                fit: BoxFit.contain,
                                errorBuilder: (_, _, _) => const Icon(
                                  Icons.auto_awesome_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Catálogo Já',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.2,
                              ),
                            ),
                            // Premium badge
                            Container(
                              margin: const EdgeInsets.only(top: 2),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(
                                  AppTokens.radiusFull,
                                ),
                                gradient: AppTokens.goldGradient,
                              ),
                              child: const Text(
                                'PREMIUM',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Theme toggle
                      IconButton(
                        onPressed: () {
                          widgetRef.read(themeModeProvider.notifier).state =
                              isDark ? ThemeMode.light : ThemeMode.dark;
                        },
                        icon: Icon(
                          isDark
                              ? Icons.light_mode_outlined
                              : Icons.dark_mode_outlined,
                          color: Colors.white38,
                          size: 18,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Company card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                      color: Colors.white.withOpacity(0.04),
                      border: Border.all(color: Colors.white.withOpacity(0.06)),
                    ),
                    child: Row(
                      children: [
                        // Avatar
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            gradient: AppTokens.accentGradient,
                          ),
                          child: Center(
                            child: Text(
                              displayTitle.isNotEmpty
                                  ? displayTitle[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayTitle,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                              if (authEmail != null)
                                Text(
                                  authEmail!,
                                  style: const TextStyle(
                                    color: Colors.white38,
                                    fontSize: 11,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),
          Container(height: 1, color: Colors.white.withOpacity(0.06)),
          const SizedBox(height: 8),

          // ── Nav items ─────────────────────────────────────────────────
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              itemCount: visibleDestinations.length,
              itemBuilder: (context, index) {
                final item = visibleDestinations[index];
                return _SidebarItem(
                  item: item,
                  isSelected: currentIndex == item.branchIndex,
                  onTap: () => onDestinationSelected(item.branchIndex),
                );
              },
            ),
          ),

          // ── Bottom: Logout ─────────────────────────────────────────────
          Container(height: 1, color: Colors.white.withOpacity(0.06)),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(AppTokens.radiusMd),
              child: InkWell(
                onTap: () =>
                    widgetRef.read(authViewModelProvider.notifier).signOut(),
                borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.logout_rounded,
                        size: 18,
                        color: Colors.red.shade400,
                      ),
                      const SizedBox(width: 14),
                      Text(
                        'Sair',
                        style: TextStyle(
                          color: Colors.red.shade400,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SafeArea(top: false, child: SizedBox(height: 8)),
        ],
      ),
    );
  }
}

// ─── Sidebar Item ─────────────────────────────────────────────────────────────

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  final _NavItem item;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTokens.radiusMd),
              color: isSelected
                  ? item.color.withOpacity(0.12)
                  : Colors.transparent,
              border: isSelected
                  ? Border.all(color: item.color.withOpacity(0.2))
                  : null,
            ),
            child: Row(
              children: [
                // Icon
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    isSelected ? item.icon : item.iconOutlined,
                    key: ValueKey(isSelected),
                    size: 20,
                    color: isSelected ? item.color : Colors.white38,
                  ),
                ),
                const SizedBox(width: 14),
                // Label
                Expanded(
                  child: Text(
                    item.label,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white54,
                      fontSize: 14,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ),
                // Active dot
                if (isSelected)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: item.color,
                      boxShadow: [
                        BoxShadow(
                          color: item.color.withOpacity(0.5),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Floating Bottom Nav ──────────────────────────────────────────────────────

class _FloatingBottomNav extends StatelessWidget {
  const _FloatingBottomNav({
    required this.currentIndex,
    required this.onDestinationSelected,
    required this.visibleIndices,
    required this.isDark,
  });

  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<int> visibleIndices;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 68,
      decoration: BoxDecoration(
        color: isDark ? AppTokens.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(AppTokens.radiusFull),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.5 : 0.12),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.07)
              : Colors.black.withOpacity(0.04),
        ),
      ),
      child: Row(
        children: visibleIndices.map((index) {
          final item = AdminShellScreen._destinations[index];
          final isSelected = currentIndex == index;

          return Expanded(
            child: GestureDetector(
              onTap: () => onDestinationSelected(index),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppTokens.radiusFull),
                  gradient: isSelected ? AppTokens.primaryGradient : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        isSelected ? item.icon : item.iconOutlined,
                        key: ValueKey(isSelected),
                        size: 22,
                        color: isSelected
                            ? Colors.white
                            : (isDark ? Colors.white38 : Colors.black38),
                      ),
                    ),
                    if (!isSelected) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── NavItem Model ────────────────────────────────────────────────────────────

class _NavItem {
  final int branchIndex;
  final IconData icon;
  final IconData iconOutlined;
  final String label;
  final Color color;

  const _NavItem({
    required this.branchIndex,
    required this.icon,
    required this.iconOutlined,
    required this.label,
    required this.color,
  });

  bool isVisibleFor(UserRole role) {
    return switch (branchIndex) {
      0 => role.canViewDashboard,
      1 => role.canViewProducts,
      2 => role.canViewCollections,
      3 => role.canViewCategories,
      4 => role.canViewCatalogs,
      5 => role.canViewImports,
      6 => role.canViewProfile,
      7 => role.canShare,
      8 => role.canViewSettings,
      9 => role.canViewBackup,
      _ => false,
    };
  }
}
