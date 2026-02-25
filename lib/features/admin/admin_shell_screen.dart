import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:catalogo_ja/core/widgets/admin_drawer_header.dart';
import 'package:catalogo_ja/features/theme/theme_providers.dart';
import 'package:catalogo_ja/ui/theme/app_tokens.dart';

class AdminShellScreen extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const AdminShellScreen({super.key, required this.navigationShell});

  static const _destinations = [
    _NavItem(icon: Icons.inventory, label: 'Produtos'),
    _NavItem(icon: Icons.collections_bookmark, label: 'Cole\u00e7\u00f5es'),
    _NavItem(icon: Icons.category, label: 'Categorias'),
    _NavItem(icon: Icons.menu_book, label: 'Cat\u00e1logos'),
    _NavItem(icon: Icons.cloud_download, label: 'Importa\u00e7\u00f5es'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;
    void toggleTheme() {
      ref.read(themeModeProvider.notifier).state = isDark
          ? ThemeMode.light
          : ThemeMode.dark;
    }
    void onAdminNavigation(int index) {
      navigationShell.goBranch(index, initialLocation: index == 0);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;
        return Scaffold(
          appBar: isWide
              ? null
              : AppBar(
                  elevation: 0,
                  scrolledUnderElevation: 0,
                  title: Text(
                    _destinations[navigationShell.currentIndex].label,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  actions: [
                    IconButton(
                      tooltip: isDark ? 'Modo claro' : 'Modo noturno',
                      icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
                      onPressed: toggleTheme,
                    ),
                  ],
                  leading: Builder(
                    builder: (context) => IconButton(
                      icon: const Icon(Icons.menu),
                      onPressed: () => Scaffold.of(context).openDrawer(),
                    ),
                  ),
                ),
          drawer: isWide
              ? null
              : Drawer(
                  child: SafeArea(
                    child: NavigationDrawer(
                      selectedIndex: navigationShell.currentIndex,
                      onDestinationSelected: (index) {
                        onAdminNavigation(index);
                        Navigator.of(context).pop();
                      },
                      children: [
                        const SizedBox(height: AppTokens.space24),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: AdminDrawerHeader(
                            title: 'CatalogoJa Admin',
                            subtitle: 'Cat\u00e1logos automatizados',
                            icon: Icons.auto_awesome_outlined,
                          ),
                        ),
                        const SizedBox(height: AppTokens.space24),
                        ..._destinations.map(
                          (item) => NavigationDrawerDestination(
                            icon: Icon(item.icon),
                            selectedIcon: Icon(
                              item.icon,
                              color: AppTokens.accentBlue,
                            ),
                            label: Text(item.label),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.all(AppTokens.space16),
                          child: Divider(),
                        ),
                        SwitchListTile.adaptive(
                          title: const Text(
                            'Modo noturno',
                            style: TextStyle(fontSize: 14),
                          ),
                          value: isDark,
                          onChanged: (_) => toggleTheme(),
                          activeColor: AppTokens.accentBlue,
                          secondary: Icon(
                            isDark
                                ? Icons.dark_mode_outlined
                                : Icons.light_mode_outlined,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          body: isWide
              ? Row(
                  children: [
                    Container(
                      width: 280,
                      decoration: BoxDecoration(
                        border: Border(
                          right: BorderSide(color: Theme.of(context).dividerColor),
                        ),
                      ),
                      child: SafeArea(
                        child: NavigationDrawer(
                          selectedIndex: navigationShell.currentIndex,
                          onDestinationSelected: onAdminNavigation,
                          children: [
                            const SizedBox(height: AppTokens.space24),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16),
                              child: AdminDrawerHeader(
                                title: 'CatalogoJa Admin',
                                subtitle: 'Beta Version',
                                icon: Icons.auto_awesome_outlined,
                              ),
                            ),
                            const SizedBox(height: AppTokens.space24),
                            ..._destinations.map(
                              (item) => NavigationDrawerDestination(
                                icon: Icon(item.icon),
                                selectedIcon: Icon(
                                  item.icon,
                                  color: AppTokens.accentBlue,
                                ),
                                label: Text(item.label),
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.all(AppTokens.space16),
                              child: Divider(),
                            ),
                            SwitchListTile.adaptive(
                              title: const Text(
                                'Modo noturno',
                                style: TextStyle(fontSize: 14),
                              ),
                              value: isDark,
                              onChanged: (_) => toggleTheme(),
                              activeColor: AppTokens.accentBlue,
                              secondary: Icon(
                                isDark
                                    ? Icons.dark_mode_outlined
                                    : Icons.light_mode_outlined,
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(child: navigationShell),
                  ],
                )
              : navigationShell,
        );
      },
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;

  const _NavItem({required this.icon, required this.label});
}
