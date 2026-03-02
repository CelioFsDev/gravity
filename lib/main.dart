import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:catalogo_ja/firebase_options.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:catalogo_ja/models/product.dart';
import 'package:catalogo_ja/models/category.dart';
import 'package:catalogo_ja/models/catalog.dart';
import 'package:catalogo_ja/models/settings.dart';
import 'package:catalogo_ja/models/product_variant.dart';
import 'package:catalogo_ja/models/product_image.dart';
import 'package:catalogo_ja/features/admin/admin_shell_screen.dart';
import 'package:catalogo_ja/features/admin/products/products_screen.dart';
import 'package:catalogo_ja/features/admin/categories/categories_screen.dart';
import 'package:catalogo_ja/features/admin/collections/collections_screen.dart';
import 'package:catalogo_ja/features/admin/collections/collection_form_screen.dart';
import 'package:catalogo_ja/features/admin/catalogs/catalogs_screen.dart';
import 'package:catalogo_ja/features/admin/import/nuvemshop_import_screen.dart';
import 'package:catalogo_ja/features/admin/settings/settings_screen.dart';
import 'package:catalogo_ja/features/admin/users/user_management_screen.dart';
import 'package:catalogo_ja/features/theme/theme_providers.dart';
import 'package:catalogo_ja/features/public/catalog_home_page.dart';
import 'package:catalogo_ja/features/public/product_detail_screen.dart';
import 'package:catalogo_ja/ui/theme/app_theme.dart';
import 'package:catalogo_ja/ui/theme/app_tokens.dart';
import 'package:catalogo_ja/features/auth/login_screen.dart';
import 'package:catalogo_ja/features/splash/splash_screen.dart';
import 'package:catalogo_ja/viewmodels/auth_viewmodel.dart';
import 'package:catalogo_ja/core/auth/user_role.dart';

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
  Hive.registerAdapter(ProductImageSourceAdapter());
  Hive.registerAdapter(ProductImageAdapter());
  Hive.registerAdapter(AppSettingsAdapter());
  Hive.registerAdapter(ProductAdapter());
  Hive.registerAdapter(CatalogBannerAdapter());
  Hive.registerAdapter(CatalogModeAdapter());
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

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  late final GoRouter _router;
  late final _RouterRefreshNotifier _routerRefreshNotifier;

  @override
  void initState() {
    super.initState();
    _routerRefreshNotifier = _RouterRefreshNotifier(ref);
    _router = GoRouter(
      initialLocation: '/splash',
      refreshListenable: _routerRefreshNotifier,
      redirect: (context, state) {
        final authState = ref.read(authViewModelProvider);
        final user = authState.valueOrNull;
        final isLoggingIn = state.matchedLocation == '/login';
        final isSplash = state.matchedLocation == '/splash';
        final isPublicArea =
            state.matchedLocation == '/' ||
            state.matchedLocation.startsWith('/c/') ||
            state.matchedLocation.startsWith('/p/');

        if (isPublicArea || isSplash) return null;

        if (user == null) {
          return isLoggingIn ? null : '/login';
        }

        if (isLoggingIn) {
          return '/admin/products';
        }

        return null;
      },
      routes: [
        GoRoute(
          path: '/splash',
          builder: (context, state) => const SplashScreen(),
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/',
          builder: (context, state) => const PublicHomeScreen(),
        ),
        GoRoute(
          path: '/p/:productId',
          builder: (context, state) {
            final productId = state.pathParameters['productId']!;
            final extra = state.extra as Map<String, dynamic>?;

            if (extra != null && extra.containsKey('product')) {
              return PublicProductDetailScreen(
                product: extra['product'] as Product,
                mode: extra['mode'] as CatalogMode,
              );
            }

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
                  routes: [
                    GoRoute(
                      path: 'users',
                      builder: (context, state) => const UserManagementScreen(),
                      redirect: (context, state) {
                        final role = ref.read(currentRoleProvider);
                        final email = ref
                            .read(authViewModelProvider)
                            .valueOrNull
                            ?.email;
                        if (!role.canManageUsers(email)) {
                          return '/admin/settings';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  @override
  void dispose() {
    _router.dispose();
    _routerRefreshNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(themeModeProvider);

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
        title: 'CatalogoJa',
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: mode,
        routerConfig: _router,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
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
        title: const Text('Cat\u00e1logo'),
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
                      'Acesse seu cat\u00e1logo',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _codeController,
                      decoration: const InputDecoration(
                        labelText: 'C\u00f3digo do cat\u00e1logo',
                        prefixIcon: Icon(Icons.link),
                      ),
                      onSubmitted: (_) => _openCatalog(),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _openCatalog,
                        child: const Text('Abrir cat\u00e1logo'),
                      ),
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

class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(WidgetRef ref) {
    _subscription = ref.listenManual(
      authViewModelProvider,
      (_, _) => notifyListeners(),
    );
  }

  late final ProviderSubscription<AsyncValue<dynamic>> _subscription;

  @override
  void dispose() {
    _subscription.close();
    super.dispose();
  }
}
