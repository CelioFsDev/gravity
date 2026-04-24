import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:catalogo_ja/ui/theme/app_tokens.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToNext();
  }

  Future<void> _navigateToNext() async {
    // Wait for 2 seconds to show the splash screen
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      // Go to the products screen, the router redirect will handle auth check
      context.go('/admin/products');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: AppTokens.deepNavy,
      body: Stack(
        children: [
          // Radial Glow for depth
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.2,
                  colors: [
                    Color(0xFF0F1A35), // Brilho suave central
                    AppTokens.deepNavy, // Fundo escuro nas bordas
                  ],
                ),
              ),
            ),
          ),

          // Central Logo
          Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOut,
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.scale(
                    scale: 0.9 + (0.1 * value),
                    child: child,
                  ),
                );
              },
              child: Hero(
                tag: 'app_logo',
                child: Image.asset(
                  'assets/branding/logo/catalogoja_logo_master_2048x2048.png',
                  width: 240,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),

          // Subtle loading indicator
          const Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.only(bottom: 80.0),
              child: SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(AppTokens.vibrantCyan),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
