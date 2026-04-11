class MatchModel {
  final int id;
  final String? matchDate;
  final String? startTime;
  final String? venueName;
  final int? venueId;
  final String status;
  final String? matchType;
  final int? minLevel;
  final int? maxLevel;
  final String? description;
  final int? creatorId;
  final String? creatorName;
  final int playerCount;
  final int maxPlayers;

  const MatchModel({
    required this.id,
    this.matchDate,
    this.startTime,
    this.venueName,
    this.venueId,
    this.status = 'buscando',
    this.matchType,
    this.minLevel,
    this.maxLevel,
    this.description,
    this.creatorId,
    this.creatorName,
    this.playerCount = 0,
    this.maxPlayers = 4,
  });

  factory MatchModel.fromJson(Map<String, dynamic> json) {
    return MatchModel(
      id: json['id'] as int? ?? 0,
      matchDate: json['match_date'] as String?,
      startTime: json['start_time'] as String?,
      venueName: json['venue_name'] as String?,
      venueId: json['venue_id'] as int?,
      status: (json['status'] ?? 'buscando') as String,
      matchType: json['match_type'] as String?,
      minLevel: json['min_level'] as int?,
      maxLevel: json['max_level'] as int?,
      description: json['description'] as String?,
      creatorId: (json['creator_id'] ?? json['created_by']) as int?,
      creatorName: json['creator_name'] as String?,
      playerCount:
          (json['player_count'] ?? json['current_players'] ?? 0) as int,
      maxPlayers: (json['max_players'] ?? 4) as int,
    );
  }
}

class MatchPlayerModel {
  final int id;
  final int? userId;
  final String name;
  final int team;
  final int level;

  const MatchPlayerModel({
    required this.id,
    this.userId,
    required this.name,
    required this.team,
    this.level = 0,
  });

  factory MatchPlayerModel.fromJson(Map<String, dynamic> json) {
    return MatchPlayerModel(
      id: (json['id'] ?? json['user_id'] ?? 0) as int,
      userId: (json['user_id'] ?? json['id']) as int?,
      name: (json['name'] ?? json['display_name'] ?? json['nombre'] ?? '')
          as String,
      team: (json['team'] ?? 1) as int,
      level: (json['level'] ?? json['numeric_level'] ?? 0) as int,
    );
  }
}
