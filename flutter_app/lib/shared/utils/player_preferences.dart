class PreferenceOption {
  final String value;
  final String label;

  const PreferenceOption({
    required this.value,
    required this.label,
  });
}

class PreferenceSectionDefinition {
  final String field;
  final String title;
  final List<PreferenceOption> options;

  const PreferenceSectionDefinition({
    required this.field,
    required this.title,
    required this.options,
  });
}

class PlayerPreferenceCatalog {
  static const courtPreferences = [
    PreferenceOption(value: 'drive', label: 'Derecha (Drive)'),
    PreferenceOption(value: 'reves', label: 'Izquierda (Revés)'),
    PreferenceOption(value: 'ambos', label: 'Indiferente / Ambos lados'),
  ];

  static const dominantHands = [
    PreferenceOption(value: 'diestro', label: 'Diestro/a'),
    PreferenceOption(value: 'zurdo', label: 'Zurdo/a'),
    PreferenceOption(value: 'ambidiestro', label: 'Ambidiestro/a'),
  ];

  static const availabilityPreferences = [
    PreferenceOption(value: 'mananas', label: 'Mañanas'),
    PreferenceOption(value: 'mediodias', label: 'Mediodías'),
    PreferenceOption(value: 'tardes_noches', label: 'Tardes / Noches'),
    PreferenceOption(value: 'flexible', label: 'Horario flexible'),
  ];

  static const matchPreferences = [
    PreferenceOption(value: 'amistoso', label: 'Amistoso (Partida Social)'),
    PreferenceOption(value: 'competitivo', label: 'Competitivo (Reto / Liga)'),
    PreferenceOption(value: 'americana', label: 'Americana'),
  ];

  static const sections = [
    PreferenceSectionDefinition(
      field: 'court_preferences',
      title: 'Preferencia en pista',
      options: courtPreferences,
    ),
    PreferenceSectionDefinition(
      field: 'dominant_hands',
      title: 'Perfil del jugador',
      options: dominantHands,
    ),
    PreferenceSectionDefinition(
      field: 'availability_preferences',
      title: 'Disponibilidad horaria',
      options: availabilityPreferences,
    ),
    PreferenceSectionDefinition(
      field: 'match_preferences',
      title: 'Modalidad de juego',
      options: matchPreferences,
    ),
  ];

  static List<String> parseValues(dynamic value) {
    if (value is List) {
      return value
          .whereType<Object>()
          .map((item) => item.toString())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    }

    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) {
        return const [];
      }

      if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
        final inner = trimmed.substring(1, trimmed.length - 1).trim();
        if (inner.isEmpty) {
          return const [];
        }
        return inner
            .split(',')
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toList(growable: false);
      }

      return [trimmed];
    }

    return const [];
  }

  static List<String> orderedValues(
    List<String> selectedValues,
    List<PreferenceOption> options,
  ) {
    final selectedSet = selectedValues.toSet();
    return options
        .where((option) => selectedSet.contains(option.value))
        .map((option) => option.value)
        .toList(growable: false);
  }

  static String labelForValue(String value) {
    for (final section in sections) {
      for (final option in section.options) {
        if (option.value == value) {
          return option.label;
        }
      }
    }
    return value;
  }

  static List<String> labelsForValues(List<String> values) {
    return values.map(labelForValue).toList(growable: false);
  }
}
