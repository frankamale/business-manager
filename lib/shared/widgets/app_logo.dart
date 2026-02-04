import 'package:flutter/material.dart';
import '../../back_pos/config.dart';

/// A reusable logo widget that loads the flavor-specific logo
/// with automatic fallback to the default logo.
class AppLogo extends StatelessWidget {
  final double width;
  final double height;
  final BoxFit fit;

  const AppLogo({
    super.key,
    this.width = 100,
    this.height = 100,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      AppConfig.logoPath,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stackTrace) {
        // Fallback to default logo if flavor logo not found
        return Image.asset(
          AppConfig.fallbackLogoPath,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (context, error, stackTrace) {
            // Final fallback to icon if no logo found
            return Icon(
              Icons.storefront_rounded,
              size: width < height ? width : height,
              color: Colors.blue.shade700,
            );
          },
        );
      },
    );
  }
}

/// A circular logo container with the app logo inside
class AppLogoCircle extends StatelessWidget {
  final double size;
  final double padding;
  final Color? backgroundColor;

  const AppLogoCircle({
    super.key,
    this.size = 100,
    this.padding = 16,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.blue.shade50,
        shape: BoxShape.circle,
      ),
      child: AppLogo(
        width: size,
        height: size,
      ),
    );
  }
}
