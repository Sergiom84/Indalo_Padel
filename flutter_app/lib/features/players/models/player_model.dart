class PlayerModel {
  final int userId;
  final String displayName;
  final String? email;
  final int level;
  final List<String> courtPreferences;
  final List<String> dominantHands;
  final List<String> availabilityPreferences;
  final List<String> matchPreferences;
  final bool isAvailable;
  final double avgRating;
  final int totalRatings;
  final int matchesPlayed;
  final int matchesWon;
  final String? bio;
  final String? avatarUrl;
  final bool isFavorited;

  const PlayerModel({
    required this.userId,
    required this.displayName,
    this.email,
    this.level = 0,
    this.courtPreferences = const [],
    this.dominantHands = const [],
    this.availabilityPreferences = const [],
    this.matchPreferences = const [],
    this.isAvailable = true,
    this.avgRating = 0.0,
    this.totalRatings = 0,
    this.matchesPlayed = 0,
    this.matchesWon = 0,
    this.bio,
    this.avatarUrl,
    this.isFavorited = false,
  });

  factory PlayerModel.fromJson(Map<String, dynamic> json) {
    return PlayerModel(
      userId: _asInt(json['user_id'] ?? json['id']),
      displayName: (json['display_name'] ?? json['nombre'] ?? '') as String,
      email: json['email'] as String?,
      level: _asInt(json['level'] ?? json['numeric_level']),
      courtPreferences: _asStringList(json['court_preferences']),
      dominantHands: _asStringList(json['dominant_hands']),
      availabilityPreferences: _asStringList(json['availability_preferences']),
      matchPreferences: _asStringList(json['match_preferences']),
      isAvailable: (json['is_available'] ?? true) as bool,
      avgRating: _asDouble(json['avg_rating']) ?? 0.0,
      totalRatings: _asInt(json['total_ratings']),
      matchesPlayed: _asInt(json['matches_played']),
      matchesWon: _asInt(json['matches_won']),
      bio: json['bio'] as String?,
      avatarUrl: json['avatar_url'] as String? ?? json['avatarUrl'] as String?,
      isFavorited: (json['is_favorited'] ?? false) as bool,
    );
  }
}

class RatingModel {
  final int? id;
  final String raterName;
  final double rating;
  final String? comment;

  const RatingModel({
    this.id,
    required this.raterName,
    required this.rating,
    this.comment,
  });

  factory RatingModel.fromJson(Map<String, dynamic> json) {
    return RatingModel(
      id: _asNullableInt(json['id']),
      raterName: (json['rater_name'] ?? 'Anónimo') as String,
      rating: _asDouble(json['rating']) ?? 0,
      comment: json['comment'] as String?,
    );
  }
}

int _asInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

int? _asNullableInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

double? _asDouble(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.replaceAll(',', '.'));
  return null;
}

List<String> _asStringList(dynamic value) {
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
