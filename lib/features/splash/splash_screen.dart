import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:catalogo_ja/ui/theme/app_tokens.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _logoController;
  late final AnimationController _textController;
  late final AnimationController _pulseController;
  late final AnimationController _bgController;

  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _textOpacity;
  late final Animation<Offset> _textSlide;
  late final Animation<double> _taglineOpacity;
  late final Animation<double> _pulse;
  late final Animation<double> _bgGlow;

  @override
  void initState() {
    super.initState();

    // Background glow animation
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _bgGlow = CurvedAnimation(parent: _bgController, curve: Curves.easeInOut);
    _bgController.forward();

    // Logo entrance
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _logoScale = Tween<double>(begin: 0.55, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    // Text entrance
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _textController,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
      ),
    );
    _taglineOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _textController,
        curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
      ),
    );
    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOutCubic),
    );

    // Pulse for logo glow
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Sequence: bg → logo → text → navigate
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _logoController.forward();
    });
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) _textController.forward();
    });
    Future.delayed(const Duration(milliseconds: 2600), () {
      if (mounted) context.go('/admin/products');
    });
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    _pulseController.dispose();
    _bgController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTokens.deepNavy,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background image
          Image.asset(
            'assets/branding/splash/catalogoja_splash_clean.png',
            fit: BoxFit.cover,
            alignment: Alignment.center,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),

          // Dark overlay gradient
          FadeTransition(
            opacity: _bgGlow,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppTokens.deepNavy.withOpacity(0.65),
                    AppTokens.deepNavy.withOpacity(0.78),
                    AppTokens.deepNavy.withOpacity(0.95),
                  ],
                  stops: const [0.0, 0.55, 1.0],
                ),
              ),
            ),
          ),

          // Glow orbs background
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, _) {
              return CustomPaint(
                painter: _GlowOrbPainter(pulse: _pulse.value),
              );
            },
          ),

          // Center content
          SafeArea(
            child: Column(
              children: [
                const Spacer(),

                // Logo
                AnimatedBuilder(
                  animation: _logoController,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _logoOpacity.value,
                      child: Transform.scale(
                        scale: _logoScale.value,
                        child: child,
                      ),
                    );
                  },
                  child: AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          // Glow ring
                          Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppTokens.electricBlue
                                      .withOpacity(_pulse.value * 0.35),
                                  blurRadius: 60,
                                  spreadRadius: 10,
                                ),
                                BoxShadow(
                                  color: AppTokens.vibrantCyan
                                      .withOpacity(_pulse.value * 0.2),
                                  blurRadius: 40,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                          ),
                          // Logo container
                          Container(
                            width: 112,
                            height: 112,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(28),
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF1A3A6B),
                                  Color(0xFF0A1F44),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              border: Border.all(
                                color: AppTokens.electricBlue.withOpacity(0.4),
                                width: 1.5,
                              ),
                              boxShadow: const [AppTokens.shadowDeep],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(26),
                              child: Image.asset(
                                'assets/branding/icons/catalogoja_icons_glass_1024x1024.png',
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.auto_awesome_rounded,
                                  color: Colors.white,
                                  size: 48,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),

                const SizedBox(height: 32),

                // App name + tagline
                AnimatedBuilder(
                  animation: _textController,
                  builder: (context, child) {
                    return SlideTransition(
                      position: _textSlide,
                      child: Opacity(
                        opacity: _textOpacity.value,
                        child: child,
                      ),
                    );
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // App name with gradient
                      ShaderMask(
                        shaderCallback: (bounds) =>
                            AppTokens.primaryGradient.createShader(bounds),
                        child: const Text(
                          'Catálogo Já',
                          style: TextStyle(
                            fontSize: 38,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -1.5,
                            height: 1.0,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Tagline
                      AnimatedBuilder(
                        animation: _textController,
                        builder: (context, child) {
                          return Opacity(
                            opacity: _taglineOpacity.value,
                            child: child,
                          );
                        },
                        child: const Text(
                          'Seu catálogo profissional em segundos',
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.white60,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 0.2,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Bottom section: badge + loader
                Padding(
                  padding: const EdgeInsets.only(bottom: 48),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Premium badge
                      AnimatedBuilder(
                        animation: _textController,
                        builder: (context, child) {
                          return Opacity(
                            opacity: _taglineOpacity.value,
                            child: child,
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(AppTokens.radiusFull),
                            border: Border.all(
                              color: AppTokens.accentGold.withOpacity(0.5),
                            ),
                            color: AppTokens.accentGold.withOpacity(0.08),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.workspace_premium_rounded,
                                size: 14,
                                color: AppTokens.accentGold,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Plano Premium Ativo',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppTokens.accentGold,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Loading indicator
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppTokens.vibrantCyan.withOpacity(0.7),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter for background glow orbs
class _GlowOrbPainter extends CustomPainter {
  final double pulse;

  const _GlowOrbPainter({required this.pulse});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    // Top-right blue orb
    paint.shader = RadialGradient(
      colors: [
        AppTokens.electricBlue.withOpacity(0.12 * pulse),
        Colors.transparent,
      ],
    ).createShader(Rect.fromCircle(
      center: Offset(size.width * 0.85, size.height * 0.18),
      radius: 200,
    ));
    canvas.drawCircle(
      Offset(size.width * 0.85, size.height * 0.18),
      200,
      paint,
    );

    // Bottom-left cyan orb
    paint.shader = RadialGradient(
      colors: [
        AppTokens.vibrantCyan.withOpacity(0.08 * pulse),
        Colors.transparent,
      ],
    ).createShader(Rect.fromCircle(
      center: Offset(size.width * 0.1, size.height * 0.75),
      radius: 180,
    ));
    canvas.drawCircle(
      Offset(size.width * 0.1, size.height * 0.75),
      180,
      paint,
    );

    // Center purple orb
    paint.shader = RadialGradient(
      colors: [
        AppTokens.softPurple.withOpacity(0.06 * pulse),
        Colors.transparent,
      ],
    ).createShader(Rect.fromCircle(
      center: Offset(size.width * 0.5, size.height * 0.42),
      radius: 220,
    ));
    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.42),
      220,
      paint,
    );
  }

  @override
  bool shouldRepaint(_GlowOrbPainter oldDelegate) =>
      oldDelegate.pulse != pulse;
}
