// mon_splash_loader.dart
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../additions/colors.dart';

class MonSplashLoader extends StatefulWidget {
  final String statusMessage;
  final bool isOfflineMode;

  const MonSplashLoader({
    super.key,
    required this.statusMessage,
    this.isOfflineMode = false,
  });

  @override
  State<MonSplashLoader> createState() => _MonSplashLoaderState();
}

class _MonSplashLoaderState extends State<MonSplashLoader>
    with TickerProviderStateMixin {
  late final AnimationController _mainCtrl;
  late final AnimationController _pulseCtrl;
  late final AnimationController _dotCtrl;

  @override
  void initState() {
    super.initState();

    _mainCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _dotCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
  }

  @override
  void dispose() {
    _mainCtrl.dispose();
    _pulseCtrl.dispose();
    _dotCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 88,
          height: 88,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Subtle outer glow ring
              AnimatedBuilder(
                animation: _pulseCtrl,
                builder: (_, __) {
                  final scale = lerpDouble(0.95, 1.08, _pulseCtrl.value)!;
                  return Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: LightColors.secondary.withOpacity(0.15),
                          width: 1.5,
                        ),
                      ),
                    ),
                  );
                },
              ),

              // Main rotating loader
              RotationTransition(
                turns: _mainCtrl,
                child: CustomPaint(
                  size: const Size(88, 88),
                  painter: _BusinessLoaderPainter(),
                ),
              ),

              // Center logo/icon area (pulsing)
              AnimatedBuilder(
                animation: _pulseCtrl,
                builder: (_, __) {
                  final opacity = lerpDouble(0.7, 1.0, _pulseCtrl.value)!;
                  return Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: LightColors.surface,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: LightColors.secondary.withOpacity(0.25),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.analytics_rounded,
                      size: 22,
                      color: LightColors.secondary,
                    ),
                  );
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 28),

        // Status Message
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.25),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          ),

        ),

        const SizedBox(height: 16),

        // Elegant pulsing dots
        _BusinessDots(controller: _dotCtrl),

        if (widget.isOfflineMode) ...[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: Colors.orange.withOpacity(0.25),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_off_rounded, color: Colors.orange, size: 15),
                SizedBox(width: 8),
                Text(
                  'Working in Offline Mode',
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ── Custom Business Loader Painter ─────────────────────────────
class _BusinessLoaderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: center, radius: 36);

    // Light background ring
    final bgPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..color = LightColors.secondary.withOpacity(0.08);

    canvas.drawCircle(center, 36, bgPaint);

    // Gradient rotating arc
    final gradientPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        center: Alignment.center,
        startAngle: 0,
        endAngle: 2 * pi,
        colors: [
          LightColors.secondary.withOpacity(0.1),
          LightColors.secondary.withOpacity(0.9),
          LightColors.secondary.withOpacity(0.3),
        ],
        stops: const [0.0, 0.6, 1.0],
      ).createShader(rect);

    canvas.drawArc(
      rect,
      -pi / 2,           // start from top
      2.8,               // sweep angle in radians (~160 degrees)
      false,
      gradientPaint,
    );
  }

  @override
  bool shouldRepaint(_) => false;
}

// ── Elegant Wave Dots ───────────────────────────────────────────
class _BusinessDots extends StatelessWidget {
  final AnimationController controller;

  const _BusinessDots({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final delay = index * 0.25;
            final phase = (controller.value - delay).clamp(0.0, 1.0);
            final t = (sin(phase * 2 * pi * 1.8) + 1) / 2;

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 5.5,
              height: 5.5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: LightColors.secondary.withOpacity(0.35 + 0.65 * t),
              ),
            );
          }),
        );
      },
    );
  }
}