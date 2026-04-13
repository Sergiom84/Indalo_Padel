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

class PlayerLevelOption {
  final String key;
  final String mainLevel;
  final String subLevel;
  final String label;

  const PlayerLevelOption({
    required this.key,
    required this.mainLevel,
    required this.subLevel,
    required this.label,
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

  static const genderOptions = [
    PreferenceOption(value: 'masculino', label: 'Masculino'),
    PreferenceOption(value: 'femenino', label: 'Femenino'),
    PreferenceOption(value: 'otro', label: 'Otro'),
    PreferenceOption(
      value: 'prefiero_no_decirlo',
      label: 'Prefiero no decirlo',
    ),
  ];

  static const levelOptions = [
    PlayerLevelOption(
      key: 'bajo:bajo',
      mainLevel: 'bajo',
      subLevel: 'bajo',
      label: 'Bajo - Bajo',
    ),
    PlayerLevelOption(
      key: 'bajo:medio',
      mainLevel: 'bajo',
      subLevel: 'medio',
      label: 'Bajo - Medio',
    ),
    PlayerLevelOption(
      key: 'bajo:alto',
      mainLevel: 'bajo',
      subLevel: 'alto',
      label: 'Bajo - Alto',
    ),
    PlayerLevelOption(
      key: 'medio:bajo',
      mainLevel: 'medio',
      subLevel: 'bajo',
      label: 'Medio - Bajo',
    ),
    PlayerLevelOption(
      key: 'medio:medio',
      mainLevel: 'medio',
      subLevel: 'medio',
      label: 'Medio - Medio',
    ),
    PlayerLevelOption(
      key: 'medio:alto',
      mainLevel: 'medio',
      subLevel: 'alto',
      label: 'Medio - Alto',
    ),
    PlayerLevelOption(
      key: 'alto:bajo',
      mainLevel: 'alto',
      subLevel: 'bajo',
      label: 'Alto - Bajo',
    ),
    PlayerLevelOption(
      key: 'alto:medio',
      mainLevel: 'alto',
      subLevel: 'medio',
      label: 'Alto - Medio',
    ),
    PlayerLevelOption(
      key: 'alto:alto',
      mainLevel: 'alto',
      subLevel: 'alto',
      label: 'Alto - Alto',
    ),
  ];

  static const accountDeletionReasons = [
    PreferenceOption(value: 'no_uso_la_app', label: 'No uso la app'),
    PreferenceOption(value: 'no_me_gusta', label: 'No me gusta'),
    PreferenceOption(
      value: 'no_es_lo_que_buscaba',
      label: 'No es lo que buscaba',
    ),
    PreferenceOption(value: 'otros', label: 'Otros'),
  ];

  static const sections = [
    PreferenceSectionDefinition(
      field: 'court_preferences',
      title: 'Posición en pista',
      options: courtPreferences,
    ),
    PreferenceSectionDefinition(
      field: 'dominant_hands',
      title: 'Preferencia de la mano',
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

  static PlayerLevelOption? levelOptionForKey(String? key) {
    if (key == null || key.isEmpty) {
      return null;
    }

    for (final option in levelOptions) {
      if (option.key == key) {
        return option;
      }
    }

    return null;
  }

  static String labelForGender(String? value) {
    if (value == null || value.isEmpty) {
      return '';
    }

    for (final option in genderOptions) {
      if (option.value == value) {
        return option.label;
      }
    }

    return value;
  }

  static String labelForAccountDeletionReason(String? value) {
    if (value == null || value.isEmpty) {
      return '';
    }

    for (final option in accountDeletionReasons) {
      if (option.value == value) {
        return option.label;
      }
    }

    return value;
  }
}
