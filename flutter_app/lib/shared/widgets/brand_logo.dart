import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

enum BrandLogoShape { rounded, circle }

class BrandLogo extends StatelessWidget {
  final double size;
  final bool glow;
  final BrandLogoShape shape;
  static const double _logoAspectRatio = 1408 / 768;

  const BrandLogo({
    super.key,
    this.size = 72,
    this.glow = false,
    this.shape = BrandLogoShape.rounded,
  });

  @override
  Widget build(BuildContext context) {
    final isCircle = shape == BrandLogoShape.circle;
    final borderRadius = BorderRadius.circular(size * 0.26);

    return Container(
      width: isCircle ? size : size * _logoAspectRatio,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: isCircle ? null : borderRadius,
        border: Border.all(color: AppColors.border),
        boxShadow: glow
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.16),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ]
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.all(size * (isCircle ? 0.02 : 0.12)),
        child: Transform.scale(
          scale: isCircle ? 1.8 : 1,
          child: Image.asset(
            'assets/branding/indalo-icon.png',
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
