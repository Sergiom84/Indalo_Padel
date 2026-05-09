import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/platform/platform_helper.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/utils/chronology.dart';
import '../../../shared/widgets/loading_spinner.dart';
import '../../../shared/widgets/notification_dot.dart';
import '../../../shared/widgets/padel_badge.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../../auth/providers/auth_provider.dart';
import '../../chat/providers/chat_provider.dart';
import '../../community/models/community_model.dart';
import '../../notifications/models/app_alerts_model.dart';
import '../../notifications/providers/app_alerts_provider.dart';
import '../../players/models/player_model.dart';
import '../../players/providers/player_provider.dart';
import '../../profile/providers/current_profile_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _loadingVenues = true;
  bool _loadingBookings = true;
  List<dynamic> _venues = [];
  List<dynamic> _matches = [];
  Map<String, dynamic> _bookings = {'upcoming': [], 'past': []};
  Map<String, dynamic> _metrics = {};
  List<Map<String, dynamic>> _confirmedCommunityPlans = [];
  List<Map<String, dynamic>> _upcomingCommunityMatches = [];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    final api = ref.read(apiClientProvider);
    if (mounted) {
      setState(() {
        _loadingVenues = true;
        _loadingBookings = true;
      });
    }

    try {
      final profileRefresh =
          ref.read(currentProfileProvider.notifier).refresh();
      final result = await api.get('/padel/dashboard');
      await profileRefresh;
      final json = _asMap(result);

      if (!mounted) {
        return;
      }

      final bookings = _asMap(json?['bookings']) ??
          const {
            'upcoming': [],
            'past': [],
          };
      final community = _asMap(json?['community']);

      setState(() {
        _venues = _asList(json?['venues']);
        _matches = _asList(json?['matches']);
        _bookings = bookings;
        _metrics = _asMap(json?['metrics']) ?? const {};
        if (community == null) {
          _confirmedCommunityPlans = const [];
          _upcomingCommunityMatches = const [];
        } else {
          _confirmedCommunityPlans =
              _buildCommunityBookingsFromDashboard(community);
          _upcomingCommunityMatches =
              _buildCommunityMatchesFromDashboard(community);
        }
        _loadingVenues = false;
        _loadingBookings = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadingVenues = false;
        _loadingBookings = false;
      });
    }
  }

  List<dynamic> _asList(dynamic value) {
    if (value is List) {
      return value;
    }
    return [];
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

  List<Map<String, dynamic>> _asMapList(dynamic value) {
    if (value is! List) {
      return const [];
    }

    return value
        .map(_asMap)
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
  }

  List<Map<String, dynamic>> _buildCommunityBookingsFromDashboard(
    dynamic payload,
  ) {
    final json = _asMap(payload);
    if (json == null) {
      return const [];
    }

    final plans = [
      ..._asMapList(json['active_plans']),
      ..._asMapList(json['history_plans']),
    ];

    return _buildCommunityBookingsFromPlans(plans);
  }

  List<Map<String, dynamic>> _buildCommunityBookingsFromPlans(
    List<Map<String, dynamic>> plans,
  ) {
    return plans.where(_isUpcomingConfirmedCommunityPlan).map((plan) {
      final venue = _asMap(plan['venue']);
      final startTime = plan['scheduled_time']?.toString() ?? '';
      return <String, dynamic>{
        '_type': 'community',
        'id': plan['id'],
        'venue_name': venue?['name']?.toString() ?? 'Convocatoria',
        'booking_date': plan['scheduled_date']?.toString() ?? '',
        'start_time':
            startTime.length >= 5 ? startTime.substring(0, 5) : startTime,
        'status': 'confirmada',
      };
    }).toList(growable: false);
  }

  List<Map<String, dynamic>> _buildCommunityMatchesFromDashboard(
    dynamic payload,
  ) {
    final json = _asMap(payload);
    if (json == null) {
      return const [];
    }

    final plans = [
      ..._asMapList(json['active_plans']),
      ..._asMapList(json['history_plans']),
    ];

    return plans.where(_isUpcomingCommunityMatchPlan).map((plan) {
      final venue = _asMap(plan['venue']);
      final participants = _asMapList(plan['participants']);
      final acceptedPlayers = participants.where((participant) {
        final state = participant['response_state']?.toString();
        return state == 'accepted' || _asBool(participant['is_organizer']);
      }).length;
      final startTime = plan['scheduled_time']?.toString() ?? '';
      final reservationState = plan['reservation_state']?.toString() ?? '';

      return <String, dynamic>{
        '_type': 'community',
        'id': plan['id'],
        'venue_name': venue?['name']?.toString() ?? 'Partido',
        'match_date': plan['scheduled_date']?.toString() ?? '',
        'start_time':
            startTime.length >= 5 ? startTime.substring(0, 5) : startTime,
        'status':
            reservationState == 'confirmed' ? 'confirmado' : 'convocatoria',
        'player_count': acceptedPlayers,
        'max_players': _asInt(plan['capacity']) ?? 4,
      };
    }).toList(growable: false);
  }

  bool _isUpcomingConfirmedCommunityPlan(Map<String, dynamic> plan) {
    if (plan['reservation_state']?.toString() != 'confirmed') {
      return false;
    }

    final hasBackendFlags =
        plan.containsKey('is_upcoming') || plan.containsKey('is_finished');
    if (hasBackendFlags) {
      return _asBool(plan['is_upcoming']) && !_asBool(plan['is_finished']);
    }

    return !_hasPlanEnded(plan);
  }

  bool _isUpcomingCommunityMatchPlan(Map<String, dynamic> plan) {
    final inviteState = plan['invite_state']?.toString().toLowerCase();
    final reservationState =
        plan['reservation_state']?.toString().toLowerCase();
    if (inviteState == 'cancelled' ||
        inviteState == 'expired' ||
        reservationState == 'cancelled' ||
        reservationState == 'expired') {
      return false;
    }

    final hasBackendFlags =
        plan.containsKey('is_upcoming') || plan.containsKey('is_finished');
    if (hasBackendFlags &&
        (!_asBool(plan['is_upcoming']) || _asBool(plan['is_finished']))) {
      return false;
    }

    if (!hasBackendFlags && _hasPlanEnded(plan)) {
      return false;
    }

    if (_asBool(plan['is_organizer'])) {
      return true;
    }

    final myResponseState = plan['my_response_state']?.toString();
    if (myResponseState == 'accepted') {
      return true;
    }

    return _asMapList(plan['participants']).any((participant) {
      return _asBool(participant['is_current_user']) &&
          (participant['response_state']?.toString() == 'accepted' ||
              _asBool(participant['is_organizer']));
    });
  }

  bool _hasPlanEnded(Map<String, dynamic> plan) {
    final scheduledDate = plan['scheduled_date']?.toString();
    final scheduledTime = plan['scheduled_time']?.toString();
    if (scheduledDate == null ||
        scheduledDate.isEmpty ||
        scheduledTime == null ||
        scheduledTime.isEmpty) {
      return false;
    }

    final date = DateTime.tryParse(scheduledDate);
    if (date == null) {
      return false;
    }

    final timeParts = scheduledTime.split(':');
    if (timeParts.length < 2) {
      return false;
    }

    final hour = int.tryParse(timeParts[0]);
    final minute = int.tryParse(timeParts[1]);
    final second = timeParts.length > 2 ? int.tryParse(timeParts[2]) ?? 0 : 0;
    if (hour == null || minute == null) {
      return false;
    }

    final durationMinutes = _asInt(plan['duration_minutes']) ?? 90;
    final start = DateTime(
      date.year,
      date.month,
      date.day,
      hour,
      minute,
      second,
    );

    return !start
        .add(Duration(minutes: durationMinutes))
        .isAfter(DateTime.now());
  }

  bool _asBool(dynamic value) {
    if (value is bool) {
      return value;
    }

    if (value is num) {
      return value != 0;
    }

    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1') {
        return true;
      }
      if (normalized == 'false' || normalized == '0') {
        return false;
      }
    }

    return false;
  }

  int? _asInt(dynamic value) {
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

  double? _asDouble(dynamic value) {
    if (value is double) {
      return value;
    }

    if (value is num) {
      return value.toDouble();
    }

    if (value is String) {
      return double.tryParse(value.replaceAll(',', '.'));
    }

    return null;
  }

  List<dynamic> get _allUpcomingBookings {
    final bookings = _asList(_bookings['upcoming'])
        .whereType<Map>()
        .map((booking) => Map<String, dynamic>.from(booking))
        .toList();

    final all = [...bookings, ..._confirmedCommunityPlans];

    all.sort((left, right) {
      final comparison = compareChronology(
        leftDate: left['booking_date']?.toString() ?? left['fecha']?.toString(),
        leftTime:
            left['start_time']?.toString() ?? left['hora_inicio']?.toString(),
        rightDate:
            right['booking_date']?.toString() ?? right['fecha']?.toString(),
        rightTime:
            right['start_time']?.toString() ?? right['hora_inicio']?.toString(),
      );
      if (comparison != 0) {
        return comparison;
      }
      final leftId = (left['id'] as num?)?.toInt() ?? 0;
      final rightId = (right['id'] as num?)?.toInt() ?? 0;
      return leftId.compareTo(rightId);
    });

    return all;
  }

  List<Map<String, dynamic>> get _allUpcomingMatches {
    final matches = _matches
        .whereType<Map>()
        .map((match) => Map<String, dynamic>.from(match))
        .where(_isUpcomingMatch)
        .toList();

    final all = [...matches, ..._upcomingCommunityMatches];

    all.sort((left, right) {
      final comparison = compareChronology(
        leftDate: left['match_date']?.toString() ??
            left['scheduled_date']?.toString(),
        leftTime: left['start_time']?.toString() ??
            left['scheduled_time']?.toString(),
        rightDate: right['match_date']?.toString() ??
            right['scheduled_date']?.toString(),
        rightTime: right['start_time']?.toString() ??
            right['scheduled_time']?.toString(),
      );
      if (comparison != 0) {
        return comparison;
      }
      final leftId = (left['id'] as num?)?.toInt() ?? 0;
      final rightId = (right['id'] as num?)?.toInt() ?? 0;
      return leftId.compareTo(rightId);
    });

    return all;
  }

  bool _isUpcomingMatch(Map<String, dynamic> match) {
    final status = match['status']?.toString().toLowerCase();
    if (status == 'finalizado' ||
        status == 'cancelado' ||
        status == 'cancelada' ||
        status == 'cancelled') {
      return false;
    }

    final dateTime = chronologyDateTime(
      match['match_date']?.toString() ?? match['scheduled_date']?.toString(),
      match['start_time']?.toString() ?? match['scheduled_time']?.toString(),
    );
    if (dateTime == null) {
      return true;
    }

    return !dateTime.isBefore(
      DateTime.now().subtract(const Duration(minutes: 1)),
    );
  }

  List<Map<String, dynamic>> get _featuredVenues => _venues
      .whereType<Map>()
      .map((venue) => Map<String, dynamic>.from(venue))
      .take(3)
      .toList(growable: false);

  int _dashboardMetric(String key, int fallback) =>
      _asInt(_metrics[key]) ?? fallback;

  String _profileRatingValue(Map<String, dynamic>? profile) {
    return (_asDouble(profile?['avg_rating']) ?? 0).toStringAsFixed(1);
  }

  String _rankingValue(Map<String, dynamic>? profile) {
    final position = _asInt(profile?['ranking_position']);
    if (position != null && position > 0) {
      return '#$position';
    }

    final points = _asInt(profile?['ranking_points']);
    if (points != null) {
      return '$points pts';
    }

    return 'Ver';
  }

  String _profileRatingsRoute() =>
      '/profile?ratings=${DateTime.now().millisecondsSinceEpoch}';

  void _openProfileRatings() {
    appLightImpact();
    context.go(_profileRatingsRoute());
  }

  void _openRanking() {
    appLightImpact();
    context.go('/players/ranking');
  }

  void _openMatches() {
    appLightImpact();
    context.go('/matches');
  }

  int _notificationCount(
    AppAlertsState alerts, {
    required int fallbackRequests,
  }) {
    final count = alerts.allAlerts.length + alerts.pendingResultPlans.length;
    if (count > 0) {
      return count;
    }
    return fallbackRequests;
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final profileAsync = ref.watch(currentProfileProvider);
    final profile = profileAsync.valueOrNull;
    final networkAsync = ref.watch(networkProvider);
    final alerts = ref.watch(appAlertsProvider);
    final incomingRequests =
        networkAsync.valueOrNull?.incomingRequests ?? const <PlayerModel>[];
    final chatUnreadCount = ref.watch(chatUnreadCountProvider);
    final greeting = (profile?['display_name'] ??
            profile?['nombre'] ??
            user?.nombre ??
            'Jugador')
        .toString();
    final avatarUrl = profile?['avatar_url']?.toString();
    final loadingSummary = _loadingVenues || _loadingBookings;
    final allUpcomingBookings = _allUpcomingBookings;
    final upcomingBookings = allUpcomingBookings.take(3).toList();
    final allUpcomingMatches = _allUpcomingMatches;
    final upcomingMatches = allUpcomingMatches.take(3).toList();
    final listedCommunityMatchesCount = _upcomingCommunityMatches.length;
    final listedLegacyMatchesCount =
        allUpcomingMatches.length - listedCommunityMatchesCount;
    final dashboardLegacyMatchesCount = _dashboardMetric(
      'upcoming_matches',
      listedLegacyMatchesCount,
    );
    final upcomingMatchesCount =
        (dashboardLegacyMatchesCount > listedLegacyMatchesCount
                ? dashboardLegacyMatchesCount
                : listedLegacyMatchesCount) +
            listedCommunityMatchesCount;
    final ratingLoading = profileAsync.isLoading && profile == null;
    final rankingLoading = ratingLoading;
    final featuredVenues = _featuredVenues;
    final notificationsCount =
        _notificationCount(alerts, fallbackRequests: incomingRequests.length);
    final notificationsLoading = (alerts.loading && notificationsCount == 0) ||
        (networkAsync.isLoading &&
            incomingRequests.isEmpty &&
            alerts.playerInvitationAlerts.any(
              (alert) => alert.kind == 'network_request',
            ));

    return Scaffold(
      backgroundColor: AppColors.dark,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: AppColors.surface,
          onRefresh: _fetchData,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 120),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _headlineDate(),
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Hola, $greeting',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _NotificationBellButton(
                    pendingCount: notificationsCount,
                    loading: notificationsLoading,
                    onTap: () => _openNotificationsDialog(
                      initialRequests: incomingRequests,
                      alerts: alerts,
                      loading: notificationsLoading,
                    ),
                  ),
                  const SizedBox(width: 10),
                  _ChatBubbleButton(
                    unreadCount: chatUnreadCount,
                    onTap: () {
                      appLightImpact();
                      context.push('/players/chat');
                    },
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () {
                      appLightImpact();
                      context.push('/profile');
                    },
                    child: UserAvatar(
                      displayName: greeting,
                      avatarUrl: avatarUrl,
                      size: 56,
                      fontSize: 20,
                      backgroundColor: AppColors.surface,
                      borderColor: AppColors.border,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Sesión de hoy',
                      style: TextStyle(
                        color: AppColors.muted,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: _MetricTile(
                            label: 'Valoración',
                            value: ratingLoading
                                ? '—'
                                : _profileRatingValue(profile),
                            showDot: alerts.hasProfileBadge,
                            onTap: _openProfileRatings,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _MetricTile(
                            label: 'Ranking',
                            value:
                                rankingLoading ? '—' : _rankingValue(profile),
                            onTap: _openRanking,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _MetricTile(
                            label: 'Partidos',
                            value: _loadingBookings
                                ? '—'
                                : '$upcomingMatchesCount',
                            onTap: _openMatches,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              _HomeSection(
                title: 'Próximos partidos a jugar',
                actionLabel: 'Ver partidos',
                onAction: _openMatches,
                child: _loadingBookings && upcomingMatches.isEmpty
                    ? const LoadingSpinner()
                    : upcomingMatches.isEmpty
                        ? const _EmptyState(
                            icon: Icons.sports_tennis_outlined,
                            message: 'No tienes partidos próximos.',
                          )
                        : Column(
                            children: upcomingMatches
                                .map((match) => _MatchPreviewCard(match: match))
                                .toList(),
                          ),
              ),
              const SizedBox(height: 18),
              _HomeSection(
                title: 'Próximas reservas',
                actionLabel: 'Ver calendario',
                onAction: () => context.go('/calendar'),
                child: _loadingBookings && upcomingBookings.isEmpty
                    ? const LoadingSpinner()
                    : upcomingBookings.isEmpty
                        ? const _EmptyState(
                            icon: Icons.calendar_today_outlined,
                            message: 'No tienes reservas próximas.',
                          )
                        : Column(
                            children: upcomingBookings
                                .map((booking) =>
                                    _BookingPreviewCard(booking: booking))
                                .toList(),
                          ),
              ),
              const SizedBox(height: 18),
              _HomeSection(
                title: 'Clubes destacados',
                actionLabel: 'Ver clubes',
                onAction:
                    featuredVenues.isEmpty ? null : () => context.go('/venues'),
                child: _loadingVenues && featuredVenues.isEmpty
                    ? const LoadingSpinner()
                    : featuredVenues.isEmpty
                        ? const _EmptyState(
                            icon: Icons.sports_tennis_outlined,
                            message: 'No hay clubes destacados.',
                          )
                        : Column(
                            children: featuredVenues
                                .map((venue) => _VenuePreviewCard(venue: venue))
                                .toList(),
                          ),
              ),
              if (loadingSummary)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Actualizando contenido...',
                    style: TextStyle(color: AppColors.muted, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openNotificationsDialog({
    required List<PlayerModel> initialRequests,
    required AppAlertsState alerts,
    required bool loading,
  }) async {
    final rootContext = context;

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        final requests = List<PlayerModel>.from(initialRequests);
        final busyIds = <int>{};
        final navigator = Navigator.of(dialogContext);

        return StatefulBuilder(
          builder: (context, setDialogState) {
            void closeAndGo(String location) {
              navigator.pop();
              if (mounted) {
                rootContext.go(location);
              }
            }

            Future<void> handleAction(PlayerModel player, String action) async {
              if (busyIds.contains(player.userId)) {
                return;
              }

              setDialogState(() => busyIds.add(player.userId));

              try {
                final message = await _respondToNetworkRequest(player, action);
                notifyPlayerNetworkChanged(ref);
                if (!mounted) {
                  return;
                }

                setDialogState(() {
                  busyIds.remove(player.userId);
                  requests.removeWhere(
                    (request) => request.userId == player.userId,
                  );
                });

                _showMessage(
                  message ??
                      (action == 'accepted'
                          ? '${player.displayName} ya forma parte de tu red.'
                          : 'Has rechazado la solicitud de ${player.displayName}.'),
                );
              } catch (error) {
                if (!mounted) {
                  return;
                }
                setDialogState(() => busyIds.remove(player.userId));
                _showMessage(error.toString(), isError: true);
              }
            }

            final playerAlerts = alerts.playerInvitationAlerts
                .where((alert) => alert.kind != 'network_request')
                .toList(growable: false);
            final hasNotifications = requests.isNotEmpty ||
                alerts.bookingInvitationAlerts.isNotEmpty ||
                alerts.communityInvitationAlerts.isNotEmpty ||
                alerts.communityPlannerAlerts.isNotEmpty ||
                alerts.pendingResultPlans.isNotEmpty ||
                playerAlerts.isNotEmpty ||
                alerts.profileRatingAlerts.isNotEmpty;

            return AlertDialog(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: const BorderSide(color: AppColors.border),
              ),
              titlePadding: const EdgeInsets.fromLTRB(20, 18, 12, 0),
              contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              title: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Notificaciones',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => navigator.pop(),
                    icon: const Icon(Icons.close, color: AppColors.muted),
                  ),
                ],
              ),
              content: SizedBox(
                width: 420,
                child: loading && !hasNotifications
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            LoadingSpinner(),
                            SizedBox(height: 12),
                            Text(
                              'Cargando notificaciones...',
                              style: TextStyle(color: AppColors.muted),
                            ),
                          ],
                        ),
                      )
                    : !hasNotifications
                        ? const _EmptyState(
                            icon: Icons.notifications_none_outlined,
                            message: 'No tienes notificaciones pendientes.',
                          )
                        : SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (requests.isNotEmpty)
                                  _NotificationDialogSection(
                                    title: 'Solicitudes de amistad',
                                    children: requests
                                        .map(
                                          (player) => _NetworkRequestDialogCard(
                                            player: player,
                                            busy:
                                                busyIds.contains(player.userId),
                                            onAccept: () => handleAction(
                                              player,
                                              'accepted',
                                            ),
                                            onReject: () => handleAction(
                                              player,
                                              'rejected',
                                            ),
                                          ),
                                        )
                                        .toList(growable: false),
                                  ),
                                if (alerts.bookingInvitationAlerts.isNotEmpty)
                                  _NotificationDialogSection(
                                    title: 'Reservas',
                                    children: alerts.bookingInvitationAlerts
                                        .map(
                                          (alert) => _AlertDialogCard(
                                            alert: alert,
                                            icon: Icons.calendar_today_outlined,
                                            actionLabel: 'Ver calendario',
                                            onAction: () =>
                                                closeAndGo('/calendar'),
                                          ),
                                        )
                                        .toList(growable: false),
                                  ),
                                if (alerts.communityInvitationAlerts.isNotEmpty)
                                  _NotificationDialogSection(
                                    title: 'Convocatorias',
                                    children: alerts.communityInvitationAlerts
                                        .map(
                                          (alert) => _AlertDialogCard(
                                            alert: alert,
                                            icon: Icons.sports_tennis_outlined,
                                            actionLabel: 'Ver comunidad',
                                            onAction: () =>
                                                closeAndGo('/community'),
                                          ),
                                        )
                                        .toList(growable: false),
                                  ),
                                if (alerts.communityPlannerAlerts.isNotEmpty)
                                  _NotificationDialogSection(
                                    title: 'Partidos organizados',
                                    children: alerts.communityPlannerAlerts
                                        .map(
                                          (alert) => _AlertDialogCard(
                                            alert: alert,
                                            icon: Icons.event_available,
                                            actionLabel: 'Ver comunidad',
                                            onAction: () =>
                                                closeAndGo('/community'),
                                          ),
                                        )
                                        .toList(growable: false),
                                  ),
                                if (alerts.pendingResultPlans.isNotEmpty)
                                  _NotificationDialogSection(
                                    title: 'Resultados pendientes',
                                    children: alerts.pendingResultPlans
                                        .map(
                                          (plan) => _AlertDialogCard(
                                            alert: _alertFromPendingPlan(plan),
                                            icon: Icons.fact_check_outlined,
                                            actionLabel: 'Ver comunidad',
                                            onAction: () =>
                                                closeAndGo('/community'),
                                          ),
                                        )
                                        .toList(growable: false),
                                  ),
                                if (playerAlerts.isNotEmpty)
                                  _NotificationDialogSection(
                                    title: 'Jugadores',
                                    children: playerAlerts
                                        .map(
                                          (alert) => _AlertDialogCard(
                                            alert: alert,
                                            icon: Icons.group_outlined,
                                            actionLabel: 'Ver jugadores',
                                            onAction: () =>
                                                closeAndGo('/players'),
                                          ),
                                        )
                                        .toList(growable: false),
                                  ),
                                if (alerts.profileRatingAlerts.isNotEmpty)
                                  _NotificationDialogSection(
                                    title: 'Valoraciones',
                                    children: alerts.profileRatingAlerts
                                        .map(
                                          (alert) => _AlertDialogCard(
                                            alert: alert,
                                            icon: Icons.star_border,
                                            actionLabel: 'Ver valoraciones',
                                            onAction: () => closeAndGo(
                                              _profileRatingsRoute(),
                                            ),
                                          ),
                                        )
                                        .toList(growable: false),
                                  ),
                              ],
                            ),
                          ),
              ),
            );
          },
        );
      },
    );

    if (mounted && alerts.hasHomeNotifications) {
      await ref.read(appAlertsProvider.notifier).markAlertsSeen(alerts);
    }
  }

  AppAlertItem _alertFromPendingPlan(CommunityPlanModel plan) {
    final details = [
      plan.venue?.name,
      _formatPlanDateTime(plan.scheduledDate, plan.scheduledTime),
    ].whereType<String>().where((item) => item.isNotEmpty).join(' · ');

    return AppAlertItem(
      uniqueKey: pendingResultAlertKey(plan),
      scope: AppAlertScope.communityPlanner,
      kind: 'pending_result',
      title: 'Resultado pendiente',
      body: details.isEmpty
          ? 'Tienes un partido pendiente de resultado.'
          : 'Tienes un partido pendiente de resultado. $details.',
    );
  }

  String? _formatPlanDateTime(String date, String time) {
    final cleanDate = date.trim();
    final cleanTime = time.trim();
    if (cleanDate.isEmpty && cleanTime.isEmpty) {
      return null;
    }

    final shortTime =
        cleanTime.length >= 5 ? cleanTime.substring(0, 5) : cleanTime;
    if (cleanDate.isEmpty) {
      return shortTime;
    }
    if (shortTime.isEmpty) {
      return cleanDate;
    }
    return '$cleanDate · $shortTime';
  }

  Future<String?> _respondToNetworkRequest(
    PlayerModel player,
    String action,
  ) async {
    final api = ref.read(apiClientProvider);
    final data = await api.post(
      '/padel/players/${player.userId}/network/respond',
      data: {'action': action},
    );
    if (data is Map && data['message'] != null) {
      return data['message'].toString();
    }
    return null;
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.danger : AppColors.surface,
      ),
    );
  }

  String _headlineDate() {
    final now = DateTime.now();
    const weekDays = [
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado',
      'Domingo',
    ];
    const months = [
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre',
    ];
    return '${weekDays[now.weekday - 1]}, ${now.day} ${months[now.month - 1]}';
  }
}

