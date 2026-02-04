import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gravity/core/widgets/admin_drawer_header.dart';
import 'package:gravity/features/theme/theme_providers.dart';
import 'package:gravity/ui/theme/app_tokens.dart';

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
      ref.read(themeModeProvider.notifier).state = isDark
          ? ThemeMode.light
          : ThemeMode.dark;
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
                        navigationShell.goBranch(index);
                        Navigator.of(context).pop();
                      },
                      children: [
                        const SizedBox(height: AppTokens.space24),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: AdminDrawerHeader(
                            title: 'Gravity Admin',
                            subtitle: 'Catálogos automatizados',
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
                      decoration: BoxDecoration(
                        border: Border(
                          right: BorderSide(
                            color: Theme.of(context).dividerColor,
                          ),
                        ),
                      ),
                      child: NavigationRail(
                        minExtendedWidth: 240,
                        extended: true,
                        leading: const Padding(
                          padding: EdgeInsets.symmetric(
                            vertical: 32,
                            horizontal: 16,
                          ),
                          child: AdminDrawerHeader(
                            title: 'Gravity Admin',
                            subtitle: 'Beta Version',
                            icon: Icons.auto_awesome_outlined,
                          ),
                        ),
                        trailing: Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 24),
                              child: _ThemeToggleButton(
                                isDark: isDark,
                                onToggle: toggleTheme,
                              ),
                            ),
                          ),
                        ),
                        destinations: _destinations
                            .map(
                              (item) => NavigationRailDestination(
                                icon: Icon(item.icon, size: 22),
                                selectedIcon: Icon(
                                  item.icon,
                                  color: AppTokens.accentBlue,
                                  size: 22,
                                ),
                                label: Text(
                                  item.label,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                        selectedIndex: navigationShell.currentIndex,
                        onDestinationSelected: (index) =>
                            navigationShell.goBranch(index),
                        indicatorColor: AppTokens.accentBlue.withOpacity(0.08),
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

class _ThemeToggleButton extends StatelessWidget {
  final bool isDark;
  final VoidCallback onToggle;

  const _ThemeToggleButton({required this.isDark, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              isDark ? 'Modo Claro' : 'Modo Escuro',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;

  const _NavItem({required this.icon, required this.label});
}
