import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:gravity/models/settings.dart';
import 'package:gravity/models/product_variant.dart';
import 'package:gravity/features/admin/admin_shell_screen.dart';
import 'package:gravity/features/admin/products/products_screen.dart';
import 'package:gravity/features/admin/categories/categories_screen.dart';
import 'package:gravity/features/admin/collections/collections_screen.dart';
import 'package:gravity/features/admin/collections/collection_form_screen.dart';
import 'package:gravity/features/admin/catalogs/catalogs_screen.dart';
import 'package:gravity/features/admin/import/nuvemshop_import_screen.dart';
import 'package:gravity/features/admin/settings/settings_screen.dart';
import 'package:gravity/features/theme/theme_providers.dart';
import 'package:gravity/features/public/catalog_home_page.dart';
import 'package:gravity/core/auth/auth_repository.dart';
import 'package:gravity/features/public/product_detail_screen.dart';
import 'package:gravity/ui/theme/app_theme.dart';
import 'package:gravity/ui/theme/app_tokens.dart';

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
  Hive.registerAdapter(AppSettingsAdapter());
  Hive.registerAdapter(ProductAdapter());
  Hive.registerAdapter(CatalogBannerAdapter());
  Hive.registerAdapter(CatalogAdapter());

  // Open Boxes
  try {
    await Hive.openBox<Category>('categories');
  } catch (e) {
    debugPrint(
      'Error opening "categories" box: $e. Deleting and recreating...',
    );
    await Hive.deleteBoxFromDisk('categories');
    await Hive.openBox<Category>('categories');
  }
  await Hive.openBox<Product>('products');
  await Hive.openBox<Catalog>('catalogs');
  await Hive.openBox<AppSettings>('settings');

  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } on FirebaseException catch (e) {
    if (e.code == 'duplicate-app') {
      debugPrint('Firebase initialized (recovered from duplicate-app error)');
    } else {
      debugPrint('Firebase init failed (Offline Mode Active): $e');
    }
  } catch (e) {
    debugPrint('Firebase init failed (Offline Mode Active): $e');
  }

  runApp(const ProviderScope(child: MyApp()));
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
          path: 'p/:productId',
          builder: (context, state) {
            final productId = state.pathParameters['productId']!;
            final extra = state.extra as Map<String, dynamic>?;

            if (extra != null && extra.containsKey('product')) {
              return PublicProductDetailScreen(
                product: extra['product'] as Product,
                mode: extra['mode'] as CatalogMode,
              );
            }

            // Deep link support: Fallback to loading screen that fetches the product
            return Scaffold(
              appBar: AppBar(),
              body: Center(child: Text('Carregando produto $productId...')),
            );
          },
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
                  builder: (context, state) => const ProductsScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/admin/collections',
                  builder: (context, state) => const CollectionsScreen(),
                  routes: [
                    GoRoute(
                      path: 'new',
                      builder: (context, state) => const CollectionFormScreen(),
                    ),
                    GoRoute(
                      path: ':id/edit',
                      builder: (context, state) => CollectionFormScreen(
                        collectionId: state.pathParameters['id'],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/admin/categories',
                  builder: (context, state) => const CategoriesScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/admin/catalogs',
                  builder: (context, state) => const CatalogsScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/admin/imports/nuvemshop',
                  builder: (context, state) => const NuvemshopImportScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/admin/settings',
                  builder: (context, state) => const SettingsScreen(),
                ),
              ],
            ),
          ],
        ),
      ],
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: ref.watch(themeModeProvider) == ThemeMode.dark
          ? SystemUiOverlayStyle.light.copyWith(
              statusBarColor: Colors.transparent,
              systemNavigationBarColor: AppTokens.bgDark,
              systemNavigationBarIconBrightness: Brightness.light,
            )
          : SystemUiOverlayStyle.dark.copyWith(
              statusBarColor: Colors.transparent,
              systemNavigationBarColor: AppTokens.bg,
              systemNavigationBarIconBrightness: Brightness.dark,
            ),
      child: MaterialApp.router(
        title: 'Gravity',
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: mode,
        routerConfig: router,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.listen((event) => notifyListeners());
  }
  late final StreamSubscription<dynamic> _subscription;
  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

String? _authRedirect(AuthUser? user, GoRouterState state) {
  if (kBypassAuth) return null;
  final path = state.uri.path;
  if (!isLoggedIn(user)) {
    if (path == '/login' ||
        path == '/register' ||
        path.startsWith('/c/') ||
        path == '/')
      return null;
    return '/login';
  }
  if (path == '/login' || path == '/register') {
    return isAdmin(user) ? '/admin/products' : '/';
  }
  if (path.startsWith('/admin') && !isAdmin(user)) return '/';
  return null;
}

class PublicHomeScreen extends ConsumerStatefulWidget {
  const PublicHomeScreen({super.key});
  @override
  ConsumerState<PublicHomeScreen> createState() => _PublicHomeScreenState();
}

class _PublicHomeScreenState extends ConsumerState<PublicHomeScreen> {
  final _codeController = TextEditingController();
  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _openCatalog() {
    final code = _codeController.text.trim().toLowerCase();
    if (code.isNotEmpty) context.go('/c/$code');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Catálogo'),
        actions: [
          IconButton(
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
            onPressed: () => ref.read(themeModeProvider.notifier).state = isDark
                ? ThemeMode.light
                : ThemeMode.dark,
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Text(
                      'Acesse seu catálogo',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _codeController,
                      decoration: const InputDecoration(
                        labelText: 'Código do catálogo',
                        prefixIcon: Icon(Icons.link),
                      ),
                      onSubmitted: (_) => _openCatalog(),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _openCatalog,
                        child: const Text('Abrir catálogo'),
                      ),
                    ),
                    const Divider(height: 48),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => context.go('/login'),
                            child: const Text('Entrar'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: () => context.go('/register'),
                            child: const Text('Criar conta'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
