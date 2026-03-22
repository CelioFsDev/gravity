import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:catalogo_ja/core/widgets/admin_drawer_header.dart';
import 'package:catalogo_ja/features/theme/theme_providers.dart';
import 'package:catalogo_ja/ui/theme/app_tokens.dart';
import 'package:catalogo_ja/viewmodels/auth_viewmodel.dart';
import 'package:catalogo_ja/viewmodels/tenant_viewmodel.dart';
import 'package:catalogo_ja/core/auth/user_role.dart';

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

    final authUser = ref.watch(authViewModelProvider).valueOrNull;
    final currentRole = ref.watch(currentRoleProvider);
    final canManageUsers = currentRole.canManageUsers(authUser?.email);

    final tenantAsync = ref.watch(currentTenantProvider);
    final tenant = tenantAsync.valueOrNull;

    final displayTitle = tenant?.name ?? authUser?.displayName ?? 'Admin';
    final displaySubtitle = tenant?.subtitle ?? authUser?.email ?? 'Empresa n\u00e3o identificada';
    final logoUrl = tenant?.logoUrl ?? authUser?.photoURL;

    String getEffectiveTitle(BuildContext context) {
      final location = GoRouterState.of(context).matchedLocation;
      if (location.startsWith('/admin/settings/users')) return 'Usu\u00e1rios';
      if (location.startsWith('/admin/settings/profile')) return 'Meu Perfil';
      if (location.startsWith('/admin/settings')) return 'Ajustes';
      if (navigationShell.currentIndex < _destinations.length) {
        return _destinations[navigationShell.currentIndex].label;
      }
      return '';
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
                    getEffectiveTitle(context),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  actions: [
                    if (canManageUsers)
                      IconButton(
                        tooltip: 'Gerenciar Usuários',
                        icon: const Icon(Icons.people_alt_outlined),
                        onPressed: () => context.push('/admin/settings/users'),
                      ),
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
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: AdminDrawerHeader(
                            title: displayTitle,
                            subtitle: displaySubtitle,
                            imageUrl: logoUrl,
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
                        ListTile(
                          leading: const Icon(Icons.person_outline, size: 20),
                          title: const Text(
                            'Meu Perfil',
                            style: TextStyle(fontSize: 14),
                          ),
                          onTap: () {
                            Navigator.of(context).pop();
                            context.push('/admin/settings/profile');
                          },
                        ),
                        ListTile(
                          leading: const Icon(
                            Icons.settings_outlined,
                            size: 20,
                          ),
                          title: const Text(
                            'Ajustes',
                            style: TextStyle(fontSize: 14),
                          ),
                          onTap: () {
                            Navigator.of(context).pop();
                            context.push('/admin/settings');
                          },
                        ),
                        if (canManageUsers)
                          ListTile(
                            leading: const Icon(Icons.people_outline, size: 20),
                            title: const Text(
                              'Usu\u00e1rios',
                              style: TextStyle(fontSize: 14),
                            ),
                            onTap: () {
                              Navigator.of(context).pop();
                              context.push('/admin/settings/users');
                            },
                          ),
                        const Divider(),
                        ListTile(
                          leading: const Icon(
                            Icons.logout,
                            size: 20,
                            color: Colors.red,
                          ),
                          title: const Text(
                            'Sair do Aplicativo',
                            style: TextStyle(fontSize: 14, color: Colors.red),
                          ),
                          onTap: () {
                            Navigator.of(context).pop();
                            ref.read(authViewModelProvider.notifier).signOut();
                          },
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
                          right: BorderSide(
                            color: Theme.of(context).dividerColor,
                          ),
                        ),
                      ),
                      child: SafeArea(
                        child: NavigationDrawer(
                          selectedIndex: navigationShell.currentIndex,
                          onDestinationSelected: onAdminNavigation,
                          children: [
                            const SizedBox(height: AppTokens.space24),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: AdminDrawerHeader(
                                title: displayTitle,
                                subtitle: displaySubtitle,
                                imageUrl: logoUrl,
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
                            ListTile(
                              leading: const Icon(
                                Icons.settings_outlined,
                                size: 20,
                              ),
                              title: const Text(
                                'Ajustes',
                                style: TextStyle(fontSize: 14),
                              ),
                              onTap: () => context.push('/admin/settings'),
                            ),
                            ListTile(
                              leading: const Icon(
                                Icons.person_outline,
                                size: 20,
                              ),
                              title: const Text(
                                'Meu Perfil',
                                style: TextStyle(fontSize: 14),
                              ),
                              onTap: () =>
                                  context.push('/admin/settings/profile'),
                            ),
                            if (canManageUsers)
                              ListTile(
                                leading: const Icon(
                                  Icons.people_outline,
                                  size: 20,
                                ),
                                title: const Text(
                                  'Usu\u00e1rios',
                                  style: TextStyle(fontSize: 14),
                                ),
                                onTap: () =>
                                    context.push('/admin/settings/users'),
                              ),
                            const Divider(),
                            ListTile(
                              leading: const Icon(
                                Icons.logout,
                                size: 20,
                                color: Colors.red,
                              ),
                              title: const Text(
                                'Sair do Aplicativo',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.red,
                                ),
                              ),
                              onTap: () => ref
                                  .read(authViewModelProvider.notifier)
                                  .signOut(),
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
