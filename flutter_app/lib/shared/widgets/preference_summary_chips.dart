import 'package:flutter/material.dart';

import '../utils/player_preferences.dart';
import 'padel_badge.dart';

class PreferenceSummaryChips extends StatelessWidget {
  final List<String> courtPreferences;
  final List<String> dominantHands;
  final List<String> availabilityPreferences;
  final List<String> matchPreferences;
  final int maxItems;

  const PreferenceSummaryChips({
    super.key,
    this.courtPreferences = const [],
    this.dominantHands = const [],
    this.availabilityPreferences = const [],
    this.matchPreferences = const [],
    this.maxItems = 3,
  });

  @override
  Widget build(BuildContext context) {
    final labels = <String>[
      ...PlayerPreferenceCatalog.labelsForValues(availabilityPreferences),
      ...PlayerPreferenceCatalog.labelsForValues(matchPreferences),
      ...PlayerPreferenceCatalog.labelsForValues(courtPreferences),
      ...PlayerPreferenceCatalog.labelsForValues(dominantHands),
    ].where((label) => label.trim().isNotEmpty).toList(growable: false);

    if (labels.isEmpty) {
      return const SizedBox.shrink();
    }

    final visibleLabels = labels.take(maxItems).toList(growable: false);

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final label in visibleLabels)
          PadelBadge(label: label, variant: PadelBadgeVariant.outline),
      ],
    );
  }
}
