import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../utils/player_preferences.dart';

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
        bg = AppColors.success.withValues(alpha: 0.15);
        fg = AppColors.success;
        border = AppColors.success.withValues(alpha: 0.3);
        break;
      case PadelBadgeVariant.warning:
        bg = AppColors.warning.withValues(alpha: 0.15);
        fg = AppColors.warning;
        border = AppColors.warning.withValues(alpha: 0.3);
        break;
      case PadelBadgeVariant.danger:
        bg = AppColors.danger.withValues(alpha: 0.15);
        fg = AppColors.danger;
        border = AppColors.danger.withValues(alpha: 0.3);
        break;
      case PadelBadgeVariant.info:
        bg = AppColors.info.withValues(alpha: 0.15);
        fg = AppColors.info;
        border = AppColors.info.withValues(alpha: 0.3);
        break;
      case PadelBadgeVariant.outline:
        bg = Colors.transparent;
        fg = AppColors.muted;
        border = AppColors.border;
        break;
      case PadelBadgeVariant.neutral:
        bg = AppColors.primary.withValues(alpha: 0.15);
        fg = AppColors.primary;
        border = AppColors.primary.withValues(alpha: 0.3);
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
  final String? mainLevel;
  final String? subLevel;

  const LevelBadge({
    super.key,
    required this.level,
    this.mainLevel,
    this.subLevel,
  });

  @override
  Widget build(BuildContext context) {
    final lvl =
        (level is int ? level : int.tryParse(level?.toString() ?? '0')) ?? 0;
    final label = PlayerPreferenceCatalog.levelLabel(
      mainLevel: mainLevel,
      subLevel: subLevel,
      numericLevel: lvl,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
