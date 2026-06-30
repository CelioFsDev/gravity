import 'dart:io';

void main() {
  final file = File('lib/main.dart');
  String content = file.readAsStringSync();

  // 1. Substituir FlutterNativeSplash
  if (!content.contains('void _safeRemoveSplash')) {
    content = content.replaceFirst(
        'void main() async {',
        '''void _safeRemoveSplash() {
  try {
    FlutterNativeSplash.remove();
  } catch (e) {
    debugPrint('Erro ignorado no splash remove: \$e');
  }
}

void _safePreserveSplash(WidgetsBinding binding) {
  try {
    FlutterNativeSplash.preserve(widgetsBinding: binding);
  } catch (e) {
    debugPrint('Erro ignorado no splash preserve: \$e');
  }
}

void main() async {''');
  }

  content = content.replaceAll('FlutterNativeSplash.remove();', '_safeRemoveSplash();');
  content = content.replaceAll('FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);', '_safePreserveSplash(widgetsBinding);');

  // 2. Adicionar import do session_error_screen
  if (!content.contains('session_error_screen.dart')) {
    content = content.replaceFirst(
      "import 'package:catalogo_ja/features/splash/splash_screen.dart';",
      "import 'package:catalogo_ja/features/splash/splash_screen.dart';\nimport 'package:catalogo_ja/features/auth/session_error_screen.dart';"
    );
  }

  // 3. Substituir valueOrNull por asData?.value
  content = content.replaceAll('.valueOrNull', '.asData?.value');

  // 4. Transformar todos os .value soltos (usados de forma insegura no redirect) em .asData?.value
  // Vamos ser BEM específicos:
  content = content.replaceAll('final user = authState.value;', 'final user = authState.asData?.value;');
  content = content.replaceAll('ref.read(currentUserStatusProvider).value', 'ref.read(currentUserStatusProvider).asData?.value');
  content = content.replaceAll('ref.read(requiresTenantOnboardingProvider).value', 'ref.read(requiresTenantOnboardingProvider).asData?.value');
  content = content.replaceAll('final needsOnboarding = onboardingAsync.value', 'final needsOnboarding = onboardingAsync.asData?.value');
  content = content.replaceAll('final role = roleAsync.value', 'final role = roleAsync.asData?.value');
  content = content.replaceAll('final user = ref.read(authViewModelProvider).value;', 'final user = ref.read(authViewModelProvider).asData?.value;');

  // 5. Envolver o redirect no try-catch
  if (!content.contains('try {') && content.contains('redirect: (context, state) async {')) {
    // vamos tentar substituir o início
    content = content.replaceFirst('redirect: (context, state) async {', 'redirect: (context, state) async {\ntry {');
    
    // e substituir o fim
    final endTarget = '''        if (locationPath.startsWith('/admin')) {
          final roleAsync = ref.read(userRoleStreamProvider);
          if (roleAsync is AsyncLoading) return null;
          final role = roleAsync.asData?.value ?? UserRole.viewer;
          if (!_canAccessAdminLocation(role, state.matchedLocation)) {
            return _defaultAdminLocationFor(role);
          }
        }

        return null;
      },''';
      
    final endReplacement = '''        if (locationPath.startsWith('/admin')) {
          final roleAsync = ref.read(userRoleStreamProvider);
          if (roleAsync is AsyncLoading) return null;
          final role = roleAsync.asData?.value ?? UserRole.viewer;
          if (!_canAccessAdminLocation(role, state.matchedLocation)) {
            return _defaultAdminLocationFor(role);
          }
        }

        return null;
        } catch (e, stackTrace) {
          debugPrint('❌ [GoRouter] Erro crítico no redirect: \$e');
          debugPrint(stackTrace.toString());
          return '/session-error';
        }
      },''';
      
    content = content.replaceFirst(endTarget, endReplacement);
  }
  
  // 6. Adicionar Rota do session-error
  if (!content.contains("path: '/session-error'")) {
    final routeTarget = '''      routes: [
        GoRoute(
          path: '/splash',
          pageBuilder: (context, state) =>
              _buildPage(state, const SplashScreen()),
        ),''';
        
    final routeReplacement = '''      routes: [
        GoRoute(
          path: '/splash',
          pageBuilder: (context, state) =>
              _buildPage(state, const SplashScreen()),
        ),
        GoRoute(
          path: '/session-error',
          pageBuilder: (context, state) =>
              _buildPage(state, const SessionErrorScreen()),
        ),''';
        
    content = content.replaceFirst(routeTarget, routeReplacement);
  }

  file.writeAsStringSync(content);
  print('main.dart refatorado com sucesso!');
}