class _ChatBubbleButton extends StatelessWidget {
  final int unreadCount;
  final VoidCallback onTap;

  const _ChatBubbleButton({
    required this.unreadCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasUnread = unreadCount > 0;

    return Tooltip(
      message: 'Mensajes',
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(18),
              child: Ink(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: hasUnread
                      ? AppColors.primary.withValues(alpha: 0.16)
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: hasUnread
                        ? AppColors.primary.withValues(alpha: 0.55)
                        : AppColors.border,
                  ),
                ),
                child: Icon(
                  hasUnread ? Icons.forum : Icons.forum_outlined,
                  color: hasUnread ? AppColors.primary : Colors.white,
                ),
              ),
            ),
          ),
          if (hasUnread)
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.dark, width: 2),
                ),
                alignment: Alignment.center,
                child: Text(
                  unreadCount > 9 ? '9+' : '$unreadCount',
                  style: const TextStyle(
                    color: AppColors.dark,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _NotificationBellButton extends StatelessWidget {
  final int pendingCount;
  final bool loading;
  final VoidCallback onTap;

  const _NotificationBellButton({
    required this.pendingCount,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: Ink(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: pendingCount > 0
                      ? AppColors.primary.withValues(alpha: 0.45)
                      : AppColors.border,
                ),
              ),
              child: loading
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: AppColors.primary,
                      ),
                    )
                  : Icon(
                      pendingCount > 0
                          ? Icons.notifications_active_outlined
                          : Icons.notifications_none_outlined,
                      color:
                          pendingCount > 0 ? AppColors.primary : Colors.white,
                    ),
            ),
          ),
        ),
        if (!loading && pendingCount > 0)
          Positioned(
            top: -4,
            right: -4,
            child: Container(
              constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.dark, width: 2),
              ),
              alignment: Alignment.center,
              child: Text(
                pendingCount > 9 ? '9+' : '$pendingCount',
                style: const TextStyle(
                  color: AppColors.dark,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final bool showDot;
  final VoidCallback? onTap;

  const _MetricTile({
    required this.label,
    required this.value,
    this.showDot = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(18);

    return Material(
      color: Colors.transparent,
      borderRadius: borderRadius,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 82),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: borderRadius,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    height: 28,
                    width: double.infinity,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        value,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    height: 30,
                    child: Center(
                      child: Text(
                        label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                          height: 1.15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (showDot)
              const Positioned(
                top: 8,
                right: 8,
                child: NotificationDot(visible: true, size: 9),
              ),
          ],
        ),
      ),
    );
  }
}

