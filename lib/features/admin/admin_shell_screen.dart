import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AdminShellScreen extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const AdminShellScreen({super.key, required this.navigationShell});

  static const _destinations = [
    _NavItem(icon: Icons.inventory, label: 'Products'),
    _NavItem(icon: Icons.category, label: 'Categories'),
    _NavItem(icon: Icons.menu_book, label: 'Catalogs'),
  ];

  @override
  Widget build(BuildContext context) {
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
                    child: Column(
                      children: [
                        const SizedBox(height: 8),
                        ...List.generate(
                          _destinations.length,
                          (index) => ListTile(
                            leading: Icon(_destinations[index].icon),
                            title: Text(_destinations[index].label),
                            selected: navigationShell.currentIndex == index,
                            onTap: () {
                              navigationShell.goBranch(index);
                              Navigator.of(context).pop();
                            },
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
