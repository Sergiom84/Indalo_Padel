import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

enum PadelButtonVariant { primary, outline, ghost, danger }

class PadelButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final PadelButtonVariant variant;
  final bool loading;
  final bool fullWidth;
  final IconData? icon;
  final double? fontSize;

  const PadelButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = PadelButtonVariant.primary,
    this.loading = false,
    this.fullWidth = false,
    this.icon,
    this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading)
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                variant == PadelButtonVariant.primary ? AppColors.dark : AppColors.primary,
              ),
            ),
          )
        else ...[
          if (icon != null) ...[
            Icon(icon, size: 18),
            const SizedBox(width: 8),
          ],
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: fontSize ?? 15,
            ),
          ),
        ],
      ],
    );

    final isDisabled = onPressed == null || loading;

    switch (variant) {
      case PadelButtonVariant.primary:
        return SizedBox(
          width: fullWidth ? double.infinity : null,
          child: ElevatedButton(
            onPressed: isDisabled ? null : onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.dark,
              disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.4),
            ),
            child: content,
          ),
        );
      case PadelButtonVariant.outline:
        return SizedBox(
          width: fullWidth ? double.infinity : null,
          child: OutlinedButton(
            onPressed: isDisabled ? null : onPressed,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: AppColors.border),
            ),
            child: content,
          ),
        );
      case PadelButtonVariant.ghost:
        return SizedBox(
          width: fullWidth ? double.infinity : null,
          child: TextButton(
            onPressed: isDisabled ? null : onPressed,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
            ),
            child: content,
          ),
        );
      case PadelButtonVariant.danger:
        return SizedBox(
          width: fullWidth ? double.infinity : null,
          child: OutlinedButton(
            onPressed: isDisabled ? null : onPressed,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.danger,
              side: const BorderSide(color: AppColors.danger),
            ),
            child: content,
          ),
        );
    }
  }
}