class _HomeSection extends StatelessWidget {
  final String title;
  final String actionLabel;
  final VoidCallback? onAction;
  final Widget child;

  const _HomeSection({
    required this.title,
    required this.actionLabel,
    this.onAction,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TextButton(
                onPressed: onAction,
                child: Text(actionLabel),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _VenuePreviewCard extends StatelessWidget {
  final Map<String, dynamic> venue;

  const _VenuePreviewCard({required this.venue});

  String get _name => (venue['name'] ?? venue['nombre'] ?? 'Club').toString();

  String get _location =>
      (venue['location'] ?? venue['ubicacion'] ?? venue['address'] ?? '')
          .toString();

  int? get _id {
    final raw = venue['id'];
    if (raw is int) {
      return raw;
    }
    if (raw is num) {
      return raw.toInt();
    }
    if (raw is String) {
      return int.tryParse(raw);
    }
    return null;
  }

  bool get _isComingSoon {
    final status = (venue['booking_status'] ?? '').toString();
    if (status == 'coming_soon') {
      return true;
    }
    final raw = venue['is_bookable'];
    if (raw is bool) {
      return !raw;
    }
    if (raw is num) {
      return raw == 0;
    }
    if (raw is String) {
      final normalized = raw.trim().toLowerCase();
      return normalized == 'false' || normalized == '0';
    }
    return false;
  }

  String? get _hoursLabel {
    final opening = venue['opening_time']?.toString();
    final closing = venue['closing_time']?.toString();
    if (opening == null ||
        opening.trim().isEmpty ||
        closing == null ||
        closing.trim().isEmpty) {
      return null;
    }

    return '${_shortTime(opening)} - ${_shortTime(closing)}';
  }

  String _shortTime(String raw) => raw.length >= 5 ? raw.substring(0, 5) : raw;

  @override
  Widget build(BuildContext context) {
    final id = _id;
    final isComingSoon = _isComingSoon;
    final statusColor = isComingSoon ? AppColors.warning : AppColors.success;
    final hours = _hoursLabel;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: id == null || isComingSoon
          ? null
          : () {
              appLightImpact();
              context.go('/venues/$id');
            },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Icon(
                isComingSoon ? Icons.lock_clock_outlined : Icons.sports_tennis,
                color: statusColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (_location.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      _location,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          const TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                  ],
                  if (hours != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      hours,
                      style:
                          const TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            PadelBadge(
              label: isComingSoon ? 'Próximamente' : 'Disponible',
              variant: isComingSoon
                  ? PadelBadgeVariant.warning
                  : PadelBadgeVariant.success,
            ),
          ],
        ),
      ),
    );
  }
}

class _BookingPreviewCard extends StatelessWidget {
  final dynamic booking;

  const _BookingPreviewCard({required this.booking});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => context.go('/calendar'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.schedule, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    booking['venue_name']?.toString() ?? 'Reserva',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${booking['booking_date'] ?? booking['fecha'] ?? ''} · ${booking['start_time'] ?? booking['hora_inicio'] ?? ''}',
                    style:
                        const TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            PadelBadge(
              label: booking['status']?.toString() ?? 'pendiente',
              variant: _badgeForBooking(booking['status']?.toString() ?? ''),
            ),
          ],
        ),
      ),
    );
  }

  PadelBadgeVariant _badgeForBooking(String status) {
    switch (status) {
      case 'confirmada':
        return PadelBadgeVariant.success;
      case 'cancelada':
        return PadelBadgeVariant.danger;
      case 'pendiente':
        return PadelBadgeVariant.warning;
      default:
        return PadelBadgeVariant.neutral;
    }
  }
}

