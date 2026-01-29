import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gravity/core/auth/auth_controller.dart';
import 'package:gravity/core/auth/auth_guards.dart';
import 'package:gravity/core/auth/auth_user.dart';
import 'package:gravity/features/auth/login_screen.dart';
import 'package:gravity/features/auth/register_screen.dart';
import 'package:gravity/firebase_options.dart';
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
import 'package:gravity/models/app_settings.dart';
import 'package:gravity/features/public/catalog_home_page.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gravity/core/auth/auth_repository.dart';

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
  Hive.registerAdapter(AppSettingsAdapter());

  // Open Boxes
  await Hive.openBox<Order>('orders');
  await Hive.openBox<Category>('categories');
  await Hive.openBox<Product>('products');
  await Hive.openBox<Catalog>('catalogs');
  await Hive.openBox<Seller>('sellers');
  await Hive.openBox<AppSettings>('settings');

  try {
    // Initialize Firebase (after Hive to reuse local cache first)
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase init failed (Offline Mode Active): $e');
  }

  runApp(ProviderScope(child: const MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final authState = ref.watch(authControllerProvider);
    final user = authState.value;
    final streamSource = ref.watch(authRepositoryProvider).authStateChanges();
    final router = GoRouter(
      initialLocation: '/admin/orders',
      refreshListenable: GoRouterRefreshStream(streamSource),
      redirect: (context, state) => _authRedirect(user, state),
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const PublicHomeScreen(),
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/register',
          builder: (context, state) => const RegisterScreen(),
        ),
        GoRoute(
          path: '/c/:shareCode',
          builder: (context, state) =>
              CatalogHomePage(shareCode: state.pathParameters['shareCode']!),
        ),
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
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/admin/products',
                  builder: (c, s) => const ProductsScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/admin/categories',
                  builder: (c, s) => const CategoriesScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/admin/catalogs',
                  builder: (c, s) => const CatalogsScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/admin/promotions',
                  builder: (c, s) =>
                      const Scaffold(body: Center(child: Text('Promotions'))),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/admin/sellers',
                  builder: (c, s) => const SellersScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/admin/settings',
                  builder: (c, s) => const SettingsScreen(),
                ),
              ],
            ),
          ],
        ),
      ],
    );

    return MaterialApp.router(
      title: 'Admin Dashboard',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
        textTheme: GoogleFonts.interTextTheme(),
        visualDensity: VisualDensity.adaptivePlatformDensity,
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        textTheme: GoogleFonts.interTextTheme(
          ThemeData(brightness: Brightness.dark).textTheme,
        ),
        visualDensity: VisualDensity.adaptivePlatformDensity,
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
      themeMode: mode,
      routerConfig: router,
    );
  }
}

/// Converts a [Stream] into a [Listenable] by notifying listeners whenever
/// a new event is emitted.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.listen((event) {
      notifyListeners();
    });
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

String? _authRedirect(AuthUser? user, GoRouterState state) {
  if (kBypassAuth) {
    return null;
  }
  final path = state.uri.path;
  final isLogin = path == '/login';
  final isRegister = path == '/register';
  final isAdminPath = path.startsWith('/admin');
  final isShareRoute = path.startsWith('/c/');
  final isPublicHome = path == '/';

  if (!isLoggedIn(user)) {
    if (isLogin || isRegister || isShareRoute || isPublicHome) return null;
    return '/login';
  }

  if (isLogin || isRegister) {
    return isAdmin(user) ? '/admin/dashboard' : '/';
  }

  if (isAdminPath && !isAdmin(user)) {
    return '/';
  }

  return null;
}

class PublicHomeScreen extends StatelessWidget {
  const PublicHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Catálogo Público')),
      body: const Center(
        child: Text(
          'Acesse um catálogo compartilhado usando /c/{shareCode} ou peça para um administrador publicar um link.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
