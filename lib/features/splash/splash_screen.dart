import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Gradient Background
          Positioned.fill(
            child: Image.asset(
              'assets/branding/splash/catalogoja_splash_ios_1080x1920.png',
              fit: BoxFit.cover,
            ),
          ),

          // Subtle loading indicator at the bottom
          const Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.only(bottom: 64.0),
              child: SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3DD5F3)),
                  strokeWidth: 3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
