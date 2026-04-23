class PreferenceOption {
  final String value;
  final String label;

  const PreferenceOption({
    required this.value,
    required this.label,
  });
}

class PlayerLevelModel {
  final String? mainLevel;
  final String? subLevel;

  const PlayerLevelModel({
    this.mainLevel,
    this.subLevel,
  });

  bool get hasValue => mainLevel != null || subLevel != null;

  factory PlayerLevelModel.fromJson(Map<String, dynamic> json) {
    return PlayerLevelModel(
      mainLevel: PlayerPreferenceCatalog.normalizeLevelValue(json['main_level']),
      subLevel: PlayerPreferenceCatalog.normalizeLevelValue(json['sub_level']),
    );
  }

  static PlayerLevelModel fromNumericLevel(int? numericLevel) {
    if (numericLevel == null || numericLevel <= 0) {
      return const PlayerLevelModel();
    }

    final normalized = numericLevel.clamp(1, 9);
    final mainIndex = (normalized - 1) ~/ 3;
    final subIndex = (normalized - 1) % 3;

    return PlayerLevelModel(
      mainLevel: PlayerPreferenceCatalog.levelValues[mainIndex],
      subLevel: PlayerPreferenceCatalog.levelValues[subIndex],
    );
  }

  String label({
    int? fallbackNumericLevel,
    String separator = ' / ',
    String emptyLabel = 'Sin nivel',
  }) {
    final effective = hasValue
        ? this
        : PlayerLevelModel.fromNumericLevel(fallbackNumericLevel);
    final parts = <String>[];

    final mainLabel = PlayerPreferenceCatalog.labelForLevelValue(
      effective.mainLevel,
    );
    final subLabel = PlayerPreferenceCatalog.labelForLevelValue(
      effective.subLevel,
    );

    if (mainLabel.isNotEmpty) {
      parts.add(mainLabel);
    }
    if (subLabel.isNotEmpty) {
      parts.add(subLabel);
    }

    if (parts.isEmpty) {
      return emptyLabel;
    }

    return parts.join(separator);
  }
}

class PlayerPreferencesModel {
  final PlayerLevelModel level;
  final List<String> courtPreferences;
  final List<String> dominantHands;
  final List<String> availabilityPreferences;
  final List<String> matchPreferences;
  final String? gender;
  final String? birthDate;
  final String? phone;

  const PlayerPreferencesModel({
    this.level = const PlayerLevelModel(),
    this.courtPreferences = const [],
    this.dominantHands = const [],
    this.availabilityPreferences = const [],
    this.matchPreferences = const [],
    this.gender,
    this.birthDate,
    this.phone,
  });

  factory PlayerPreferencesModel.fromJson(Map<String, dynamic> json) {
    return PlayerPreferencesModel(
      level: PlayerLevelModel.fromJson(json),
      courtPreferences: PlayerPreferenceCatalog.parseValues(
        json['court_preferences'],
      ),
      dominantHands: PlayerPreferenceCatalog.parseValues(
        json['dominant_hands'],
      ),
      availabilityPreferences: PlayerPreferenceCatalog.parseValues(
        json['availability_preferences'],
      ),
      matchPreferences: PlayerPreferenceCatalog.parseValues(
        json['match_preferences'],
      ),
      gender: PlayerPreferenceCatalog.normalizeNullableText(json['gender']),
      birthDate: PlayerPreferenceCatalog.normalizeNullableText(json['birth_date']),
      phone: PlayerPreferenceCatalog.normalizeNullableText(json['phone']),
    );
  }

  Map<String, dynamic> toProfilePayload() {
    return {
      if (level.mainLevel != null) 'main_level': level.mainLevel,
      if (level.subLevel != null) 'sub_level': level.subLevel,
      'court_preferences': courtPreferences,
      'dominant_hands': dominantHands,
      'availability_preferences': availabilityPreferences,
      'match_preferences': matchPreferences,
      'gender': gender,
      'birth_date': birthDate,
      'phone': phone,
    };
  }
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
  static const levelValues = ['bajo', 'medio', 'alto'];

  static const levelOptions = [
    PreferenceOption(value: 'bajo', label: 'Bajo'),
    PreferenceOption(value: 'medio', label: 'Medio'),
    PreferenceOption(value: 'alto', label: 'Alto'),
  ];

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

  static const availabilityDayPreferences = [
    PreferenceOption(value: 'laborables', label: 'Lunes a viernes'),
    PreferenceOption(value: 'fin_de_semana', label: 'Fin de semana'),
    PreferenceOption(value: 'cualquiera', label: 'Cualquier día'),
  ];

  static const availabilityTimePreferences = [
    PreferenceOption(value: 'mananas', label: 'Mañanas'),
    PreferenceOption(value: 'mediodias', label: 'Mediodías'),
    PreferenceOption(value: 'tardes_noches', label: 'Tardes / Noches'),
    PreferenceOption(value: 'flexible', label: 'Horario flexible'),
  ];

  static const availabilityPreferences = [
    ...availabilityDayPreferences,
    ...availabilityTimePreferences,
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

  static String? normalizeNullableText(dynamic value) {
    if (value == null) {
      return null;
    }

    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static String? normalizeLevelValue(dynamic value) {
    final normalized = normalizeNullableText(value)?.toLowerCase();
    if (normalized == null || !levelValues.contains(normalized)) {
      return null;
    }
    return normalized;
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

  static List<String> availabilityDayValues(List<String> selectedValues) {
    return orderedValues(selectedValues, availabilityDayPreferences);
  }

  static List<String> availabilityTimeValues(List<String> selectedValues) {
    return orderedValues(selectedValues, availabilityTimePreferences);
  }

  static List<String> mergeAvailabilityValues({
    required List<String> dayValues,
    required List<String> timeValues,
  }) {
    final values = <String>[
      ...availabilityDayValues(dayValues),
      ...availabilityTimeValues(timeValues),
    ];
    return values.toSet().toList(growable: false);
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

  static String labelForLevelValue(String? value) {
    if (value == null || value.isEmpty) {
      return '';
    }

    for (final option in levelOptions) {
      if (option.value == value) {
        return option.label;
      }
    }

    return value;
  }

  static String levelLabel({
    String? mainLevel,
    String? subLevel,
    int? numericLevel,
    String separator = ' / ',
    String emptyLabel = 'Sin nivel',
  }) {
    return PlayerLevelModel(
      mainLevel: normalizeLevelValue(mainLevel),
      subLevel: normalizeLevelValue(subLevel),
    ).label(
      fallbackNumericLevel: numericLevel,
      separator: separator,
      emptyLabel: emptyLabel,
    );
  }

  static List<String> labelsForValues(List<String> values) {
    return values.map(labelForValue).toList(growable: false);
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
}
