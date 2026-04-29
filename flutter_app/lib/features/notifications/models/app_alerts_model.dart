import '../../community/models/community_model.dart';

enum AppAlertScope {
  communityPlanner,
  communityInvitations,
  players,
  profileRatings,
}

class AppAlertItem {
  final String uniqueKey;
  final AppAlertScope scope;
  final String title;
  final String body;

  const AppAlertItem({
    required this.uniqueKey,
    required this.scope,
    required this.title,
    required this.body,
  });

  factory AppAlertItem.fromJson(
    Map<String, dynamic> json, {
    required AppAlertScope scope,
  }) {
    return AppAlertItem(
      uniqueKey: (json['unique_key'] ?? '').toString(),
      scope: scope,
      title: (json['title'] ?? '').toString(),
      body: (json['body'] ?? '').toString(),
    );
  }
}

class AppAlertsState {
  final bool loading;
  final List<AppAlertItem> communityPlannerAlerts;
  final List<AppAlertItem> communityInvitationAlerts;
  final List<AppAlertItem> playerInvitationAlerts;
  final List<AppAlertItem> profileRatingAlerts;
  final List<CommunityPlanModel> pendingResultPlans;

  const AppAlertsState({
    this.loading = false,
    this.communityPlannerAlerts = const [],
    this.communityInvitationAlerts = const [],
    this.playerInvitationAlerts = const [],
    this.profileRatingAlerts = const [],
    this.pendingResultPlans = const [],
  });

  factory AppAlertsState.fromJson(Map<String, dynamic> json) {
    List<AppAlertItem> parseAlerts(dynamic value, AppAlertScope scope) {
      if (value is! List) {
        return const [];
      }

      return value
          .whereType<Map>()
          .map(
            (item) => AppAlertItem.fromJson(
              Map<String, dynamic>.from(item),
              scope: scope,
            ),
          )
          .where((alert) => alert.uniqueKey.isNotEmpty)
          .toList(growable: false);
    }

    List<CommunityPlanModel> parsePlans(dynamic value) {
      if (value is! List) {
        return const [];
      }

      return value
          .whereType<Map>()
          .map(
            (item) =>
                CommunityPlanModel.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(growable: false);
    }

    return AppAlertsState(
      communityPlannerAlerts: parseAlerts(
        json['community_planner_alerts'],
        AppAlertScope.communityPlanner,
      ),
      communityInvitationAlerts: parseAlerts(
        json['community_invitation_alerts'],
        AppAlertScope.communityInvitations,
      ),
      playerInvitationAlerts: parseAlerts(
        json['player_invitation_alerts'],
        AppAlertScope.players,
      ),
      profileRatingAlerts: parseAlerts(
        json['rating_alerts'],
        AppAlertScope.profileRatings,
      ),
      pendingResultPlans: parsePlans(json['pending_result_plans']),
    );
  }

  AppAlertsState copyWith({
    bool? loading,
    List<AppAlertItem>? communityPlannerAlerts,
    List<AppAlertItem>? communityInvitationAlerts,
    List<AppAlertItem>? playerInvitationAlerts,
    List<AppAlertItem>? profileRatingAlerts,
    List<CommunityPlanModel>? pendingResultPlans,
  }) {
    return AppAlertsState(
      loading: loading ?? this.loading,
      communityPlannerAlerts:
          communityPlannerAlerts ?? this.communityPlannerAlerts,
      communityInvitationAlerts:
          communityInvitationAlerts ?? this.communityInvitationAlerts,
      playerInvitationAlerts:
          playerInvitationAlerts ?? this.playerInvitationAlerts,
      profileRatingAlerts: profileRatingAlerts ?? this.profileRatingAlerts,
      pendingResultPlans: pendingResultPlans ?? this.pendingResultPlans,
    );
  }

  bool get hasResultPendingBadge => pendingResultPlans.isNotEmpty;

  bool get hasCommunityBadge =>
      communityPlannerAlerts.isNotEmpty ||
      communityInvitationAlerts.isNotEmpty ||
      pendingResultPlans.isNotEmpty;

  bool get hasCommunityPlannerBadge => communityPlannerAlerts.isNotEmpty;

  bool get hasCommunityInvitationsBadge => communityInvitationAlerts.isNotEmpty;

  bool get hasPlayersBadge => playerInvitationAlerts.isNotEmpty;
  bool get hasProfileBadge => profileRatingAlerts.isNotEmpty;

  List<AppAlertItem> get allAlerts => [
        ...communityPlannerAlerts,
        ...communityInvitationAlerts,
        ...playerInvitationAlerts,
        ...profileRatingAlerts,
      ];
}
