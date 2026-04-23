import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class NotificationDot extends StatelessWidget {
  final bool visible;
  final double size;

  const NotificationDot({
    super.key,
    required this.visible,
    this.size = 10,
  });

  @override
  Widget build(BuildContext context) {
    if (!visible) {
      return const SizedBox.shrink();
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.danger,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.surface, width: 1.5),
      ),
    );
  }
}

class NotificationLabel extends StatelessWidget {
  final String label;
  final bool showDot;

  const NotificationLabel({
    super.key,
    required this.label,
    required this.showDot,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label),
        if (showDot) ...[
          const SizedBox(width: 6),
          const NotificationDot(visible: true, size: 9),
        ],
      ],
    );
  }
}
