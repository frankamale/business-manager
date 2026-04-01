// mon_splash_loader.dart
import 'dart:math';
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
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true); // "alternate" like the CSS
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // The CSS-inspired vertical bars loader
        SizedBox(
          width: 48,
          height: 48,
          child: _BarLoader(controller: _controller),
        ),

        const SizedBox(height: 24),

        // Status Message
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Text(
            widget.statusMessage,
            key: ValueKey(widget.statusMessage),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: LightColors.textPrimary.withOpacity(0.9),
              fontSize: 14.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),

        const SizedBox(height: 12),

        if (widget.isOfflineMode)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_off_rounded, color: Colors.orange, size: 15),
                SizedBox(width: 6),
                Text(
                  'Offline Mode',
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ── CSS-inspired Vertical Bars Loader ─────────────────────────────
class _BarLoader extends StatelessWidget {
  final AnimationController controller;

  const _BarLoader({required this.controller});

  @override
  Widget build(BuildContext context) {
    const barWidth = 5.0;
    const barHeight = 24.0;
    const spacing = 6.0;

    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (index) {
            // Staggered delay for each bar (0%, 33%, 66%)
            final delay = index * 0.33;
            final phase = (controller.value - delay).clamp(0.0, 1.0);

            // Smooth up/down movement (similar to the CSS keyframes)
            final animationValue = sin(phase * pi * 2) * 0.5 + 0.5; // 0.0 to 1.0

            // Map to vertical position: top = 0, bottom = full height
            final topPosition = (1 - animationValue) * (barHeight - 8);

            return Padding(
              padding: EdgeInsets.symmetric(horizontal: spacing / 2),
              child: Stack(
                children: [
                  // Background faint bar
                  Container(
                    width: barWidth,
                    height: barHeight,
                    decoration: BoxDecoration(
                      color: LightColors.secondary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  // Animated foreground bar
                  Positioned(
                    top: topPosition,
                    child: Container(
                      width: barWidth,
                      height: 8,
                      decoration: BoxDecoration(
                        color: LightColors.secondary,
                        borderRadius: BorderRadius.circular(3),
                        boxShadow: [
                          BoxShadow(
                            color: LightColors.secondary.withOpacity(0.4),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        );
      },
    );
  }
}