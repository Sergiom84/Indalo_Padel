class SetScore {
  final int a;
  final int b;
  final int? tieBreakA;
  final int? tieBreakB;

  const SetScore({
    required this.a,
    required this.b,
    this.tieBreakA,
    this.tieBreakB,
  });

  factory SetScore.fromJson(Map<String, dynamic> json) => SetScore(
        a: (json['a'] as num?)?.toInt() ?? 0,
        b: (json['b'] as num?)?.toInt() ?? 0,
        tieBreakA: _asNullableInt(
          json['tie_break_a'] ??
              json['tiebreak_a'] ??
              json['tieBreakA'] ??
              _asMap(json['tie_break'])?['a'],
        ),
        tieBreakB: _asNullableInt(
          json['tie_break_b'] ??
              json['tiebreak_b'] ??
              json['tieBreakB'] ??
              _asMap(json['tie_break'])?['b'],
        ),
      );

  bool get hasTieBreak => tieBreakA != null && tieBreakB != null;

  int get winnerSide {
    if (a > b) return 1;
    if (b > a) return 2;
    if (hasTieBreak) {
      if (tieBreakA! > tieBreakB!) return 1;
      if (tieBreakB! > tieBreakA!) return 2;
    }
    return 0;
  }

  String get displayLabel {
    final base = '$a-$b';
    if (!hasTieBreak) {
      return base;
    }
    return '$base ($tieBreakA-$tieBreakB)';
  }

  Map<String, dynamic> toJson() => {
        'a': a,
        'b': b,
        if (hasTieBreak) ...{
          'tie_break_a': tieBreakA,
          'tie_break_b': tieBreakB,
        },
      };
}

class MatchResultSubmissionModel {
  final int userId;
  final int? partnerUserId;
  final int winnerTeam;
  final List<SetScore> sets;
  final DateTime? submittedAt;

  const MatchResultSubmissionModel({
    required this.userId,
    required this.partnerUserId,
    required this.winnerTeam,
    required this.sets,
    this.submittedAt,
  });

  factory MatchResultSubmissionModel.fromJson(Map<String, dynamic> json) {
    final rawSets = json['sets'];
    final sets = <SetScore>[];
    if (rawSets is List) {
      for (final item in rawSets) {
        if (item is Map) {
          sets.add(SetScore.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }
    return MatchResultSubmissionModel(
      userId: (json['user_id'] as num).toInt(),
      partnerUserId: (json['partner_user_id'] as num?)?.toInt(),
      winnerTeam: (json['winner_team'] as num).toInt(),
      sets: sets,
      submittedAt: _parseDate(json['submitted_at']),
    );
  }
}

class MatchResultModel {
  final int? id;
  final int planId;
  final String status;
  final List<int> teamAUserIds;
  final List<int> teamBUserIds;
  final int? winnerTeam;
  final List<SetScore> sets;
  final DateTime? resolvedAt;
  final List<MatchResultSubmissionModel> submissions;

  const MatchResultModel({
    this.id,
    required this.planId,
    required this.status,
    required this.teamAUserIds,
    required this.teamBUserIds,
    this.winnerTeam,
    required this.sets,
    this.resolvedAt,
    required this.submissions,
  });

  bool get isConsensuado => status == 'consensuado';
  bool get isDisputa => status == 'disputa';
  bool get isPending => status == 'pending';

  MatchResultSubmissionModel? submissionFor(int userId) {
    for (final s in submissions) {
      if (s.userId == userId) return s;
    }
    return null;
  }

  factory MatchResultModel.fromPayload({
    required int planId,
    required Map<String, dynamic> payload,
  }) {
    final resultJson = payload['result'];
    final submissionsJson = payload['submissions'];

    final submissions = <MatchResultSubmissionModel>[];
    if (submissionsJson is List) {
      for (final item in submissionsJson) {
        if (item is Map) {
          submissions.add(
            MatchResultSubmissionModel.fromJson(
                Map<String, dynamic>.from(item)),
          );
        }
      }
    }

    if (resultJson is! Map) {
      return MatchResultModel(
        planId: planId,
        status: 'pending',
        teamAUserIds: const [],
        teamBUserIds: const [],
        sets: const [],
        submissions: submissions,
      );
    }

    final map = Map<String, dynamic>.from(resultJson);
    final rawSets = map['sets'];
    final sets = <SetScore>[];
    if (rawSets is List) {
      for (final item in rawSets) {
        if (item is Map) {
          sets.add(SetScore.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }

    List<int> parseIntList(dynamic value) {
      if (value is List) {
        return value
            .whereType<num>()
            .map((v) => v.toInt())
            .toList(growable: false);
      }
      return const [];
    }

    return MatchResultModel(
      id: (map['id'] as num?)?.toInt(),
      planId: planId,
      status: (map['status'] ?? 'pending').toString(),
      teamAUserIds: parseIntList(map['team_a_user_ids']),
      teamBUserIds: parseIntList(map['team_b_user_ids']),
      winnerTeam: (map['winner_team'] as num?)?.toInt(),
      sets: sets,
      resolvedAt: _parseDate(map['resolved_at']),
      submissions: submissions,
    );
  }
}

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString());
}

Map<String, dynamic>? _asMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return null;
}

int? _asNullableInt(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}
