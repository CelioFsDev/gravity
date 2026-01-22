import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:gravity/models/order.dart';
import 'package:gravity/models/order_status.dart';
import 'package:gravity/models/order_item.dart';
import 'package:gravity/models/product.dart';
import 'package:gravity/models/category.dart';
import 'package:gravity/models/catalog.dart';
import 'package:gravity/features/admin/admin_shell_screen.dart';
import 'package:gravity/features/admin/dashboard_screen.dart';
import 'package:gravity/features/admin/orders_screen.dart';
import 'package:gravity/features/admin/products/products_screen.dart';
import 'package:gravity/features/admin/categories/categories_screen.dart';
import 'package:gravity/features/admin/catalogs/catalogs_screen.dart';
import 'package:gravity/features/admin/sellers/sellers_screen.dart';
import 'package:gravity/features/admin/settings/settings_screen.dart';
import 'package:gravity/features/theme/theme_providers.dart';
import 'package:gravity/models/seller.dart';
import 'package:gravity/features/public/catalog_home_page.dart';
import 'package:google_fonts/google_fonts.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Hive
  await Hive.initFlutter();
  
  // Register Adapters
  Hive.registerAdapter(OrderAdapter());
  Hive.registerAdapter(OrderStatusAdapter());
  Hive.registerAdapter(OrderItemAdapter());
  Hive.registerAdapter(CategoryAdapter());
  Hive.registerAdapter(ProductAdapter());
  Hive.registerAdapter(CatalogBannerAdapter());
  Hive.registerAdapter(CatalogAdapter());
  Hive.registerAdapter(SellerAdapter());
  
  // Open Boxes
  await Hive.openBox<Order>('orders');
  await Hive.openBox<Category>('categories');
  await Hive.openBox<Product>('products');
  await Hive.openBox<Catalog>('catalogs');
  await Hive.openBox<Seller>('sellers');
  
  runApp(const ProviderScope(child: MyApp()));
}

final _router = GoRouter(
  initialLocation: '/admin/orders', // Changed for dev convenience
  routes: [
    GoRoute(path: '/c/:slug', builder: (context, state) => CatalogHomePage(slug: state.pathParameters['slug']!)),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return AdminShellScreen(navigationShell: navigationShell);
      },
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/admin/dashboard',
              builder: (context, state) => const DashboardScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/admin/orders',
              builder: (context, state) => const OrdersScreen(),
            ),
          ],
        ),
         StatefulShellBranch(routes: [GoRoute(path: '/admin/products', builder: (c, s) => const ProductsScreen())]),
         StatefulShellBranch(routes: [GoRoute(path: '/admin/categories', builder: (c, s) => const CategoriesScreen())]),
         StatefulShellBranch(routes: [GoRoute(path: '/admin/catalogs', builder: (c, s) => const CatalogsScreen())]),
         StatefulShellBranch(routes: [GoRoute(path: '/admin/promotions', builder: (c, s) => const Scaffold(body: Center(child: Text('Promotions'))))]),
         StatefulShellBranch(routes: [GoRoute(path: '/admin/sellers', builder: (c, s) => const SellersScreen())]),
        StatefulShellBranch(routes: [GoRoute(path: '/admin/settings', builder: (c, s) => const SettingsScreen())]),
      ],
    ),
  ],
);

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: 'Admin Dashboard',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
        textTheme: GoogleFonts.interTextTheme(),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue, brightness: Brightness.dark),
        useMaterial3: true,
        textTheme: GoogleFonts.interTextTheme(ThemeData(brightness: Brightness.dark).textTheme),
      ),
      themeMode: mode,
      routerConfig: _router,
    );
  }
}
