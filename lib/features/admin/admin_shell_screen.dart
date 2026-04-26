import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:catalogo_ja/features/theme/theme_providers.dart';
import 'package:catalogo_ja/ui/theme/app_tokens.dart';
import 'package:catalogo_ja/viewmodels/auth_viewmodel.dart';
import 'package:catalogo_ja/viewmodels/tenant_viewmodel.dart';
import 'package:catalogo_ja/core/auth/user_role.dart';
import 'package:catalogo_ja/ui/theme/app_icons.dart';

class AdminShellScreen extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const AdminShellScreen({super.key, required this.navigationShell});

  static final _destinations = [
    _NavItem(
      branchIndex: 0,
      icon: Icons.dashboard_outlined,
      label: 'In\u00edcio',
      premiumIcon: (size) => AppIcons.dashboard(size: size),
    ),
    _NavItem(
      branchIndex: 1,
      icon: Icons.inventory_2_outlined,
      label: 'Produtos',
      premiumIcon: (size) => AppIcons.products(size: size),
    ),
    _NavItem(
      branchIndex: 2,
      icon: Icons.collections_bookmark_outlined,
      label: 'Cole\u00e7\u00f5es',
      premiumIcon: (size) => AppIcons.collections(size: size),
    ),
    _NavItem(
      branchIndex: 3,
      icon: Icons.category_outlined,
      label: 'Categorias',
      premiumIcon: (size) => AppIcons.categories(size: size),
    ),
    _NavItem(
      branchIndex: 4,
      icon: Icons.menu_book_outlined,
      label: 'Cat\u00e1logos',
    ),
    _NavItem(
      branchIndex: 5,
      icon: Icons.cloud_download_outlined,
      label: 'Importa\u00e7\u00f5es',
    ),
    _NavItem(branchIndex: 6, icon: Icons.person_outline, label: 'Meu Perfil'),
    _NavItem(
      branchIndex: 7,
      icon: Icons.share_location_outlined,
      label: 'Divulga\u00e7\u00e3o',
    ),
    _NavItem(
      branchIndex: 8,
      icon: Icons.settings_outlined,
      label: 'Ajustes',
      premiumIcon: (size) => AppIcons.settings(size: size),
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

    // Check if we are on a root page of any branch
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
    ].contains(location);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;
        final isDark = Theme.of(context).brightness == Brightness.dark;

        final bottomNavIndices = [
          0,
          1,
          4,
          7,
          8,
        ]; // Início, Produtos, Catálogos, Divulgação, Ajustes

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          drawer: isWide
              ? null
              : Drawer(
                  child: _Sidebar(
                    currentIndex: navigationShell.currentIndex,
                    onDestinationSelected: (index) {
                      onAdminNavigation(index);
                      Navigator.pop(context);
                    },
                    displayTitle: displayTitle,
                    logoUrl: logoUrl,
                    visibleDestinations: visibleDestinations,
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
                          // Main Content Area
                          Positioned.fill(
                            child: Container(
                              color: Theme.of(context).scaffoldBackgroundColor,
                              padding: EdgeInsets.only(
                                bottom: isRootPage ? 100 : 0,
                              ),
                              child: navigationShell,
                            ),
                          ),

                          // Floating Mobile Bottom Nav
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
                                    16,
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

class _Sidebar extends ConsumerWidget {
  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;
  final String displayTitle;
  final String? logoUrl;
  final List<_NavItem> visibleDestinations;

  const _Sidebar({
    required this.currentIndex,
    required this.onDestinationSelected,
    required this.displayTitle,
    this.logoUrl,
    required this.visibleDestinations,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;

    return Container(
      width: 280,
      color: AppTokens.deepNavy,
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
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
                  ),
                  child: logoUrl == null
                      ? const Icon(
                          Icons.auto_awesome_rounded,
                          color: Colors.white,
                          size: 24,
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    displayTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 24),
            leading: Icon(
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              color: Colors.white54,
              size: 20,
            ),
            title: Text(
              isDark ? 'Modo Claro' : 'Modo Escuro',
              style: const TextStyle(color: Colors.white60, fontSize: 14),
            ),
            onTap: () {
              ref.read(themeModeProvider.notifier).state = isDark
                  ? ThemeMode.light
                  : ThemeMode.dark;
            },
          ),
          const Divider(color: Colors.white10),

          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: visibleDestinations.length,
              separatorBuilder: (_, _) => const SizedBox(height: 4),
              itemBuilder: (context, index) {
                final item = visibleDestinations[index];
                return _SidebarItem(
                  icon: item.icon,
                  label: item.label,
                  isSelected: currentIndex == item.branchIndex,
                  premiumIcon: item.premiumIcon,
                  onTap: () => onDestinationSelected(item.branchIndex),
                );
              },
            ),
          ),

          _SidebarItem(
            icon: Icons.logout_rounded,
            label: 'Sair',
            isSelected: false,
            color: Colors.redAccent.withOpacity(0.7),
            onTap: () => ref.read(authViewModelProvider.notifier).signOut(),
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? color;
  final Widget Function(double size)? premiumIcon;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.color,
    this.premiumIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: isSelected
                ? AppTokens.primaryGradient.withOpacity(0.1)
                : null,
            border: isSelected
                ? Border.all(color: AppTokens.vibrantCyan.withOpacity(0.2))
                : null,
          ),
          child: Row(
            children: [
              if (premiumIcon != null)
                Opacity(
                  opacity: isSelected ? 1.0 : 0.6,
                  child: premiumIcon!(20),
                )
              else
                Icon(
                  icon,
                  size: 22,
                  color: isSelected
                      ? AppTokens.vibrantCyan
                      : (color ?? Colors.white70),
                ),
              const SizedBox(width: 16),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : (color ?? Colors.white60),
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                ),
              ),
              if (isSelected) ...[
                const Spacer(),
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTokens.vibrantCyan,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FloatingBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<int> visibleIndices;

  const _FloatingBottomNav({
    required this.currentIndex,
    required this.onDestinationSelected,
    required this.visibleIndices,
  });
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: isDark ? AppTokens.deepNavy : Colors.white,
        borderRadius: BorderRadius.circular(36),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.4 : 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: visibleIndices.map((index) {
          final item = AdminShellScreen._destinations[index];
          final isSelected = currentIndex == index;

          return Expanded(
            child: InkWell(
              onTap: () => onDestinationSelected(index),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (item.premiumIcon != null)
                    Opacity(
                      opacity: isSelected ? 1.0 : 0.5,
                      child: item.premiumIcon!(isSelected ? 28 : 24),
                    )
                  else
                    Icon(
                      item.icon,
                      color: isSelected
                          ? (isDark
                                ? AppTokens.vibrantCyan
                                : AppTokens.electricBlue)
                          : (isDark ? Colors.white54 : Colors.black38),
                      size: 24,
                    ),
                  if (isSelected)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark
                            ? AppTokens.vibrantCyan
                            : AppTokens.electricBlue,
                      ),
                    ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _NavItem {
  final int branchIndex;
  final IconData icon;
  final String label;
  final Widget Function(double size)? premiumIcon;

  const _NavItem({
    required this.branchIndex,
    required this.icon,
    required this.label,
    this.premiumIcon,
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
      _ => false,
    };
  }
}
