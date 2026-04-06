import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

enum PadelBadgeVariant { success, warning, danger, info, neutral, outline }

class PadelBadge extends StatelessWidget {
  final String label;
  final PadelBadgeVariant variant;

  const PadelBadge({
    super.key,
    required this.label,
    this.variant = PadelBadgeVariant.neutral,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    Color border;

    switch (variant) {
      case PadelBadgeVariant.success:
        bg = AppColors.success.withOpacity(0.15);
        fg = AppColors.success;
        border = AppColors.success.withOpacity(0.3);
        break;
      case PadelBadgeVariant.warning:
        bg = AppColors.warning.withOpacity(0.15);
        fg = AppColors.warning;
        border = AppColors.warning.withOpacity(0.3);
        break;
      case PadelBadgeVariant.danger:
        bg = AppColors.danger.withOpacity(0.15);
        fg = AppColors.danger;
        border = AppColors.danger.withOpacity(0.3);
        break;
      case PadelBadgeVariant.info:
        bg = AppColors.info.withOpacity(0.15);
        fg = AppColors.info;
        border = AppColors.info.withOpacity(0.3);
        break;
      case PadelBadgeVariant.outline:
        bg = Colors.transparent;
        fg = AppColors.muted;
        border = AppColors.border;
        break;
      case PadelBadgeVariant.neutral:
      default:
        bg = AppColors.primary.withOpacity(0.15);
        fg = AppColors.primary;
        border = AppColors.primary.withOpacity(0.3);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class LevelBadge extends StatelessWidget {
  final dynamic level;
  const LevelBadge({super.key, required this.level});

  @override
  Widget build(BuildContext context) {
    final lvl = (level is int ? level : int.tryParse(level?.toString() ?? '0')) ?? 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Text(
        'Nv $lvl',
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
