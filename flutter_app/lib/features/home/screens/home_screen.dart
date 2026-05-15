import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/platform/platform_helper.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/utils/chronology.dart';
import '../../../shared/widgets/loading_spinner.dart';
import '../../../shared/widgets/notification_dot.dart';
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

class _HomePalette {
  static const background = Color(0xFFF4F6FA);
  static const card = Color(0xFFFFFFFF);
  static const navy = Color(0xFF1A3A5C);
  static const navyDeep = Color(0xFF0F2440);
  static const orange = Color(0xFFE8732C);
  static const text = Color(0xFF1A2233);
  static const textSecondary = Color(0xFF5A6678);
  static const textMuted = Color(0xFF94A0B4);
  static const border = Color(0xFFE2E8F0);
  static const success = Color(0xFF16A34A);
  static const successBg = Color(0xFFECFDF5);
  static const warning = Color(0xFFF59E0B);
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

  Future<void> _openProfileRatings() async {
    appLightImpact();
    final unreadRatingAlerts = ref.read(appAlertsProvider).profileRatingAlerts;

    try {
      final api = ref.read(apiClientProvider);
      final data = await api.get('/padel/players/profile/ratings');
      final list = data is Map ? data['ratings'] : const [];
      final ratings = list is List
          ? list
              .whereType<Map>()
              .map(
                (rating) => RatingModel.fromJson(
                  Map<String, dynamic>.from(rating),
                ),
              )
              .toList(growable: false)
          : const <RatingModel>[];

      if (!mounted) {
        return;
      }

      if (unreadRatingAlerts.isNotEmpty) {
        await ref.read(appAlertsProvider.notifier).markProfileRatingsSeen();
      }

      if (!mounted) {
        return;
      }

      await showModalBottomSheet<void>(
        context: context,
        useRootNavigator: true,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (context) => _HomeRatingsSheet(ratings: ratings),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage(error.toString(), isError: true);
    }
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

  List<_HomeActivityEntry> _buildActivityEntries({
    required List<Map<String, dynamic>> matches,
    required List<dynamic> bookings,
  }) {
    final entries = <_HomeActivityEntry>[
      ...matches.map((match) {
        final date = _homeString(
          match['match_date'] ??
              match['scheduled_date'] ??
              match['booking_date'],
        );
        final time =
            _homeString(match['start_time'] ?? match['scheduled_time']);
        final playerCount = _asInt(
              match['player_count'] ??
                  match['current_players'] ??
                  match['accepted_players'],
            ) ??
            0;
        final maxPlayers =
            _asInt(match['max_players'] ?? match['capacity']) ?? 4;

        return _HomeActivityEntry(
          type: _HomeActivityType.match,
          title: _homeString(match['venue_name'] ?? match['venue'], 'Partido'),
          subtitle: _joinHomeDetails([
            _formatHomeDate(date),
            _shortHomeTime(time),
          ]),
          badge: '$playerCount/$maxPlayers',
          icon: Icons.sports_tennis,
          accentColor: _HomePalette.orange,
          date: date,
          time: time,
          matchId: _asInt(match['id']),
          isCommunityMatch: match['_type']?.toString() == 'community',
        );
      }),
      ...bookings.whereType<Map>().map((booking) {
        final json = Map<String, dynamic>.from(booking);
        final date = _homeString(json['booking_date'] ?? json['fecha']);
        final time = _homeString(json['start_time'] ?? json['hora_inicio']);
        final status = _homeString(json['status'], 'confirmada');
        final court = _homeString(json['court_name']);

        return _HomeActivityEntry(
          type: _HomeActivityType.booking,
          title:
              _homeString(json['venue_name'] ?? json['pista_name'], 'Reserva'),
          subtitle: _joinHomeDetails([
            _formatHomeDate(date),
            _shortHomeTime(time),
            court,
          ]),
          badge: _bookingStatusLabel(status),
          icon: Icons.calendar_today,
          accentColor: status == 'confirmada'
              ? _HomePalette.success
              : _HomePalette.warning,
          date: date,
          time: time,
        );
      }),
    ];

    entries.sort(
      (left, right) => compareChronology(
        leftDate: left.date,
        leftTime: left.time,
        rightDate: right.date,
        rightTime: right.time,
      ),
    );
    return entries.take(3).toList(growable: false);
  }

  String _bookingStatusLabel(String status) {
    switch (status) {
      case 'confirmada':
        return 'Confirmado';
      case 'cancelada':
        return 'Cancelada';
      case 'pendiente':
        return 'Pendiente';
      default:
        return status.isEmpty ? 'Reserva' : status;
    }
  }

  void _openMatch(Map<String, dynamic> match) {
    appLightImpact();
    final id = _asInt(match['id']);
    if (match['_type']?.toString() == 'community' || id == null) {
      context.go('/community');
    } else {
      context.go('/matches/$id');
    }
  }

  void _openActivityEntry(_HomeActivityEntry entry) {
    appLightImpact();
    if (entry.type == _HomeActivityType.booking) {
      context.go('/calendar');
      return;
    }

    if (entry.isCommunityMatch || entry.matchId == null) {
      context.go('/community');
    } else {
      context.go('/matches/${entry.matchId}');
    }
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
    final nextMatch = upcomingMatches.isEmpty ? null : upcomingMatches.first;
    final activityEntries = _buildActivityEntries(
      matches: allUpcomingMatches,
      bookings: allUpcomingBookings,
    );

    return Scaffold(
      backgroundColor: _HomePalette.background,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: _HomePalette.orange,
          backgroundColor: _HomePalette.card,
          onRefresh: _fetchData,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 120),
            children: [
              _HomeHeader(
                headlineDate: _headlineDate(),
                greeting: greeting,
                avatarUrl: avatarUrl,
                notificationsCount: notificationsCount,
                notificationsLoading: notificationsLoading,
                chatUnreadCount: chatUnreadCount,
                onNotificationsTap: () => _openNotificationsDialog(
                  initialRequests: incomingRequests,
                  alerts: alerts,
                  loading: notificationsLoading,
                ),
                onChatTap: () {
                  appLightImpact();
                  context.push('/players/chat');
                },
                onProfileTap: () {
                  appLightImpact();
                  context.push('/profile');
                },
              ),
              const SizedBox(height: 18),
              if (_loadingBookings && nextMatch == null)
                const _HomeHeroLoadingCard()
              else if (nextMatch != null)
                _NextMatchHeroCard(
                  match: nextMatch,
                  onTap: () => _openMatch(nextMatch),
                )
              else
                _HomeHeroEmptyCard(
                  onCreateMatch: () {
                    appLightImpact();
                    context.go('/matches/create');
                  },
                ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _MetricTile(
                      icon: Icons.star,
                      label: 'Valoración',
                      value: ratingLoading ? '—' : _profileRatingValue(profile),
                      showDot: alerts.hasProfileBadge,
                      onTap: _openProfileRatings,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MetricTile(
                      icon: Icons.leaderboard,
                      label: 'Ranking',
                      value: rankingLoading ? '—' : _rankingValue(profile),
                      accentColor: _HomePalette.navy,
                      onTap: _openRanking,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MetricTile(
                      icon: Icons.sports_tennis,
                      label: 'Partidos',
                      value: _loadingBookings ? '—' : '$upcomingMatchesCount',
                      onTap: _openMatches,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _QuickActionsRow(
                onCreateMatch: () {
                  appLightImpact();
                  context.go('/matches/create');
                },
                onFindPlayers: () {
                  appLightImpact();
                  context.go('/players');
                },
                onBookCourt: () {
                  appLightImpact();
                  context.go('/venues');
                },
              ),
              const SizedBox(height: 22),
              _HomeSection(
                title: 'Tu actividad',
                actionLabel: 'Ver todo',
                icon: Icons.timeline,
                onAction: () => context.go('/calendar'),
                child: _loadingBookings && activityEntries.isEmpty
                    ? const LoadingSpinner()
                    : activityEntries.isEmpty
                        ? const _EmptyState(
                            icon: Icons.timeline,
                            message: 'Todavía no tienes actividad próxima.',
                          )
                        : _ActivityTimeline(
                            entries: activityEntries,
                            onEntryTap: _openActivityEntry,
                          ),
              ),
              const SizedBox(height: 20),
              _HomeSection(
                title: 'Reservas próximas',
                actionLabel: 'Calendario',
                icon: Icons.calendar_today,
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
                                .map(
                                  (booking) =>
                                      _BookingPreviewCard(booking: booking),
                                )
                                .toList(),
                          ),
              ),
              const SizedBox(height: 20),
              _HomeSection(
                title: 'Clubes destacados',
                actionLabel: 'Ver clubes',
                icon: Icons.location_on,
                onAction:
                    featuredVenues.isEmpty ? null : () => context.go('/venues'),
                child: _loadingVenues && featuredVenues.isEmpty
                    ? const LoadingSpinner()
                    : featuredVenues.isEmpty
                        ? const _EmptyState(
                            icon: Icons.sports_tennis_outlined,
                            message: 'No hay clubes destacados.',
                          )
                        : SizedBox(
                            height: 84,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: featuredVenues.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 10),
                              itemBuilder: (context, index) {
                                return _VenuePreviewCard(
                                  venue: featuredVenues[index],
                                );
                              },
                            ),
                          ),
              ),
              if (loadingSummary)
                const Padding(
                  padding: EdgeInsets.only(top: 14),
                  child: Text(
                    'Actualizando contenido...',
                    style: TextStyle(
                      color: _HomePalette.textSecondary,
                      fontSize: 12,
                    ),
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

            void closeAndOpenRatings() {
              navigator.pop();
              if (mounted) {
                _openProfileRatings();
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
                                            onAction: closeAndOpenRatings,
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

class _HomeHeader extends StatelessWidget {
  final String headlineDate;
  final String greeting;
  final String? avatarUrl;
  final int notificationsCount;
  final bool notificationsLoading;
  final int chatUnreadCount;
  final VoidCallback onNotificationsTap;
  final VoidCallback onChatTap;
  final VoidCallback onProfileTap;

  const _HomeHeader({
    required this.headlineDate,
    required this.greeting,
    required this.avatarUrl,
    required this.notificationsCount,
    required this.notificationsLoading,
    required this.chatUnreadCount,
    required this.onNotificationsTap,
    required this.onChatTap,
    required this.onProfileTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                headlineDate,
                style: const TextStyle(
                  color: _HomePalette.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Hola, $greeting',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _HomePalette.text,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        _NotificationBellButton(
          pendingCount: notificationsCount,
          loading: notificationsLoading,
          onTap: onNotificationsTap,
        ),
        const SizedBox(width: 8),
        _ChatBubbleButton(
          unreadCount: chatUnreadCount,
          onTap: onChatTap,
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: onProfileTap,
          child: UserAvatar(
            displayName: greeting,
            avatarUrl: avatarUrl,
            size: 46,
            fontSize: 17,
            backgroundColor: _HomePalette.card,
            borderColor: _HomePalette.border,
          ),
        ),
      ],
    );
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
              borderRadius: BorderRadius.circular(13),
              child: Ink(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: hasUnread
                      ? _HomePalette.orange.withValues(alpha: 0.12)
                      : _HomePalette.card,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: hasUnread
                        ? _HomePalette.orange.withValues(alpha: 0.24)
                        : _HomePalette.border,
                  ),
                ),
                child: Icon(
                  hasUnread ? Icons.forum : Icons.forum_outlined,
                  color: hasUnread ? _HomePalette.orange : _HomePalette.navy,
                  size: 22,
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
                  color: _HomePalette.orange,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: _HomePalette.background, width: 2),
                ),
                alignment: Alignment.center,
                child: Text(
                  unreadCount > 9 ? '9+' : '$unreadCount',
                  style: const TextStyle(
                    color: Colors.white,
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
            borderRadius: BorderRadius.circular(13),
            child: Ink(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _HomePalette.card,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                  color: pendingCount > 0
                      ? _HomePalette.orange.withValues(alpha: 0.28)
                      : _HomePalette.border,
                ),
              ),
              child: loading
                  ? const Padding(
                      padding: EdgeInsets.all(11),
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: _HomePalette.orange,
                      ),
                    )
                  : Icon(
                      pendingCount > 0
                          ? Icons.notifications_active_outlined
                          : Icons.notifications_none_outlined,
                      color: pendingCount > 0
                          ? _HomePalette.orange
                          : _HomePalette.navy,
                      size: 22,
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
                color: _HomePalette.orange,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: _HomePalette.background, width: 2),
              ),
              alignment: Alignment.center,
              child: Text(
                pendingCount > 9 ? '9+' : '$pendingCount',
                style: const TextStyle(
                  color: Colors.white,
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

class _HomeHeroLoadingCard extends StatelessWidget {
  const _HomeHeroLoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 204,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [_HomePalette.navyDeep, _HomePalette.navy],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const LoadingSpinner(),
    );
  }
}

class _NextMatchHeroCard extends StatelessWidget {
  final Map<String, dynamic> match;
  final VoidCallback onTap;

  const _NextMatchHeroCard({
    required this.match,
    required this.onTap,
  });

  bool get _isCommunityMatch => match['_type']?.toString() == 'community';

  String get _venueName =>
      _homeString(match['venue_name'] ?? match['venue'], 'Partido');

  String get _date => _homeString(
        match['match_date'] ?? match['scheduled_date'] ?? match['booking_date'],
      );

  String get _time =>
      _homeString(match['start_time'] ?? match['scheduled_time']);

  int get _playerCount => _homeInt(
        match['player_count'] ??
            match['current_players'] ??
            match['accepted_players'],
      );

  int get _maxPlayers => _homeInt(match['max_players'] ?? match['capacity'], 4);

  @override
  Widget build(BuildContext context) {
    final details = _joinHomeDetails([
      _formatHomeDate(_date),
      _shortHomeTime(_time),
      _homeString(match['court_name']),
    ]);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              colors: [_HomePalette.navyDeep, _HomePalette.navy],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            children: [
              const Positioned(
                top: -32,
                right: -22,
                child: _HeroArc(size: 122, opacity: 0.42),
              ),
              const Positioned(
                top: -14,
                right: -4,
                child: _HeroArc(size: 82, opacity: 0.24, strokeWidth: 2),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.sports_tennis,
                          color: _HomePalette.orange,
                          size: 17,
                        ),
                        const SizedBox(width: 7),
                        Text(
                          _isCommunityMatch
                              ? 'CONVOCATORIA ABIERTA'
                              : 'PRÓXIMO PARTIDO',
                          style: const TextStyle(
                            color: Color(0xCCFFFFFF),
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 17),
                    Text(
                      _venueName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      details.isEmpty ? 'Fecha pendiente' : details,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xCCFFFFFF),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        _PlayerSlots(
                          count: _playerCount,
                          maxPlayers: _maxPlayers,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '$_playerCount/$_maxPlayers jugadores',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xCCFFFFFF),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        FilledButton(
                          onPressed: onTap,
                          style: FilledButton.styleFrom(
                            backgroundColor: _HomePalette.orange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 17,
                              vertical: 10,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(11),
                            ),
                          ),
                          child: const Text(
                            'Ver detalles',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroArc extends StatelessWidget {
  final double size;
  final double opacity;
  final double strokeWidth;

  const _HeroArc({
    required this.size,
    required this.opacity,
    this.strokeWidth = 3,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: _HomePalette.orange.withValues(alpha: opacity),
          width: strokeWidth,
        ),
      ),
    );
  }
}

class _PlayerSlots extends StatelessWidget {
  final int count;
  final int maxPlayers;

  const _PlayerSlots({
    required this.count,
    required this.maxPlayers,
  });

  @override
  Widget build(BuildContext context) {
    final visibleSlots = maxPlayers.clamp(1, 4).toInt();
    return SizedBox(
      width: 24.0 + ((visibleSlots - 1) * 20),
      height: 31,
      child: Stack(
        children: [
          for (var index = 0; index < visibleSlots; index++)
            Positioned(
              left: index * 20,
              child: Container(
                width: 31,
                height: 31,
                decoration: BoxDecoration(
                  color: index < count
                      ? _HomePalette.orange.withValues(
                          alpha: index == 0 ? 1 : 0.72,
                        )
                      : Colors.white.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: index < count
                        ? Colors.white.withValues(alpha: 0.34)
                        : Colors.white.withValues(alpha: 0.32),
                    width: index < count ? 2 : 1.5,
                  ),
                ),
                child: Icon(
                  index < count ? Icons.person : Icons.add,
                  color:
                      Colors.white.withValues(alpha: index < count ? 1 : 0.7),
                  size: 15,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HomeHeroEmptyCard extends StatelessWidget {
  final VoidCallback onCreateMatch;

  const _HomeHeroEmptyCard({required this.onCreateMatch});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [_HomePalette.navyDeep, _HomePalette.navy],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: _HomePalette.orange.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.sports_tennis,
              color: _HomePalette.orange,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Organiza tu próximo partido',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Crea una convocatoria y encuentra jugadores disponibles.',
                  style: TextStyle(
                    color: Color(0xCCFFFFFF),
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          IconButton.filled(
            onPressed: onCreateMatch,
            style: IconButton.styleFrom(
              backgroundColor: _HomePalette.orange,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color accentColor;
  final bool showDot;
  final VoidCallback? onTap;

  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
    this.accentColor = _HomePalette.orange,
    this.showDot = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(16);

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
              constraints: const BoxConstraints(minHeight: 118),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
              decoration: BoxDecoration(
                color: _HomePalette.card,
                borderRadius: borderRadius,
                border: Border.all(color: _HomePalette.border),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: accentColor, size: 19),
                  const SizedBox(height: 10),
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
                          color: _HomePalette.text,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 28,
                    child: Center(
                      child: Text(
                        label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: _HomePalette.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
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

class _QuickActionsRow extends StatelessWidget {
  final VoidCallback onCreateMatch;
  final VoidCallback onFindPlayers;
  final VoidCallback onBookCourt;

  const _QuickActionsRow({
    required this.onCreateMatch,
    required this.onFindPlayers,
    required this.onBookCourt,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _QuickActionButton(
            icon: Icons.add_circle,
            label: 'Crear partido',
            accent: true,
            onTap: onCreateMatch,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _QuickActionButton(
            icon: Icons.group_add,
            label: 'Buscar jugadores',
            onTap: onFindPlayers,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _QuickActionButton(
            icon: Icons.event,
            label: 'Reservar pista',
            onTap: onBookCourt,
          ),
        ),
      ],
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool accent;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    this.accent = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = accent ? _HomePalette.orange : _HomePalette.navy;
    final background = accent
        ? _HomePalette.orange.withValues(alpha: 0.12)
        : _HomePalette.card;
    final borderColor = accent
        ? _HomePalette.orange.withValues(alpha: 0.28)
        : _HomePalette.border;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          height: 86,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 13),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 23),
              const SizedBox(height: 8),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: accent ? _HomePalette.orange : _HomePalette.text,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivityTimeline extends StatelessWidget {
  final List<_HomeActivityEntry> entries;
  final ValueChanged<_HomeActivityEntry> onEntryTap;

  const _ActivityTimeline({
    required this.entries,
    required this.onEntryTap,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 20,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                Positioned.fill(
                  left: 9,
                  right: 9,
                  top: 8,
                  bottom: 14,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: _HomePalette.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                for (var i = 0; i < entries.length; i++)
                  Positioned(
                    top: (i * 84 + 17).toDouble(),
                    child: _ActivityDot(color: entries[i].accentColor),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              children: [
                for (final entry in entries)
                  _ActivityTimelineCard(
                    entry: entry,
                    onTap: () => onEntryTap(entry),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityDot extends StatelessWidget {
  final Color color;

  const _ActivityDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.35), width: 2),
      ),
      alignment: Alignment.center,
      child: Container(
        width: 5,
        height: 5,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _ActivityTimelineCard extends StatelessWidget {
  final _HomeActivityEntry entry;
  final VoidCallback onTap;

  const _ActivityTimelineCard({
    required this.entry,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSuccess = entry.accentColor == _HomePalette.success;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _HomePalette.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _HomePalette.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: entry.accentColor.withValues(alpha: 0.11),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(entry.icon, color: entry.accentColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _HomePalette.text,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        entry.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _HomePalette.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: isSuccess
                        ? _HomePalette.successBg
                        : _HomePalette.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    entry.badge,
                    style: TextStyle(
                      color: isSuccess
                          ? _HomePalette.success
                          : _HomePalette.orange,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeSection extends StatelessWidget {
  final String title;
  final String actionLabel;
  final IconData icon;
  final VoidCallback? onAction;
  final Widget child;

  const _HomeSection({
    required this.title,
    required this.actionLabel,
    required this.icon,
    this.onAction,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Icon(icon, color: _HomePalette.orange, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: _HomePalette.text,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              TextButton(
                onPressed: onAction,
                style: TextButton.styleFrom(
                  foregroundColor: _HomePalette.orange,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(actionLabel),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

class _VenuePreviewCard extends StatelessWidget {
  final Map<String, dynamic> venue;

  const _VenuePreviewCard({required this.venue});

  String get _name => (venue['name'] ?? venue['nombre'] ?? 'Club').toString();

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
    final statusColor =
        isComingSoon ? _HomePalette.warning : _HomePalette.success;
    final hours = _hoursLabel;

    return SizedBox(
      width: 162,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: id == null || isComingSoon
              ? null
              : () {
                  appLightImpact();
                  context.go('/venues/$id');
                },
          child: Ink(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: _HomePalette.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _HomePalette.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _HomePalette.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 9),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        hours ?? (isComingSoon ? 'Próximamente' : 'Abierto'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _HomePalette.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
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
    final date = _homeString(booking['booking_date'] ?? booking['fecha']);
    final time = _homeString(booking['start_time'] ?? booking['hora_inicio']);
    final court = _homeString(booking['court_name']);
    final details = _joinHomeDetails([
      _formatHomeDate(date),
      _shortHomeTime(time),
      court,
    ]);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.go('/calendar'),
          child: Ink(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: _HomePalette.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _HomePalette.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: _HomePalette.navy.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.calendar_today,
                    color: _HomePalette.navy,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        booking['venue_name']?.toString() ?? 'Reserva',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _HomePalette.text,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        details.isEmpty ? 'Horario pendiente' : details,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _HomePalette.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right,
                  color: _HomePalette.textSecondary,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeRatingsSheet extends StatelessWidget {
  final List<RatingModel> ratings;

  const _HomeRatingsSheet({required this.ratings});

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.82,
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Valoraciones recibidas',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.close, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ratings.isEmpty
                  ? const _EmptyRatingsState()
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                      itemCount: ratings.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        return _HomeRatingCard(rating: ratings[index]);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyRatingsState extends StatelessWidget {
  const _EmptyRatingsState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.star_outline, color: AppColors.border, size: 52),
            SizedBox(height: 12),
            Text(
              'Aún no tienes valoraciones.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeRatingCard extends StatelessWidget {
  final RatingModel rating;

  const _HomeRatingCard({required this.rating});

  @override
  Widget build(BuildContext context) {
    final contextLabel = _ratingContextLabel(rating);
    final createdLabel = _formatRatingCreatedAt(rating.createdAt);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.star,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rating.raterName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (contextLabel != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        contextLabel,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _RatingStars(value: rating.rating),
            ],
          ),
          if (rating.comment != null && rating.comment!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              rating.comment!.trim(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                height: 1.35,
              ),
            ),
          ],
          if (createdLabel != null) ...[
            const SizedBox(height: 12),
            Text(
              createdLabel,
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

class _RatingStars extends StatelessWidget {
  final double value;

  const _RatingStars({required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...List.generate(
          5,
          (index) => Icon(
            Icons.star,
            size: 14,
            color: index < value.round() ? Colors.amber : AppColors.muted,
          ),
        ),
      ],
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
          Icon(icon, color: _HomePalette.textMuted, size: 30),
          const SizedBox(height: 10),
          Text(
            message,
            style: const TextStyle(color: _HomePalette.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

enum _HomeActivityType { match, booking }

class _HomeActivityEntry {
  final _HomeActivityType type;
  final String title;
  final String subtitle;
  final String badge;
  final IconData icon;
  final Color accentColor;
  final String date;
  final String time;
  final int? matchId;
  final bool isCommunityMatch;

  const _HomeActivityEntry({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.icon,
    required this.accentColor,
    required this.date,
    required this.time,
    this.matchId,
    this.isCommunityMatch = false,
  });
}

String _homeString(dynamic value, [String fallback = '']) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

int _homeInt(dynamic value, [int fallback = 0]) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value) ?? fallback;
  }
  return fallback;
}

String _shortHomeTime(String value) {
  return value.length >= 5 ? value.substring(0, 5) : value;
}

String _joinHomeDetails(List<String> values) {
  return values.where((value) => value.trim().isNotEmpty).join(' · ');
}

String _formatHomeDate(String raw) {
  if (raw.trim().isEmpty) {
    return '';
  }
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) {
    return raw.length >= 10 ? raw.substring(0, 10) : raw;
  }

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

  return '${weekDays[parsed.weekday - 1]} ${parsed.day} '
      '${months[parsed.month - 1]}';
}

String? _ratingContextLabel(RatingModel rating) {
  final parts = <String>[];
  final venue = rating.venueName?.trim();
  if (venue != null && venue.isNotEmpty) {
    parts.add(venue);
  }

  final date = _formatRatingDate(rating.scheduledDate);
  final time = _formatRatingTime(rating.scheduledTime);
  if (date != null) {
    parts.add(time == null ? date : '$date · $time');
  }

  if (parts.isEmpty) {
    return null;
  }
  return parts.join(' · ');
}

String? _formatRatingCreatedAt(String? value) {
  if (value == null || value.trim().isEmpty) {
    return null;
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    return null;
  }
  final local = parsed.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final year = local.year.toString();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return 'Recibida el $day/$month/$year a las $hour:$minute';
}

String? _formatRatingDate(String? value) {
  if (value == null || value.trim().isEmpty) {
    return null;
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    return value;
  }
  final day = parsed.day.toString().padLeft(2, '0');
  final month = parsed.month.toString().padLeft(2, '0');
  return '$day/$month/${parsed.year}';
}

String? _formatRatingTime(String? value) {
  if (value == null || value.trim().isEmpty) {
    return null;
  }
  final parts = value.split(':');
  if (parts.length < 2) {
    return value;
  }
  return '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}';
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
