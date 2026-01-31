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
import 'package:gravity/models/product.dart';
import 'package:gravity/models/category.dart';
import 'package:gravity/models/catalog.dart';
import 'package:gravity/models/product_variant.dart';
import 'package:gravity/features/admin/admin_shell_screen.dart';
import 'package:gravity/features/admin/products/products_screen.dart';
import 'package:gravity/features/admin/categories/categories_screen.dart';
import 'package:gravity/features/admin/catalogs/catalogs_screen.dart';
import 'package:gravity/features/admin/import/nuvemshop_import_screen.dart';
import 'package:gravity/features/theme/theme_providers.dart';
import 'package:gravity/features/public/catalog_home_page.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gravity/core/auth/auth_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive
  await Hive.initFlutter();

  // Register Adapters
  Hive.registerAdapter(CategoryTypeAdapter());
  Hive.registerAdapter(CollectionCoverModeAdapter());
  Hive.registerAdapter(CollectionCoverAdapter());
  Hive.registerAdapter(CategoryAdapter());
  Hive.registerAdapter(ProductVariantAdapter());
  Hive.registerAdapter(ProductPhotoAdapter());
  Hive.registerAdapter(ProductAdapter());
  Hive.registerAdapter(CatalogBannerAdapter());
  Hive.registerAdapter(CatalogAdapter());

  // Open Boxes
  await Hive.openBox<Category>('categories');
  await Hive.openBox<Product>('products');
  await Hive.openBox<Catalog>('catalogs');

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
      initialLocation: '/admin/products',
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
                  path: '/admin/imports/nuvemshop',
                  builder: (c, s) => const NuvemshopImportScreen(),
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
        cardTheme: CardThemeData(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(40, 44),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(40, 44),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey.shade100,
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
        cardTheme: CardThemeData(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(40, 44),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(40, 44),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey.shade800,
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
    return isAdmin(user) ? '/admin/products' : '/';
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

