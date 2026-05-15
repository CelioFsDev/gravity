import 'package:catalogo_ja/features/admin/users/create_email_password_user_screen.dart';
import 'package:catalogo_ja/features/auth/register_screen.dart';
import 'package:catalogo_ja/features/admin/profile/profile_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:catalogo_ja/firebase_options.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:catalogo_ja/models/product.dart';
import 'package:catalogo_ja/models/category.dart';
import 'package:catalogo_ja/models/catalog.dart';
import 'package:catalogo_ja/models/settings.dart';
import 'package:catalogo_ja/models/product_variant.dart';
import 'package:catalogo_ja/models/product_image.dart';
import 'package:catalogo_ja/core/sync/models/sync_queue_item.dart';
import 'package:catalogo_ja/core/sync/repositories/sync_queue_repository.dart';
import 'package:catalogo_ja/features/admin/admin_shell_screen.dart';
import 'package:catalogo_ja/features/admin/products/products_screen.dart';
import 'package:catalogo_ja/features/admin/categories/categories_screen.dart';
import 'package:catalogo_ja/features/admin/collections/collections_screen.dart';
import 'package:catalogo_ja/features/admin/collections/collection_form_screen.dart';
import 'package:catalogo_ja/features/admin/catalogs/catalogs_screen.dart';
import 'package:catalogo_ja/features/admin/import/import_menu_screen.dart';
import 'package:catalogo_ja/features/admin/import/nuvemshop_import_screen.dart';
import 'package:catalogo_ja/features/admin/import/stock_update_screen.dart';
import 'package:catalogo_ja/features/admin/import/catalogo_ja_import_screen.dart';
import 'package:catalogo_ja/features/admin/order_import/presentation/order_pdf_import_page.dart';
import 'package:catalogo_ja/features/admin/settings/settings_screen.dart';
import 'package:catalogo_ja/features/admin/users/user_management_screen.dart';
import 'package:catalogo_ja/features/admin/store/store_contact_share_screen.dart';
import 'package:catalogo_ja/features/admin/dashboard/dashboard_screen.dart';
import 'package:catalogo_ja/features/admin/backup/backup_screen.dart';
import 'package:catalogo_ja/features/theme/theme_providers.dart';
import 'package:catalogo_ja/features/public/catalog_home_page.dart';
import 'package:catalogo_ja/features/public/product_detail_screen.dart';
import 'package:catalogo_ja/ui/theme/app_theme.dart';
import 'package:catalogo_ja/ui/theme/app_tokens.dart';
import 'package:catalogo_ja/features/auth/login_screen.dart';
import 'package:catalogo_ja/features/splash/splash_screen.dart';
import 'package:catalogo_ja/pages/tenant/tenant_onboarding_page.dart';
import 'package:catalogo_ja/pages/tenant/tenant_picker_page.dart';
import 'package:catalogo_ja/viewmodels/auth_viewmodel.dart';
import 'package:catalogo_ja/viewmodels/tenant_viewmodel.dart';
import 'package:catalogo_ja/viewmodels/catalog_public_viewmodel.dart';
import 'package:catalogo_ja/core/auth/user_role.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart' hide Category;

/// Provider that checks if the user is disabled, manually defined to avoid build issues.
final currentUserStatusProvider = StreamProvider<bool>((ref) {
  final user = ref.watch(authViewModelProvider).valueOrNull;
  if (user == null || user.email == null) return Stream.value(false);
  final email = user.email!.trim().toLowerCase();
  return FirebaseFirestore.instance
      .collection('users')
      .doc(email)
      .snapshots()
      .map((doc) => doc.data()?['disabled'] as bool? ?? false);
});

