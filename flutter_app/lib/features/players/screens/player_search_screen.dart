import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../chat/providers/chat_provider.dart';
import '../../../shared/utils/player_preferences.dart';
import '../../notifications/providers/app_alerts_provider.dart';
import '../../../shared/widgets/loading_spinner.dart';
import '../../../shared/widgets/notification_dot.dart';
import '../../../shared/widgets/padel_badge.dart';
import '../../../shared/widgets/preference_summary_chips.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../models/player_model.dart';
import '../providers/player_provider.dart';

class PlayerSearchScreen extends ConsumerStatefulWidget {
  const PlayerSearchScreen({super.key});

  @override
  ConsumerState<PlayerSearchScreen> createState() => _PlayerSearchScreenState();
}

class _PlayerSearchScreenState extends ConsumerState<PlayerSearchScreen>
    with SingleTickerProviderStateMixin {
  final _searchCtrl = TextEditingController();
  final Set<int> _busyPlayerIds = <int>{};
  late final TabController _tabController;

  bool _loadingDiscover = false;
  bool _loadingNetwork = false;
  bool _showFilters = false;
  List<PlayerModel> _players = const [];
  PlayerNetworkSnapshot _network = const PlayerNetworkSnapshot();
  String? _filterMainLevel;
  String? _filterSubLevel;
  String? _filterGender;
  bool _filterAvailable = false;
  Timer? _searchDebounce;
  int _searchSequence = 0;

  int? get _filterNumericLevel => PlayerPreferenceCatalog.numericLevelFor(
        mainLevel: _filterMainLevel,
        subLevel: _filterSubLevel,
      );

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _searchCtrl.addListener(_onSearchChanged);
    _refreshAll();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), _search);
  }

  void _setFilterNumericLevel(int? numericLevel) {
    final option = PlayerPreferenceCatalog.optionForNumericLevel(numericLevel);
    setState(() {
      _filterMainLevel = option?.mainLevel;
      _filterSubLevel = option?.subLevel;
    });
  }

  Future<void> _refreshAll() async {
    await Future.wait([
      _fetchNetwork(),
      _search(),
    ]);
  }

  Future<void> _fetchNetwork() async {
    if (mounted) {
      setState(() => _loadingNetwork = true);
    }

    try {
      final api = ref.read(apiClientProvider);
      final data = await api.get('/padel/players/network');
      if (!mounted) {
        return;
      }

      final json = data is Map<String, dynamic>
          ? data
          : Map<String, dynamic>.from(data as Map);
      setState(() {
        _network = PlayerNetworkSnapshot.fromJson(json);
        _loadingNetwork = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() => _loadingNetwork = false);
      _showMessage(error.toString(), isError: true);
    }
  }

  Future<void> _search() async {
    _searchDebounce?.cancel();
    final requestId = ++_searchSequence;
    if (mounted) {
      setState(() => _loadingDiscover = true);
    }

    try {
      final api = ref.read(apiClientProvider);
      final params = <String, dynamic>{};
      if (_searchCtrl.text.trim().isNotEmpty) {
        params['name'] = _searchCtrl.text.trim();
      }
      if (_filterMainLevel != null) {
        params['main_level'] = _filterMainLevel!;
      }
      if (_filterSubLevel != null) {
        params['sub_level'] = _filterSubLevel!;
      }
      if (_filterGender != null) {
        params['gender'] = _filterGender!;
      }
      if (_filterAvailable) {
        params['available'] = 'true';
      }

      final queryString = params.entries
          .map((entry) =>
              '${entry.key}=${Uri.encodeComponent(entry.value.toString())}')
          .join('&');
      final data = await api.get(
        '/padel/players/search${queryString.isNotEmpty ? '?$queryString' : ''}',
      );
      final list = data is List ? data : (data['players'] ?? const []);

      if (!mounted || requestId != _searchSequence) {
        return;
      }

      setState(() {
        _players = (list as List)
            .whereType<Map>()
            .map((player) =>
                PlayerModel.fromJson(Map<String, dynamic>.from(player)))
            .toList(growable: false);
        _loadingDiscover = false;
      });
    } catch (error) {
      if (!mounted || requestId != _searchSequence) {
        return;
      }

      setState(() => _loadingDiscover = false);
      _showMessage(error.toString(), isError: true);
    }
  }

  bool _isBusy(int playerId) => _busyPlayerIds.contains(playerId);

  Future<void> _runPlayerAction(
    int playerId,
    Future<String?> Function() action,
  ) async {
    if (_busyPlayerIds.contains(playerId)) {
      return;
    }

    setState(() => _busyPlayerIds.add(playerId));

    try {
      final message = await action();
      if (message != null && mounted) {
        _showMessage(message);
      }
      notifyPlayerNetworkChanged(ref);
    } catch (error) {
      if (mounted) {
        _showMessage(error.toString(), isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _busyPlayerIds.remove(playerId));
      }
    }
  }

  Future<String?> _sendPlayRequest(PlayerModel player) async {
    final api = ref.read(apiClientProvider);
    final data = await api
        .post('/padel/players/${player.userId}/network/request', data: {});
    if (data is Map && data['message'] != null) {
      return data['message'].toString();
    }
    return null;
  }

  Future<String?> _respondToRequest(PlayerModel player, String action) async {
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

  void _goToInvitationsTab() {
    _tabController.animateTo(1);
  }

  @override
  Widget build(BuildContext context) {
    final alerts = ref.watch(appAlertsProvider);
    final chatUnreadCount = ref.watch(chatUnreadCountProvider);

    ref.listen<int>(playerNetworkRefreshProvider, (previous, next) {
      if (previous != next) {
        unawaited(_refreshAll());
      }
    });

    return Scaffold(
      backgroundColor: AppColors.dark,
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.people_outline, color: AppColors.primary, size: 22),
            SizedBox(width: 8),
            Text('Jugadores'),
          ],
        ),
        backgroundColor: AppColors.surface,
        actions: [
          IconButton(
            tooltip: 'Chat',
            onPressed: () => context.push('/players/chat'),
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.forum_outlined),
                Positioned(
                  right: -2,
                  top: -2,
                  child: NotificationDot(
                    visible: chatUnreadCount > 0,
                    size: 9,
                  ),
                ),
              ],
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: Colors.white,
          unselectedLabelColor: AppColors.muted,
          tabs: [
            const Tab(text: 'Mi red'),
            Tab(
              child: NotificationLabel(
                label: 'Invitaciones',
                showDot: alerts.hasPlayersBadge,
              ),
            ),
            const Tab(text: 'Mis peticiones'),
            const Tab(text: 'Descubrir'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMyNetworkTab(),
          _buildInvitacionesTab(),
          _buildMisPeticionesTab(),
          _buildDiscoverTab(),
        ],
      ),
    );
  }

  Widget _buildMyNetworkTab() {
    if (_loadingNetwork && _network.isEmpty) {
      return const Center(child: LoadingSpinner());
    }

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      onRefresh: _fetchNetwork,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: [
          if (_network.companions.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  Icon(Icons.people_outline, color: AppColors.muted, size: 42),
                  SizedBox(height: 12),
                  Text(
                    'Todavía no tienes compañeros confirmados.',
                    style: TextStyle(color: AppColors.muted),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Explora jugadores en Descubrir y envía solicitudes.',
                    style: TextStyle(color: AppColors.muted, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            ..._network.companions.map(
              (player) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _PlayerConnectionCard(
                  player: player,
                  onTap: () => context.push('/players/${player.userId}'),
                  footer: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              context.push('/players/${player.userId}'),
                          icon: const Icon(Icons.person_outline, size: 18),
                          label: const Text('Perfil'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => context.push(
                            '/players/chat/direct/${player.userId}',
                          ),
                          icon: const Icon(Icons.forum_outlined, size: 18),
                          label: const Text('Chat'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInvitacionesTab() {
    if (_loadingNetwork && _network.isEmpty) {
      return const Center(child: LoadingSpinner());
    }

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      onRefresh: _fetchNetwork,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: [
          if (_network.incomingRequests.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  Icon(Icons.mark_email_unread_outlined,
                      color: AppColors.muted, size: 42),
                  SizedBox(height: 12),
                  Text(
                    'Sin invitaciones pendientes.',
                    style: TextStyle(color: AppColors.muted),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Cuando otro jugador te mande una solicitud, aparecerá aquí.',
                    style: TextStyle(color: AppColors.muted, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            ..._network.incomingRequests.map(
              (player) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _PlayerConnectionCard(
                  player: player,
                  onTap: () => context.push('/players/${player.userId}'),
                  headline: '${player.displayName} quiere jugar contigo.',
                  timestampLabel: _formatConnectionMoment(
                    player.connectionRequestedAt,
                    prefix: 'Recibida',
                  ),
                  footer: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isBusy(player.userId)
                              ? null
                              : () => _runPlayerAction(
                                    player.userId,
                                    () => _respondToRequest(player, 'rejected'),
                                  ),
                          child: const Text('Rechazar'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isBusy(player.userId)
                              ? null
                              : () => _runPlayerAction(
                                    player.userId,
                                    () => _respondToRequest(player, 'accepted'),
                                  ),
                          child: _isBusy(player.userId)
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Aceptar'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMisPeticionesTab() {
    if (_loadingNetwork && _network.isEmpty) {
      return const Center(child: LoadingSpinner());
    }

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      onRefresh: _fetchNetwork,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: [
          if (_network.outgoingRequests.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  Icon(Icons.send_outlined, color: AppColors.muted, size: 42),
                  SizedBox(height: 12),
                  Text(
                    'No has enviado solicitudes todavía.',
                    style: TextStyle(color: AppColors.muted),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Usa Descubrir para pedir jugar a otros jugadores.',
                    style: TextStyle(color: AppColors.muted, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            ..._network.outgoingRequests.map(
              (player) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _PlayerConnectionCard(
                  player: player,
                  onTap: () => context.push('/players/${player.userId}'),
                  headline: _outgoingHeadline(player),
                  timestampLabel: _outgoingTimestamp(player),
                  footer: _OutgoingFooter(
                    player: player,
                    busy: _isBusy(player.userId),
                    onRetry: player.connectionStatus == 'rejected'
                        ? () => _runPlayerAction(
                              player.userId,
                              () => _sendPlayRequest(player),
                            )
                        : null,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDiscoverTab() {
    final loading = _loadingDiscover && _players.isEmpty;
    final discoverPlayers = _discoverPlayers;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'Buscar por nombre...',
                    prefixIcon:
                        Icon(Icons.search, color: AppColors.muted, size: 20),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(
                  Icons.tune,
                  color: _showFilters ? AppColors.primary : AppColors.muted,
                ),
                onPressed: () => setState(() => _showFilters = !_showFilters),
              ),
            ],
          ),
        ),
        if (_showFilters)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Column(
              children: [
                _NumericLevelDropdown(
                  label: 'Categoría',
                  value: _filterNumericLevel,
                  onChanged: (value) {
                    _setFilterNumericLevel(value);
                    _search();
                  },
                ),
                const SizedBox(height: 8),
                _LevelDropdown(
                  label: 'Sexo',
                  value: _filterGender,
                  items: const [
                    'masculino',
                    'femenino',
                    'otro',
                    'prefiero_no_decirlo',
                  ],
                  labelMap: const {
                    'masculino': 'Masculino',
                    'femenino': 'Femenino',
                    'otro': 'Otro',
                    'prefiero_no_decirlo': 'Prefiero no decirlo',
                  },
                  onChanged: (v) {
                    setState(() => _filterGender = v);
                    _search();
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Switch(
                      value: _filterAvailable,
                      activeThumbColor: AppColors.primary,
                      onChanged: (value) {
                        setState(() => _filterAvailable = value);
                        _search();
                      },
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Solo disponibles',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ],
                ),
              ],
            ),
          ),
        Expanded(
          child: loading
              ? const Center(child: LoadingSpinner())
              : RefreshIndicator(
                  color: AppColors.primary,
                  backgroundColor: AppColors.surface,
                  onRefresh: _search,
                  child: discoverPlayers.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(24, 120, 24, 120),
                          children: const [
                            _EmptyPlayersState(
                              icon: Icons.travel_explore_outlined,
                              message:
                                  'No se han encontrado jugadores con esos filtros.',
                            ),
                          ],
                        )
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                          itemCount: discoverPlayers.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final player = discoverPlayers[index];
                            return _PlayerConnectionCard(
                              player: player,
                              onTap: () =>
                                  context.push('/players/${player.userId}'),
                              footer: _DiscoverFooter(
                                player: player,
                                busy: _isBusy(player.userId),
                                onRequest: () => _runPlayerAction(
                                  player.userId,
                                  () => _sendPlayRequest(player),
                                ),
                                onOpenInvitations: _goToInvitationsTab,
                              ),
                            );
                          },
                        ),
                ),
        ),
      ],
    );
  }

  String _outgoingHeadline(PlayerModel player) {
    switch (player.connectionStatus) {
      case 'accepted':
        return '${player.displayName} ha aceptado tu solicitud.';
      case 'rejected':
        return '${player.displayName} no ha aceptado tu solicitud.';
      case 'outgoing_pending':
      default:
        return 'Solicitud enviada. En cuanto responda, aparecerá aquí.';
    }
  }

  String? _outgoingTimestamp(PlayerModel player) {
    if (player.connectionStatus == 'accepted' ||
        player.connectionStatus == 'rejected') {
      return _formatConnectionMoment(
        player.connectionRespondedAt,
        prefix: 'Respondida',
      );
    }

    return _formatConnectionMoment(
      player.connectionRequestedAt,
      prefix: 'Enviada',
    );
  }

  String? _formatConnectionMoment(String? value, {required String prefix}) {
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
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$prefix el $day/$month a las $hour:$minute';
  }

  List<PlayerModel> get _discoverPlayers {
    final companionIds =
        _network.companions.map((player) => player.userId).toSet();

    return _players.where((player) {
      if (companionIds.contains(player.userId)) {
        return false;
      }

      return player.connectionStatus != 'accepted';
    }).toList(growable: false);
  }
}

class _PlayerConnectionCard extends StatelessWidget {
  final PlayerModel player;
  final VoidCallback onTap;
  final String? headline;
  final String? timestampLabel;
  final Widget? footer;

  const _PlayerConnectionCard({
    required this.player,
    required this.onTap,
    this.headline,
    this.timestampLabel,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final hasPreferenceSummary = player.courtPreferences.isNotEmpty ||
        player.dominantHands.isNotEmpty ||
        player.availabilityPreferences.isNotEmpty ||
        player.matchPreferences.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.vertical(
                top: const Radius.circular(16),
                bottom: Radius.circular(footer == null ? 16 : 0),
              ),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    _PlayerAvatar(player: player),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            player.displayName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              LevelBadge(
                                level: player.level,
                                mainLevel: player.mainLevel,
                                subLevel: player.subLevel,
                              ),
                              if (player.avgRating > 0)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.star,
                                      color: Colors.amber,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      player.avgRating.toStringAsFixed(1),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                          if (hasPreferenceSummary) ...[
                            const SizedBox(height: 8),
                            PreferenceSummaryChips(
                              courtPreferences: player.courtPreferences,
                              dominantHands: player.dominantHands,
                              availabilityPreferences:
                                  player.availabilityPreferences,
                              matchPreferences: player.matchPreferences,
                            ),
                          ],
                        ],
                      ),
                    ),
                    _AvailabilityPill(isAvailable: player.isAvailable),
                  ],
                ),
              ),
            ),
          ),
          if (headline != null || timestampLabel != null || footer != null) ...[
            const Divider(height: 1, color: AppColors.border),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (headline != null)
                    Text(
                      headline!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  if (timestampLabel != null) ...[
                    if (headline != null) const SizedBox(height: 4),
                    Text(
                      timestampLabel!,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  if (footer != null) ...[
                    if (headline != null || timestampLabel != null)
                      const SizedBox(height: 12),
                    footer!,
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PlayerAvatar extends StatelessWidget {
  final PlayerModel player;

  const _PlayerAvatar({required this.player});

  @override
  Widget build(BuildContext context) {
    return UserAvatar(
      displayName: player.displayName,
      avatarUrl: player.avatarUrl,
      size: 46,
      fontSize: 18,
      backgroundColor: AppColors.surface,
      borderColor: AppColors.border,
    );
  }
}

class _AvailabilityPill extends StatelessWidget {
  final bool isAvailable;

  const _AvailabilityPill({required this.isAvailable});

  @override
  Widget build(BuildContext context) {
    final color = isAvailable ? AppColors.success : AppColors.muted;
    final label = isAvailable ? 'Disponible' : 'No disponible';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _OutgoingFooter extends StatelessWidget {
  final PlayerModel player;
  final bool busy;
  final VoidCallback? onRetry;

  const _OutgoingFooter({
    required this.player,
    required this.busy,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final status = player.connectionStatus;
    if (status == 'accepted') {
      return const Align(
        alignment: Alignment.centerLeft,
        child: PadelBadge(
          label: 'Aceptada',
          variant: PadelBadgeVariant.success,
        ),
      );
    }

    if (status == 'rejected') {
      return Row(
        children: [
          const PadelBadge(
            label: 'No aceptada',
            variant: PadelBadgeVariant.warning,
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: busy ? null : onRetry,
            child: busy
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Jugamos?'),
          ),
        ],
      );
    }

    return const Align(
      alignment: Alignment.centerLeft,
      child: PadelBadge(
        label: 'Pendiente',
        variant: PadelBadgeVariant.warning,
      ),
    );
  }
}

class _DiscoverFooter extends StatelessWidget {
  final PlayerModel player;
  final bool busy;
  final VoidCallback onRequest;
  final VoidCallback onOpenInvitations;

  const _DiscoverFooter({
    required this.player,
    required this.busy,
    required this.onRequest,
    required this.onOpenInvitations,
  });

  @override
  Widget build(BuildContext context) {
    switch (player.connectionStatus) {
      case 'accepted':
        return const Align(
          alignment: Alignment.centerLeft,
          child: PadelBadge(
            label: 'Ya forma parte de tu red',
            variant: PadelBadgeVariant.success,
          ),
        );
      case 'outgoing_pending':
        return const Align(
          alignment: Alignment.centerLeft,
          child: PadelBadge(
            label: 'Solicitud enviada',
            variant: PadelBadgeVariant.warning,
          ),
        );
      case 'incoming_pending':
        return Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: onOpenInvitations,
                child: const Text('Responder en Invitaciones'),
              ),
            ),
          ],
        );
      case 'rejected':
      default:
        return Row(
          children: [
            if (player.connectionStatus == 'rejected')
              const Padding(
                padding: EdgeInsets.only(right: 12),
                child: PadelBadge(
                  label: 'No aceptada',
                  variant: PadelBadgeVariant.warning,
                ),
              ),
            const Spacer(),
            ElevatedButton(
              onPressed: busy ? null : onRequest,
              child: busy
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Jugamos?'),
            ),
          ],
        );
    }
  }
}

class _EmptyPlayersState extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyPlayersState({
    required this.icon,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: AppColors.border, size: 44),
        const SizedBox(height: 10),
        Text(
          message,
          style: const TextStyle(color: AppColors.muted),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _NumericLevelDropdown extends StatelessWidget {
  final String label;
  final int? value;
  final ValueChanged<int?> onChanged;

  const _NumericLevelDropdown({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int?>(
      key: ValueKey<int?>(value),
      initialValue: value,
      dropdownColor: AppColors.surface2,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      hint: const Text(
        'Todas',
        style: TextStyle(color: AppColors.muted),
      ),
      items: <DropdownMenuItem<int?>>[
        const DropdownMenuItem<int?>(
          value: null,
          child: Text(
            'Todas',
            style: TextStyle(color: AppColors.muted),
          ),
        ),
        ...PlayerPreferenceCatalog.levelCategoryOptions.map(
          (option) => DropdownMenuItem<int?>(
            value: option.numericLevel,
            child: Text(
              option.label,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ),
      ],
      onChanged: onChanged,
    );
  }
}

class _LevelDropdown extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> items;
  final Map<String, String> labelMap;
  final ValueChanged<String?> onChanged;

  const _LevelDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.labelMap,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String?>(
      key: ValueKey<String?>(value),
      initialValue: value,
      dropdownColor: AppColors.surface2,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      hint: const Text(
        'Todos',
        style: TextStyle(color: AppColors.muted),
      ),
      items: <DropdownMenuItem<String?>>[
        const DropdownMenuItem<String?>(
          value: null,
          child: Text(
            'Todos',
            style: TextStyle(color: AppColors.muted),
          ),
        ),
        ...items.map(
          (item) => DropdownMenuItem<String?>(
            value: item,
            child: Text(
              labelMap[item] ?? item,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ),
      ],
      onChanged: onChanged,
    );
  }
}
