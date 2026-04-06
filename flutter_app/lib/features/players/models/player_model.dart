class PlayerModel {
  final int userId;
  final String displayName;
  final int level;
  final String? preferredSide;
  final bool isAvailable;
  final double avgRating;
  final int totalRatings;
  final int matchesPlayed;
  final int matchesWon;
  final String? bio;
  final bool isFavorited;

  const PlayerModel({
    required this.userId,
    required this.displayName,
    this.level = 0,
    this.preferredSide,
    this.isAvailable = true,
    this.avgRating = 0.0,
    this.totalRatings = 0,
    this.matchesPlayed = 0,
    this.matchesWon = 0,
    this.bio,
    this.isFavorited = false,
  });

  factory PlayerModel.fromJson(Map<String, dynamic> json) {
    return PlayerModel(
      userId: (json['user_id'] ?? json['id'] ?? 0) as int,
      displayName: (json['display_name'] ?? json['nombre'] ?? '') as String,
      level: (json['level'] ?? json['numeric_level'] ?? 0) as int,
      preferredSide: json['preferred_side'] as String?,
      isAvailable: (json['is_available'] ?? true) as bool,
      avgRating: ((json['avg_rating'] ?? 0.0) as num).toDouble(),
      totalRatings: (json['total_ratings'] ?? 0) as int,
      matchesPlayed: (json['matches_played'] ?? 0) as int,
      matchesWon: (json['matches_won'] ?? 0) as int,
      bio: json['bio'] as String?,
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
      id: json['id'] as int?,
      raterName: (json['rater_name'] ?? 'Anónimo') as String,
      rating: ((json['rating'] ?? 0) as num).toDouble(),
      comment: json['comment'] as String?,
    );
  }
}