void main() async {
  String? bootMode;
  try {
    if (kIsWeb) {
      bootMode = Uri.base.queryParameters['boot'];
    }
  } catch (_) {}

  void showBootError(int step, Object error, StackTrace stackTrace) {
    String platform = kIsWeb ? 'Web' : defaultTargetPlatform.name;
    String url = '';
    try {
      if (kIsWeb) url = Uri.base.toString();
    } catch (_) {}
    runApp(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('ERRO FATAL DE BOOT', style: TextStyle(color: Colors.red, fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Text('Etapa: $step', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text('Plataforma: $platform'),
                Text('URL: $url'),
                const SizedBox(height: 16),
                const Text('Erro:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(error.toString(), style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 16),
                const Text('Stack Trace:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(stackTrace.toString(), style: const TextStyle(fontFamily: 'monospace', fontSize: 10)),
              ],
            ),
          ),
        ),
      ),
    );
    FlutterNativeSplash.remove();
  }

  try {
    debugPrint('[BOOT_IOS] ETAPA 1 - WidgetsFlutterBinding.ensureInitialized()');
    WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
    FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  } catch (e, st) {
    debugPrint('[BOOT_IOS][ERRO ETAPA 1]');
    debugPrint(e.toString());
    debugPrint(st.toString());
    showBootError(1, e, st);
    return;
  }

  if (bootMode == 'minimal') {
    runApp(const MaterialApp(
      home: Scaffold(
        body: Center(child: Text('IOS BOOT MINIMAL OK')),
      ),
    ));
    FlutterNativeSplash.remove();
    return;
  }

  try {
    debugPrint('[BOOT_IOS] ETAPA 2 - usePathUrlStrategy()');
    if (kIsWeb) {
      usePathUrlStrategy();
    }
    await initializeDateFormatting('pt_BR', null);
  } catch (e, st) {
    debugPrint('[BOOT_IOS][ERRO ETAPA 2]');
    debugPrint(e.toString());
    debugPrint(st.toString());
    showBootError(2, e, st);
    return;
  }

  if (bootMode != 'no-hive') {
    try {
      debugPrint('[BOOT_IOS] ETAPA 3 - inicialização Hive');
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
        final dir = await getApplicationSupportDirectory();
        final hivePath = p.join(dir.path, 'catalogo_ja', 'db_v2');
        await Hive.initFlutter(hivePath);
      } else {
        await Hive.initFlutter();
      }

      Hive.registerAdapter(SyncStatusAdapter());
      Hive.registerAdapter(CategoryTypeAdapter());
      Hive.registerAdapter(CollectionCoverModeAdapter());
      Hive.registerAdapter(CollectionCoverAdapter());
      Hive.registerAdapter(CategoryAdapter());
      Hive.registerAdapter(ProductVariantAdapter());
      Hive.registerAdapter(ProductPhotoAdapter());
      Hive.registerAdapter(ProductImageSourceAdapter());
      Hive.registerAdapter(ProductImageAdapter());
      Hive.registerAdapter(SyncQueueItemAdapter());
      Hive.registerAdapter(AppSettingsAdapter());
      Hive.registerAdapter(ProductAdapter());
      Hive.registerAdapter(CatalogBannerAdapter());
      Hive.registerAdapter(CatalogModeAdapter());
      Hive.registerAdapter(CatalogAdapter());
    } catch (e, st) {
      debugPrint('[BOOT_IOS][ERRO ETAPA 3]');
      debugPrint(e.toString());
      debugPrint(st.toString());
      showBootError(3, e, st);
      return;
    }

    try {
      debugPrint('[BOOT_IOS] ETAPA 4 - abertura das boxes Hive');
      Future<void> safeOpenBox<T>(String name) async {
        try {
          await Hive.openBox<T>(name);
        } catch (e) {
          debugPrint('Error opening "$name" box: $e. Recreating...');
          try {
            await Hive.deleteBoxFromDisk(name);
            await Hive.openBox<T>(name);
          } catch (innerE) {
            debugPrint('Failed to recreate "$name": $innerE');
          }
        }
      }

      await safeOpenBox<Category>('categories');
      await safeOpenBox<Product>('products');
      await safeOpenBox<Catalog>('catalogs');
      await safeOpenBox<SyncQueueItem>(SyncQueueRepository.boxName);
      await safeOpenBox<AppSettings>('settings');
    } catch (e, st) {
      debugPrint('[BOOT_IOS][ERRO ETAPA 4]');
      debugPrint(e.toString());
      debugPrint(st.toString());
      showBootError(4, e, st);
      return;
    }
  }

  if (bootMode != 'no-firebase') {
    try {
      debugPrint('[BOOT_IOS] ETAPA 5 - Firebase.initializeApp()');
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      } catch (e) {
        if (!e.toString().contains('duplicate-app')) {
          rethrow;
        }
      }
    } catch (e, st) {
      debugPrint('[BOOT_IOS][ERRO ETAPA 5]');
      debugPrint(e.toString());
      debugPrint(st.toString());
      showBootError(5, e, st);
      return;
    }

    try {
      debugPrint('[BOOT_IOS] ETAPA 6 - configuração Firebase Auth persistence');
      if (kIsWeb && bootMode != 'no-auth-persistence') {
        try {
          await FirebaseAuth.instance.setPersistence(Persistence.SESSION);
        } catch (e) {
          debugPrint('Firebase Auth session persistence warning: $e');
          await FirebaseAuth.instance.setPersistence(Persistence.NONE);
        }
      }
    } catch (e, st) {
      debugPrint('[BOOT_IOS][ERRO ETAPA 6]');
      debugPrint(e.toString());
      debugPrint(st.toString());
      showBootError(6, e, st);
      return;
    }

    try {
      debugPrint('[BOOT_IOS] ETAPA 7 - configuração Firestore');
      if (kIsWeb) {
        FirebaseFirestore.instance.settings = const Settings(
          persistenceEnabled: false,
          webExperimentalAutoDetectLongPolling: true,
        );
      }
    } catch (e, st) {
      debugPrint('[BOOT_IOS][ERRO ETAPA 7]');
      debugPrint(e.toString());
      debugPrint(st.toString());
      showBootError(7, e, st);
      return;
    }
  }

  if (bootMode == 'no-hive') {
    runApp(const MaterialApp(
      home: Scaffold(
        body: Center(child: Text('IOS BOOT NO HIVE OK')),
      ),
    ));
    FlutterNativeSplash.remove();
    return;
  }

  if (bootMode == 'no-firebase') {
    runApp(const MaterialApp(
      home: Scaffold(
        body: Center(child: Text('IOS BOOT NO FIREBASE OK')),
      ),
    ));
    FlutterNativeSplash.remove();
    return;
  }

  try {
    debugPrint('[BOOT_IOS] ETAPA 8 - runApp ProviderScope(MyApp)');

    final isMobile =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS);

    if (isMobile) {
      FlutterError.onError = (errorDetails) {
        FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
      };

      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
    }

    runApp(const ProviderScope(child: MyApp()));
  } catch (e, st) {
    debugPrint('[BOOT_IOS][ERRO ETAPA 8]');
    debugPrint(e.toString());
    debugPrint(st.toString());
    showBootError(8, e, st);
    return;
  } finally {
    FlutterNativeSplash.remove();
  }
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  late final GoRouter _router;
  late final _RouterRefreshNotifier _routerRefreshNotifier;

  CustomTransitionPage<void> _buildPage(
    GoRouterState state,
    Widget child, {
    Offset beginOffset = const Offset(0.03, 0),
  }) {
    return CustomTransitionPage<void>(
      key: state.pageKey,
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 240),
      child: child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );

        return FadeTransition(
          opacity: Tween<double>(begin: 0, end: 1).animate(curved),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: beginOffset,
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _routerRefreshNotifier = _RouterRefreshNotifier(ref);
    _router = GoRouter(
      refreshListenable: _routerRefreshNotifier,
      redirect: (context, state) async {
        final authState = ref.read(authViewModelProvider);
        final user = authState.valueOrNull;
        final locationPath = state.uri.path;

        final legacyHashRoute = state.uri.fragment;
        if (locationPath == '/' && legacyHashRoute.startsWith('/')) {
          return legacyHashRoute;
        }

        // Forced status check (manual provider call to avoid generator lag)
        final isDisabled =
            ref.read(currentUserStatusProvider).valueOrNull ?? false;

        if (isDisabled && user != null) {
          ref.read(authViewModelProvider.notifier).signOut();
          return '/login';
        }

        final isAuthRoute =
            locationPath == '/login' || locationPath == '/register';

        final isSplash = locationPath == '/splash';

        final isPublicArea =
            locationPath == '/catalogo' ||
            locationPath == '/register' ||
            locationPath.startsWith('/c/') ||
            locationPath.startsWith('/p/');

        if (isPublicArea || isSplash) return null;

        if (user == null) {
          return isAuthRoute ? null : '/login';
        }

        // ✨ SaaS Logic: Se logado mas sem tenant ativo, FORÇA a seleção de empresa
        final currentTenantAsync = ref.read(currentTenantProvider);
        final isSelectingTenant =
            locationPath == '/onboarding' || locationPath == '/picker';

        // Só redireciona se já terminou de carregar (AsyncData) e o valor for nulo
        if (currentTenantAsync is AsyncData &&
            currentTenantAsync.value == null &&
            !isSelectingTenant &&
            !isAuthRoute &&
            !isSplash) {
          final needsOnboarding =
              ref.read(requiresTenantOnboardingProvider).valueOrNull ?? false;
          return needsOnboarding ? '/onboarding' : '/picker';
        }

        if (isAuthRoute) {
          final needsOnboarding =
              ref.read(requiresTenantOnboardingProvider).valueOrNull ?? false;
          return needsOnboarding ? '/onboarding' : '/picker';
        }

        if (locationPath == '/') {
          final role = await _effectiveRoleForRedirect(user.email);
          return _defaultAdminLocationFor(role);
        }

        if (locationPath.startsWith('/admin')) {
          final role = await _effectiveRoleForRedirect(user.email);
          if (!_canAccessAdminLocation(role, state.matchedLocation)) {
            return _defaultAdminLocationFor(role);
          }
        }

        return null;
      },
      routes: [
        GoRoute(
          path: '/splash',
          pageBuilder: (context, state) =>
              _buildPage(state, const SplashScreen()),
        ),
        GoRoute(
          path: '/login',
          pageBuilder: (context, state) =>
              _buildPage(state, const LoginScreen()),
        ),
        GoRoute(
          path: '/register',
          pageBuilder: (context, state) =>
              _buildPage(state, const PublicRegisterScreen()),
        ),
        GoRoute(
          path: '/onboarding',
          pageBuilder: (context, state) =>
              _buildPage(state, TenantOnboardingPage()),
        ),
        GoRoute(
          path: '/picker',
          pageBuilder: (context, state) =>
              _buildPage(state, TenantPickerPage()),
        ),
        GoRoute(
          path: '/',
          redirect: (context, state) async {
            final user = ref.read(authViewModelProvider).valueOrNull;
            if (user == null) return '/login';

            final role = await _effectiveRoleForRedirect(user.email);
            return _defaultAdminLocationFor(role);
          },
        ),
        GoRoute(
          path: '/catalogo',
          pageBuilder: (context, state) =>
              _buildPage(state, const PublicHomeScreen()),
        ),
        GoRoute(
          path: '/p/:productId',
          pageBuilder: (context, state) {
            final productId = state.pathParameters['productId']!;
            final extra = state.extra;
            final product = extra is Map ? extra['product'] : null;
            final mode = extra is Map ? extra['mode'] : null;
            final extraShareCode = extra is Map ? extra['shareCode'] : null;

            if (product is Product && mode is CatalogMode) {
              return _buildPage(
                state,
                PublicProductDetailScreen(
                  product: product,
                  mode: mode,
                  shareCode: extraShareCode is String ? extraShareCode : null,
                ),
              );
            }

            return _buildPage(
              state,
              Scaffold(
                appBar: AppBar(),
                body: Center(child: Text('Carregando produto $productId...')),
              ),
            );
          },
        ),
        GoRoute(
          path: '/c/:shareCode/p/:productId',
          pageBuilder: (context, state) {
            final productId = state.pathParameters['productId']!;
            final shareCode = state.pathParameters['shareCode']!;
            final extra = state.extra;
            final productFromExtra = extra is Map ? extra['product'] : null;
            final modeFromExtra = extra is Map ? extra['mode'] : null;

            if (productFromExtra is Product && modeFromExtra is CatalogMode) {
              return _buildPage(
                state,
                PublicProductDetailScreen(
                  product: productFromExtra,
                  mode: modeFromExtra,
                  shareCode: shareCode,
                ),
              );
            }

            return _buildPage(
              state,
              Consumer(
                builder: (context, ref, _) {
                  final catalogAsync = ref.watch(
                    catalogPublicProvider(shareCode),
                  );

                  return catalogAsync.when(
                    loading: () => const Scaffold(
                      backgroundColor: Color(0xFFF8FAFC),
                      body: Center(child: CircularProgressIndicator()),
                    ),
                    error: (error, stackTrace) {
                      debugPrint(
                        'Public product route error for $shareCode/$productId: '
                        '$error',
                      );
                      debugPrint(error.toString());
                      debugPrint(stackTrace.toString());
                      final showTechnicalError = kDebugMode || kProfileMode;

                      return Scaffold(
                        backgroundColor: const Color(0xFFF8FAFC),
                        body: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              showTechnicalError
                                  ? 'Nao foi possivel carregar este produto.\n$error'
                                  : 'Nao foi possivel carregar este produto.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      );
                    },
                    data: (data) {
                      Product? product;
                      if (data != null) {
                        for (final item in data.products) {
                          if (item.id == productId) {
                            product = item;
                            break;
                          }
                        }
                      }

                      if (data == null || product == null) {
                        return Scaffold(
                          backgroundColor: const Color(0xFFF8FAFC),
                          appBar: AppBar(),
                          body: const Center(
                            child: Text('Produto nao encontrado'),
                          ),
                        );
                      }

                      return PublicProductDetailScreen(
                        product: product,
                        mode: data.catalog.mode,
                        shareCode: shareCode,
                      );
                    },
                  );
                },
              ),
            );
          },
        ),
        GoRoute(
          path: '/c/:shareCode',
          pageBuilder: (context, state) {
            final query = state.uri.queryParameters;
            return _buildPage(
              state,
              CatalogHomePage(
                shareCode: state.pathParameters['shareCode']!,
                sellerWhatsapp: query['w'] ?? query['whatsapp'],
                debugErrors: query['debug'] == '1' || query['debug'] == 'true',
              ),
            );
          },
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
                  pageBuilder: (context, state) =>
                      _buildPage(state, const DashboardScreen()),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/admin/products',
                  pageBuilder: (context, state) =>
                      _buildPage(state, const ProductsScreen()),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/admin/collections',
                  pageBuilder: (context, state) =>
                      _buildPage(state, const CollectionsScreen()),
                  routes: [
                    GoRoute(
                      path: 'new',
                      pageBuilder: (context, state) =>
                          _buildPage(state, const CollectionFormScreen()),
                    ),
                    GoRoute(
                      path: ':id/edit',
                      pageBuilder: (context, state) => _buildPage(
                        state,
                        CollectionFormScreen(
                          collectionId: state.pathParameters['id'],
                        ),
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
                  pageBuilder: (context, state) =>
                      _buildPage(state, const CategoriesScreen()),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/admin/catalogs',
                  pageBuilder: (context, state) =>
                      _buildPage(state, const CatalogsScreen()),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/admin/imports',
                  pageBuilder: (context, state) =>
                      _buildPage(state, const ImportMenuScreen()),
                  routes: [
                    GoRoute(
                      path: 'nuvemshop',
                      pageBuilder: (context, state) =>
                          _buildPage(state, const NuvemshopImportScreen()),
                    ),
                    GoRoute(
                      path: 'stock-update',
                      pageBuilder: (context, state) =>
                          _buildPage(state, const StockUpdateScreen()),
                    ),
                    GoRoute(
                      path: 'backup',
                      pageBuilder: (context, state) =>
                          _buildPage(state, const CatalogoJaImportScreen()),
                    ),
                  ],
                ),
                GoRoute(
                  path: '/admin/import-order-pdf',
                  pageBuilder: (context, state) =>
                      _buildPage(state, const OrderPdfImportPage()),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/admin/profile',
                  pageBuilder: (context, state) =>
                      _buildPage(state, const ProfileScreen()),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/admin/share',
                  pageBuilder: (context, state) =>
                      _buildPage(state, const StoreContactShareScreen()),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/admin/settings',
                  pageBuilder: (context, state) =>
                      _buildPage(state, const SettingsScreen()),
                  routes: [
                    GoRoute(
                      path: 'users',
                      builder: (context, state) => const UserManagementScreen(),
                      redirect: (context, state) async {
                        final role = await _effectiveRoleForRedirect(
                          ref.read(authViewModelProvider).valueOrNull?.email,
                        );

                        final email = ref
                            .read(authViewModelProvider)
                            .valueOrNull
                            ?.email;

                        if (!role.canManageUsers(email)) {
                          return '/admin/settings';
                        }

                        return null;
                      },
                      routes: [
                        GoRoute(
                          path: 'create-login',
                          builder: (context, state) =>
                              const CreateEmailPasswordUserScreen(),
                          redirect: (context, state) async {
                            final role = await _effectiveRoleForRedirect(
                              ref
                                  .read(authViewModelProvider)
                                  .valueOrNull
                                  ?.email,
                            );

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
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/admin/backup',
                  builder: (context, state) => const BackupScreen(),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  bool _canAccessAdminLocation(UserRole role, String location) {
    if (!role.canAccessAdmin) return false;
    if (location.startsWith('/admin/dashboard')) return role.canViewDashboard;
    if (location.startsWith('/admin/products')) return role.canViewProducts;
    if (location.startsWith('/admin/collections')) {
      return role.canViewCollections;
    }
    if (location.startsWith('/admin/categories')) return role.canViewCategories;
    if (location.startsWith('/admin/catalogs')) return role.canViewCatalogs;
    if (location.startsWith('/admin/imports')) return role.canViewImports;
    if (location.startsWith('/admin/import-order-pdf')) {
      return role.canViewImports;
    }
    if (location.startsWith('/admin/profile')) return role.canViewProfile;
    if (location.startsWith('/admin/share')) return role.canShare;
    if (location.startsWith('/admin/settings')) return role.canViewSettings;
    if (location.startsWith('/admin/backup')) return role.canViewBackup;
    return true;
  }

  String _defaultAdminLocationFor(UserRole role) {
    if (role.canViewDashboard) return '/admin/dashboard';
    if (role.canViewCatalogs) return '/admin/catalogs';
    if (role.canShare) return '/admin/share';
    return '/picker';
  }

  Future<UserRole> _effectiveRoleForRedirect(String? rawEmail) async {
    final email = rawEmail?.trim().toLowerCase() ?? '';
    if (email.isEmpty) return UserRole.viewer;
    if (UserRole.superAdminEmails.contains(email)) return UserRole.admin;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(email)
          .get();

      final data = doc.data() ?? {};
      final tenantId = data['tenantId'] as String? ?? '';
      final storeId = data['currentStoreId'] as String? ?? '';

      final roleName = _effectiveRoleNameForData(
        data,
        tenantId: tenantId,
        storeId: storeId,
      );

      return UserRole.values.firstWhere(
        (role) => role.name == roleName,
        orElse: () => UserRole.viewer,
      );
    } catch (_) {
      return ref.read(currentRoleProvider);
    }
  }

  String _effectiveRoleNameForData(
    Map<String, dynamic> data, {
    required String tenantId,
    required String storeId,
  }) {
    final rolesByStore = data['rolesByStore'];
    if (rolesByStore is Map && tenantId.isNotEmpty && storeId.isNotEmpty) {
      final tenantStores = rolesByStore[tenantId];
      if (tenantStores is Map) {
        final role = tenantStores[storeId] as String?;
        if (role != null && role.isNotEmpty) return role;
      }
    }

    final rolesByTenant = data['rolesByTenant'];
    if (rolesByTenant is Map && tenantId.isNotEmpty) {
      final role = rolesByTenant[tenantId] as String?;
      if (role != null && role.isNotEmpty) return role;
    }

    return data['role'] as String? ?? 'viewer';
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
        title: 'Catálogo Já',
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: mode,
        themeAnimationDuration: const Duration(milliseconds: 280),
        themeAnimationCurve: Curves.easeOutCubic,
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
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Divider(height: 1),
                    ),
                    TextButton.icon(
                      onPressed: () => context.push('/login'),
                      style: TextButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.primary,
                      ),
                      icon: const Icon(Icons.admin_panel_settings_outlined),
                      label: const Text('VOLTAR AO LOGIN'),
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
    _authSubscription = ref.listenManual(
      authViewModelProvider,
      (_, _) => notifyListeners(),
    );

    _roleSubscription = ref.listenManual(
      currentRoleProvider,
      (_, _) => notifyListeners(),
    );

    _tenantSubscription = ref.listenManual(
      currentTenantProvider,
      (_, _) => notifyListeners(),
    );

    _tenantOnboardingSubscription = ref.listenManual(
      requiresTenantOnboardingProvider,
      (_, _) => notifyListeners(),
    );
  }

  late final ProviderSubscription<AsyncValue<dynamic>> _authSubscription;
  late final ProviderSubscription<UserRole> _roleSubscription;
  late final ProviderSubscription<AsyncValue<dynamic>> _tenantSubscription;
  late final ProviderSubscription<AsyncValue<dynamic>>
  _tenantOnboardingSubscription;

  @override
  void dispose() {
    _authSubscription.close();
    _roleSubscription.close();
    _tenantSubscription.close();
    _tenantOnboardingSubscription.close();
    super.dispose();
  }
}
