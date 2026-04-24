import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../core/platform/platform_helper.dart';
import '../../core/theme/app_theme.dart';

Future<DateTime?> showAdaptiveAppDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
}) {
  if (!isCupertinoPlatform) {
    return showDatePicker(
      context: context,
      locale: const Locale('es', 'ES'),
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      builder: (ctx, child) {
        return Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.primary,
              onPrimary: AppColors.dark,
              surface: AppColors.surface,
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
  }

  return showCupertinoModalPopup<DateTime>(
    context: context,
    builder: (popupContext) {
      DateTime selected = initialDate;
      return _CupertinoPickerSheet(
        title: 'Selecciona fecha',
        child: SizedBox(
          height: 216,
          child: CupertinoDatePicker(
            mode: CupertinoDatePickerMode.date,
            initialDateTime: initialDate,
            minimumDate: firstDate,
            maximumDate: lastDate,
            onDateTimeChanged: (value) => selected = value,
          ),
        ),
        onDone: () => Navigator.of(popupContext).pop(selected),
      );
    },
  );
}

Future<TimeOfDay?> showAdaptiveAppTimePicker({
  required BuildContext context,
  required TimeOfDay initialTime,
}) async {
  if (!isCupertinoPlatform) {
    return showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (ctx, child) {
        return Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.primary,
              onPrimary: AppColors.dark,
              surface: AppColors.surface,
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
  }

  final selectedDate = await showCupertinoModalPopup<DateTime>(
    context: context,
    builder: (popupContext) {
      DateTime selected = DateTime(
        0,
        1,
        1,
        initialTime.hour,
        initialTime.minute,
      );
      return _CupertinoPickerSheet(
        title: 'Selecciona hora',
        child: SizedBox(
          height: 216,
          child: CupertinoDatePicker(
            mode: CupertinoDatePickerMode.time,
            use24hFormat: true,
            initialDateTime: selected,
            onDateTimeChanged: (value) => selected = value,
          ),
        ),
        onDone: () => Navigator.of(popupContext).pop(selected),
      );
    },
  );

  if (selectedDate == null) {
    return null;
  }

  return TimeOfDay(hour: selectedDate.hour, minute: selectedDate.minute);
}

class _CupertinoPickerSheet extends StatelessWidget {
  final String title;
  final Widget child;
  final VoidCallback onDone;

  const _CupertinoPickerSheet({
    required this.title,
    required this.child,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                  Expanded(
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: onDone,
                    child: const Text(
                      'Aceptar',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }
}
