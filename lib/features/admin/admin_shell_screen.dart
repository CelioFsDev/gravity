import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gravity/core/widgets/admin_drawer_header.dart';
import 'package:gravity/features/theme/theme_providers.dart';

class AdminShellScreen extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const AdminShellScreen({super.key, required this.navigationShell});

  static const _destinations = [
    _NavItem(icon: Icons.inventory, label: 'Produtos'),
    _NavItem(icon: Icons.category, label: 'Categorias'),
    _NavItem(icon: Icons.menu_book, label: 'Catálogos'),
    _NavItem(icon: Icons.cloud_download, label: 'Importações'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;
    void toggleTheme() {
      ref.read(themeModeProvider.notifier).state =
          isDark ? ThemeMode.light : ThemeMode.dark;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;
        return Scaffold(
          appBar: isWide
              ? null
              : AppBar(
                  title: Text(
                    _destinations[navigationShell.currentIndex].label,
                  ),
                  actions: [
                    IconButton(
                      tooltip: isDark ? 'Modo claro' : 'Modo noturno',
                      icon: Icon(
                        isDark ? Icons.light_mode : Icons.dark_mode,
                      ),
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
                        navigationShell.goBranch(index);
                        Navigator.of(context).pop();
                      },
                      children: [
                        const SizedBox(height: 12),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: AdminDrawerHeader(
                            title: 'Gravity Admin',
                            subtitle: 'Catálogos automatizados',
                            icon: Icons.auto_awesome,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ..._destinations
                            .map(
                              (item) => NavigationDrawerDestination(
                                icon: Icon(item.icon),
                                label: Text(item.label),
                              ),
                            )
                            .toList(),
                        const Divider(),
                        SwitchListTile(
                          title: const Text('Modo noturno'),
                          value: isDark,
                          onChanged: (_) => toggleTheme(),
                          secondary: Icon(
                            isDark ? Icons.dark_mode : Icons.light_mode,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          body: isWide
              ? Row(
                  children: [
                    NavigationRail(
                      minExtendedWidth: 220,
                      extended: true,
                      leading: Padding(
                        padding: const EdgeInsets.only(top: 12, bottom: 12),
                        child: Column(
                          children: const [
                            AdminDrawerHeader(
                              title: 'Gravity Admin',
                              subtitle: 'Catálogos automatizados',
                              icon: Icons.auto_awesome,
                            ),
                          ],
                        ),
                      ),
                      trailing: Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: IconButton(
                          tooltip: isDark ? 'Modo claro' : 'Modo noturno',
                          icon: Icon(
                            isDark ? Icons.light_mode : Icons.dark_mode,
                          ),
                          onPressed: toggleTheme,
                        ),
                      ),
                      destinations: _destinations
                          .map(
                            (item) => NavigationRailDestination(
                              icon: Icon(item.icon),
                              label: Text(item.label),
                            ),
                          )
                          .toList(),
                      selectedIndex: navigationShell.currentIndex,
                      onDestinationSelected: (index) =>
                          navigationShell.goBranch(index),
                    ),
                    const VerticalDivider(thickness: 1, width: 1),
                    Expanded(
                      child: Container(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1200),
                            child: navigationShell,
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              : SafeArea(child: navigationShell),
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