class _MatchPreviewCard extends StatelessWidget {
  final Map<String, dynamic> match;

  const _MatchPreviewCard({required this.match});

  int? get _id {
    final raw = match['id'];
    if (raw is int) {
      return raw;
    }
    if (raw is num) {
      return raw.toInt();
    }
    if (raw is String) {
      return int.tryParse(raw);
    }
    return null;
  }

  bool get _isCommunityMatch => match['_type']?.toString() == 'community';

  String get _venueName =>
      (match['venue_name'] ?? match['venue'] ?? 'Partido').toString();

  String get _date => (match['match_date'] ??
          match['scheduled_date'] ??
          match['booking_date'] ??
          '')
      .toString();

  String get _time =>
      (match['start_time'] ?? match['scheduled_time'] ?? '').toString();

  int get _playerCount => _asInt(match['player_count'] ??
      match['current_players'] ??
      match['accepted_players'] ??
      0);

  int get _maxPlayers => _asInt(match['max_players'] ?? match['capacity'] ?? 4);

  String get _status => (match['status'] ?? 'convocatoria').toString();

  static int _asInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }

  String _shortDate(String raw) =>
      raw.length >= 10 ? raw.substring(0, 10) : raw;

  String _shortTime(String raw) => raw.length >= 5 ? raw.substring(0, 5) : raw;

  String _statusLabel(String status) {
    switch (status) {
      case 'buscando':
        return 'Buscando';
      case 'completo':
        return 'Completo';
      case 'en_juego':
        return 'En juego';
      case 'confirmado':
        return 'Confirmado';
      case 'convocatoria':
        return 'Convocatoria';
      default:
        return status;
    }
  }

  PadelBadgeVariant _statusVariant(String status) {
    switch (status) {
      case 'buscando':
      case 'convocatoria':
        return PadelBadgeVariant.warning;
      case 'completo':
      case 'confirmado':
        return PadelBadgeVariant.success;
      case 'en_juego':
        return PadelBadgeVariant.info;
      case 'cancelado':
      case 'cancelada':
        return PadelBadgeVariant.danger;
      default:
        return PadelBadgeVariant.neutral;
    }
  }

  @override
  Widget build(BuildContext context) {
    final id = _id;
    final date = _shortDate(_date);
    final time = _shortTime(_time);
    final details = [
      if (date.isNotEmpty) date,
      if (time.isNotEmpty) time,
      '$_playerCount/$_maxPlayers jugadores',
    ].join(' · ');

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        appLightImpact();
        if (_isCommunityMatch || id == null) {
          context.go('/community');
        } else {
          context.go('/matches/$id');
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.sports_tennis_outlined,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _venueName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    details,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        const TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            PadelBadge(
              label: _statusLabel(_status),
              variant: _statusVariant(_status),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Icon(icon, color: AppColors.muted, size: 30),
          const SizedBox(height: 10),
          Text(
            message,
            style: const TextStyle(color: AppColors.muted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _NotificationDialogSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _NotificationDialogSection({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              title,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          ...children.map(
            (child) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertDialogCard extends StatelessWidget {
  final AppAlertItem alert;
  final IconData icon;
  final String actionLabel;
  final VoidCallback onAction;

  const _AlertDialogCard({
    required this.alert,
    required this.icon,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppColors.primary, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (alert.body.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    alert.body,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 13,
                      height: 1.3,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: onAction,
                    child: Text(actionLabel),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NetworkRequestDialogCard extends StatelessWidget {
  final PlayerModel player;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _NetworkRequestDialogCard({
    required this.player,
    required this.busy,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              UserAvatar(
                displayName: player.displayName,
                avatarUrl: player.avatarUrl,
                size: 44,
                fontSize: 16,
                backgroundColor: AppColors.surface,
                borderColor: AppColors.border,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: player.displayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const TextSpan(
                        text: ' ha solicitado unirse a tu red.',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: busy ? null : onReject,
                  child: const Text('Rechazar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: busy ? null : onAccept,
                  child: busy
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Aceptar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
