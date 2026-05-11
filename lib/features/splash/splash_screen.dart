import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:catalogo_ja/ui/theme/app_tokens.dart';
import 'package:catalogo_ja/ui/theme/app_icons.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final AnimationController _badgeController;

  late final Animation<double> _pulse;
  late final Animation<double> _badgeFade;

  @override
  void initState() {
    super.initState();

    // Pulse suave para os orbs de glow
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Badge fade-in com delay
    _badgeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _badgeFade = CurvedAnimation(
      parent: _badgeController,
      curve: Curves.easeOut,
    );
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) _badgeController.forward();
    });


  }

  @override
  void dispose() {
    _pulseController.dispose();
    _badgeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTokens.deepNavy,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Fundo: imagem premium (já contém logo + texto) ──────────────
          Image.asset(
            AppAssets.splashPremium,
            fit: BoxFit.cover,
            alignment: Alignment.center,
            errorBuilder: (_, _, _) => _FallbackAnimatedBg(
              pulse: _pulse,
              pulseController: _pulseController,
            ),
          ),

          // ── Orbs de glow animados por cima ──────────────────────────────
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, _) =>
                CustomPaint(painter: _GlowOrbPainter(pulse: _pulse.value)),
          ),

          // ── Gradiente suave no rodapé para legibilidade ──────────────────
          const Align(
            alignment: Alignment.bottomCenter,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, AppTokens.deepNavy],
                ),
              ),
              child: SizedBox(width: double.infinity, height: 200),
            ),
          ),

          // ── Rodapé: badge + loader (únicos elementos Flutter) ───────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 48),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Badge Premium
                    FadeTransition(
                      opacity: _badgeFade,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(
                            AppTokens.radiusFull,
                          ),
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
                              size: 13,
                              color: AppTokens.accentGold,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Plano Premium Ativo',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppTokens.accentGold,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Loader
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppTokens.vibrantCyan.withOpacity(0.65),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Fallback: splash animado puro (sem imagem de fundo) ─────────────────────
// Exibido apenas se splash_background_premium não existir
class _FallbackAnimatedBg extends StatelessWidget {
  const _FallbackAnimatedBg({
    required this.pulse,
    required this.pulseController,
  });

  final Animation<double> pulse;
  final AnimationController pulseController;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Fundo sólido
        const ColoredBox(color: AppTokens.deepNavy),

        // Orbs
        AnimatedBuilder(
          animation: pulseController,
          builder: (context, _) =>
              CustomPaint(painter: _GlowOrbPainter(pulse: pulse.value)),
        ),

        // Logo + texto centralizados
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Ícone com glow
              AnimatedBuilder(
                animation: pulseController,
                builder: (context, child) => Container(
                  width: 112,
                  height: 112,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1A3A6B), Color(0xFF0A1F44)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                      color: AppTokens.electricBlue.withOpacity(0.4),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTokens.electricBlue.withOpacity(
                          pulse.value * 0.4,
                        ),
                        blurRadius: 50,
                        spreadRadius: 8,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(26),
                    child: Image.asset(
                      AppAssets.appIconGlass,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.auto_awesome_rounded,
                        color: Colors.white,
                        size: 48,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // Nome com gradiente
              ShaderMask(
                shaderCallback: (b) =>
                    AppTokens.primaryGradient.createShader(b),
                child: const Text(
                  'Catálogo Já',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -1.5,
                  ),
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'Seu catálogo profissional em segundos',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white54,
                  fontWeight: FontWeight.w400,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Glow Orbs Painter ────────────────────────────────────────────────────────
class _GlowOrbPainter extends CustomPainter {
  final double pulse;

  const _GlowOrbPainter({required this.pulse});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    // Top-right blue orb
    paint.shader =
        RadialGradient(
          colors: [
            AppTokens.electricBlue.withOpacity(0.1 * pulse),
            Colors.transparent,
          ],
        ).createShader(
          Rect.fromCircle(
            center: Offset(size.width * 0.85, size.height * 0.15),
            radius: 200,
          ),
        );
    canvas.drawCircle(
      Offset(size.width * 0.85, size.height * 0.15),
      200,
      paint,
    );

    // Bottom-left cyan orb
    paint.shader =
        RadialGradient(
          colors: [
            AppTokens.vibrantCyan.withOpacity(0.07 * pulse),
            Colors.transparent,
          ],
        ).createShader(
          Rect.fromCircle(
            center: Offset(size.width * 0.1, size.height * 0.75),
            radius: 180,
          ),
        );
    canvas.drawCircle(Offset(size.width * 0.1, size.height * 0.75), 180, paint);

    // Center purple orb
    paint.shader =
        RadialGradient(
          colors: [
            AppTokens.softPurple.withOpacity(0.05 * pulse),
            Colors.transparent,
          ],
        ).createShader(
          Rect.fromCircle(
            center: Offset(size.width * 0.5, size.height * 0.45),
            radius: 220,
          ),
        );
    canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.45), 220, paint);
  }

  @override
  bool shouldRepaint(_GlowOrbPainter oldDelegate) => oldDelegate.pulse != pulse;
}
