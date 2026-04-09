import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class BrandLogo extends StatelessWidget {
  final double size;
  final bool glow;

  const BrandLogo({
    super.key,
    this.size = 72,
    this.glow = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
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
      child: Image.asset(
        'assets/branding/indalo-icon.png',
        fit: BoxFit.cover,
      ),
    );
  }
}
