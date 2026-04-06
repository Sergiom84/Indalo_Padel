import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

bool get isCupertinoPlatform {
  return defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;
}

Future<void> appSelectionHaptic() async {
  await HapticFeedback.selectionClick();
}

Future<void> appLightImpact() async {
  await HapticFeedback.lightImpact();
}

Future<void> appMediumImpact() async {
  await HapticFeedback.mediumImpact();
}
