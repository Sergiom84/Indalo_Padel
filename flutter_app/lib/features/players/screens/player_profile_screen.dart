import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/api/api_client.dart';
import '../../../shared/widgets/adaptive_pickers.dart';
import '../../../shared/utils/player_preferences.dart';
import '../../../shared/widgets/loading_spinner.dart';
import '../../../shared/widgets/padel_badge.dart';
import '../../../shared/widgets/preference_checkbox_group.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/player_model.dart';

class PlayerProfileScreen extends ConsumerStatefulWidget {
  final String playerId;
  const PlayerProfileScreen({super.key, required this.playerId});

  @override
  ConsumerState<PlayerProfileScreen> createState() =>
      _PlayerProfileScreenState();
}

class _PlayerProfileScreenState extends ConsumerState<PlayerProfileScreen> {
  bool _loading = true;
  PlayerModel? _player;
  List<RatingModel> _ratings = [];
  bool _networkBusy = false;

  // Edit form
  bool _editOpen = false;
  final _editNameCtrl = TextEditingController();
  final _editBioCtrl = TextEditingController();
  final _editPhoneCtrl = TextEditingController();
  List<String> _editCourtPreferences = const [];
  List<String> _editDominantHands = const [];
  List<String> _editAvailabilityPreferences = const [];
  List<String> _editMatchPreferences = const [];
  String? _editGender;
  DateTime? _editBirthDate;
  bool _editAvailable = true;

  // Rate form
  bool _rateOpen = false;
  int _rateValue = 0;
  final _rateCommentCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchPlayer();
  }

  @override
  void dispose() {
    _editNameCtrl.dispose();
    _editBioCtrl.dispose();
    _editPhoneCtrl.dispose();
    _rateCommentCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchPlayer() async {
    setState(() => _loading = true);
    try {
      final api = ref.read(apiClientProvider);
      final authUser = ref.read(authProvider).user;
      final isOwnProfile = authUser?.id.toString() == widget.playerId;
      final data = isOwnProfile
          ? await api.get('/padel/players/profile')
          : await api.get('/padel/players/${widget.playerId}');
      final ratingsData = isOwnProfile
          ? await _fetchRatings(api)
          : (data['ratings'] as List<dynamic>? ?? []);
      if (mounted) {
        final playerData = isOwnProfile
            ? (data['profile'] as Map<String, dynamic>? ?? {})
            : (data['player'] as Map<String, dynamic>? ?? {});
        final player = PlayerModel.fromJson(playerData);
        setState(() {
          _player = player;
          _ratings = ratingsData
              .map((r) => RatingModel.fromJson(r as Map<String, dynamic>))
              .toList();
          _editNameCtrl.text = player.displayName;
          _editBioCtrl.text = player.bio ?? '';
          _editCourtPreferences = [...player.courtPreferences];
          _editDominantHands = [...player.dominantHands];
          _editAvailabilityPreferences = [...player.availabilityPreferences];
          _editMatchPreferences = [...player.matchPreferences];
          _editGender = player.gender;
          _editBirthDate = _parsePlayerBirthDate(player.birthDate);
          _editPhoneCtrl.text = player.phone ?? '';
          _editAvailable = player.isAvailable;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<List<dynamic>> _fetchRatings(ApiClient api) async {
    try {
      final publicData = await api.get('/padel/players/${widget.playerId}');
      return publicData['ratings'] as List<dynamic>? ?? [];
    } catch (_) {
      return const [];
    }
  }

  Future<void> _updateProfile() async {
    if (_editGender == null || _editBirthDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El género y la fecha de nacimiento son obligatorios'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    try {
      final api = ref.read(apiClientProvider);
      await api.put('/padel/players/profile', data: {
        'display_name': _editNameCtrl.text.trim(),
        'bio': _editBioCtrl.text.trim(),
        'is_available': _editAvailable,
        'gender': _editGender,
        'birth_date': DateFormat('yyyy-MM-dd').format(_editBirthDate!),
        'phone': _editPhoneCtrl.text.trim(),
        'court_preferences': _editCourtPreferences,
        'dominant_hands': _editDominantHands,
        'availability_preferences': _editAvailabilityPreferences,
        'match_preferences': _editMatchPreferences,
      });
      setState(() {
        _player = PlayerModel(
          userId: _player!.userId,
          displayName: _editNameCtrl.text.trim(),
          email: _player!.email,
          level: _player!.level,
          courtPreferences: _editCourtPreferences,
          dominantHands: _editDominantHands,
          availabilityPreferences: _editAvailabilityPreferences,
          matchPreferences: _editMatchPreferences,
          gender: _editGender,
          birthDate: DateFormat('yyyy-MM-dd').format(_editBirthDate!),
          phone: _editPhoneCtrl.text.trim().isEmpty
              ? null
              : _editPhoneCtrl.text.trim(),
          isAvailable: _editAvailable,
          avgRating: _player!.avgRating,
          totalRatings: _player!.totalRatings,
          matchesPlayed: _player!.matchesPlayed,
          matchesWon: _player!.matchesWon,
          bio: _editBioCtrl.text.trim().isEmpty
              ? null
              : _editBioCtrl.text.trim(),
          avatarUrl: _player!.avatarUrl,
          isFavorited: _player!.isFavorited,
          connectionId: _player!.connectionId,
          connectionStatus: _player!.connectionStatus,
          connectionRequestedByMe: _player!.connectionRequestedByMe,
          connectionRequestedAt: _player!.connectionRequestedAt,
          connectionRespondedAt: _player!.connectionRespondedAt,
        );
        _editOpen = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(e.toString()), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  Future<void> _pickEditBirthDate() async {
    final now = DateTime.now();
    final picked = await showAdaptiveAppDatePicker(
      context: context,
      initialDate:
          _editBirthDate ?? DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(1900, 1, 1),
      lastDate: now,
    );
    if (picked != null && mounted) {
      setState(() => _editBirthDate = picked);
    }
  }

  Future<void> _ratePlayer() async {
    if (_rateValue == 0) return;
    try {
      final api = ref.read(apiClientProvider);
      await api.post('/padel/players/${widget.playerId}/rate', data: {
        'rating': _rateValue,
        if (_rateCommentCtrl.text.trim().isNotEmpty)
          'comment': _rateCommentCtrl.text.trim(),
      });
      setState(() {
        _rateOpen = false;
        _rateValue = 0;
        _rateCommentCtrl.clear();
      });
      await _fetchPlayer();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(e.toString()), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  Future<void> _sendPlayRequest() async {
    try {
      setState(() => _networkBusy = true);
      final api = ref.read(apiClientProvider);
      final data = await api
          .post('/padel/players/${widget.playerId}/network/request', data: {});
      if (mounted && data is Map && data['message'] != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'].toString())),
        );
      }
      await _fetchPlayer();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(e.toString()), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _networkBusy = false);
      }
    }
  }

  Future<void> _respondToPlayRequest(String action) async {
    try {
      setState(() => _networkBusy = true);
      final api = ref.read(apiClientProvider);
      final data = await api.post(
        '/padel/players/${widget.playerId}/network/respond',
        data: {'action': action},
      );
      if (mounted && data is Map && data['message'] != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'].toString())),
        );
      }
      await _fetchPlayer();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(e.toString()), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _networkBusy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: AppColors.dark,
        appBar: AppBar(backgroundColor: AppColors.surface),
        body: const Center(child: LoadingSpinner()),
      );
    }

    if (_player == null) {
      return Scaffold(
        backgroundColor: AppColors.dark,
        appBar: AppBar(backgroundColor: AppColors.surface),
        body: const Center(
          child: Text('Jugador no encontrado',
              style: TextStyle(color: AppColors.muted)),
        ),
      );
    }

    final player = _player!;
    final user = ref.watch(authProvider).user;
    final isOwnProfile = user?.id == player.userId;

    return Scaffold(
      backgroundColor: AppColors.dark,
      appBar: AppBar(
        title: Text(player.displayName),
        backgroundColor: AppColors.surface,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Profile header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Avatar
                      UserAvatar(
                        displayName: player.displayName,
                        avatarUrl: player.avatarUrl,
                        size: 64,
                        fontSize: 26,
                        backgroundColor: AppColors.surface2,
                        borderColor: AppColors.border,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              player.displayName,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 20),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                LevelBadge(level: player.level),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: player.isAvailable
                                        ? AppColors.success
                                        : AppColors.muted,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  player.isAvailable
                                      ? 'Disponible'
                                      : 'No disponible',
                                  style: TextStyle(
                                    color: player.isAvailable
                                        ? AppColors.success
                                        : AppColors.muted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Action buttons
                      Column(
                        children: [
                          if (isOwnProfile)
                            IconButton(
                              icon: const Icon(Icons.edit_outlined,
                                  color: AppColors.primary),
                              onPressed: () => setState(() => _editOpen = true),
                            )
                          else ...[
                            IconButton(
                              icon: const Icon(Icons.star_outline,
                                  color: AppColors.primary),
                              onPressed: () => setState(() => _rateOpen = true),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                  if (player.bio != null && player.bio!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(player.bio!,
                          style: const TextStyle(
                              color: AppColors.muted, fontSize: 14)),
                    ),
                  ],
                  if (_PreferenceSectionData.fromPlayer(player).isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _PlayerPreferenceSummary(player: player),
                  ],
                  if (_playerMetaItems(player).isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _playerMetaItems(player)
                          .map(
                            (item) => PadelBadge(
                              label: item,
                              variant: PadelBadgeVariant.outline,
                            ),
                          )
                          .toList(),
                    ),
                  ],
                  if (!isOwnProfile) ...[
                    const SizedBox(height: 14),
                    _ConnectionActionPanel(
                      player: player,
                      busy: _networkBusy,
                      onRequest: _sendPlayRequest,
                      onAccept: () => _respondToPlayRequest('accepted'),
                      onReject: () => _respondToPlayRequest('rejected'),
                    ),
                  ],
                  const SizedBox(height: 16),

                  // Stats
                  Row(
                    children: [
                      Expanded(
                        child: _StatBox(
                          icon: Icons.emoji_events,
                          value: '${player.matchesPlayed}',
                          label: 'Partidos\njugados',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatBox(
                          icon: Icons.military_tech,
                          value: '${player.matchesWon}',
                          label: 'Partidos\nganados',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatBox(
                          icon: Icons.star,
                          value: player.avgRating > 0
                              ? player.avgRating.toStringAsFixed(1)
                              : '—',
                          label: 'Valoración\nmedia',
                          iconColor: Colors.amber,
                          below: player.avgRating > 0
                              ? _StarRow(value: player.avgRating)
                              : null,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Ratings
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Valoraciones recientes',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  if (_ratings.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text('Aún no tiene valoraciones',
                            style: TextStyle(color: AppColors.muted)),
                      ),
                    )
                  else
                    ...(_ratings.map((r) => _RatingRow(rating: r))),
                ],
              ),
            ),
          ],
        ),
      ),

      // Edit profile bottom sheet
      bottomSheet: _editOpen
          ? _EditProfileSheet(
              nameCtrl: _editNameCtrl,
              bioCtrl: _editBioCtrl,
              courtPreferences: _editCourtPreferences,
              dominantHands: _editDominantHands,
              availabilityPreferences: _editAvailabilityPreferences,
              matchPreferences: _editMatchPreferences,
              gender: _editGender,
              birthDate: _editBirthDate,
              phoneCtrl: _editPhoneCtrl,
              available: _editAvailable,
              onCourtPreferencesChanged: (values) =>
                  setState(() => _editCourtPreferences = values),
              onDominantHandsChanged: (values) =>
                  setState(() => _editDominantHands = values),
              onAvailabilityPreferencesChanged: (values) =>
                  setState(() => _editAvailabilityPreferences = values),
              onMatchPreferencesChanged: (values) =>
                  setState(() => _editMatchPreferences = values),
              onGenderChanged: (value) => setState(() => _editGender = value),
              onBirthDateTap: _pickEditBirthDate,
              onAvailableChanged: (v) => setState(() => _editAvailable = v),
              onSave: _updateProfile,
              onCancel: () => setState(() => _editOpen = false),
            )
          : _rateOpen
              ? _RatePlayerSheet(
                  rateValue: _rateValue,
                  commentCtrl: _rateCommentCtrl,
                  onRateChanged: (v) => setState(() => _rateValue = v),
                  onSubmit: _ratePlayer,
                  onCancel: () => setState(() => _rateOpen = false),
                )
              : null,
    );
  }
}

DateTime? _parsePlayerBirthDate(String? value) {
  if (value == null || value.trim().isEmpty) {
    return null;
  }

  try {
    return DateTime.parse(value);
  } catch (_) {
    return null;
  }
}

List<String> _playerMetaItems(PlayerModel player) {
  final items = <String>[];
  final genderLabel = PlayerPreferenceCatalog.labelForGender(player.gender);
  if (genderLabel.isNotEmpty) {
    items.add(genderLabel);
  }
  final birthDate = _parsePlayerBirthDate(player.birthDate);
  if (birthDate != null) {
    items.add(DateFormat('dd/MM/yyyy').format(birthDate));
  }
  if (player.phone != null && player.phone!.trim().isNotEmpty) {
    items.add(player.phone!.trim());
  }
  return items;
}

class _PreferenceSectionData {
  final String title;
  final List<String> labels;

  const _PreferenceSectionData({
    required this.title,
    required this.labels,
  });

  static List<_PreferenceSectionData> fromPlayer(PlayerModel player) {
    final valuesByField = <String, List<String>>{
      'court_preferences': player.courtPreferences,
      'dominant_hands': player.dominantHands,
      'availability_preferences': player.availabilityPreferences,
      'match_preferences': player.matchPreferences,
    };

    return PlayerPreferenceCatalog.sections
        .map(
          (section) => _PreferenceSectionData(
            title: section.title,
            labels: PlayerPreferenceCatalog.labelsForValues(
              valuesByField[section.field] ?? const [],
            ),
          ),
        )
        .where((section) => section.labels.isNotEmpty)
        .toList(growable: false);
  }
}

class _PlayerPreferenceSummary extends StatelessWidget {
  final PlayerModel player;

  const _PlayerPreferenceSummary({required this.player});

  @override
  Widget build(BuildContext context) {
    final sections = _PreferenceSectionData.fromPlayer(player);
    if (sections.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Preferencias de juego',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        for (var index = 0; index < sections.length; index++) ...[
          Text(
            sections[index].title,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final label in sections[index].labels)
                PadelBadge(
                  label: label,
                  variant: PadelBadgeVariant.outline,
                ),
            ],
          ),
          if (index < sections.length - 1) const SizedBox(height: 14),
        ],
      ],
    );
  }
}

class _ConnectionActionPanel extends StatelessWidget {
  final PlayerModel player;
  final bool busy;
  final VoidCallback onRequest;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _ConnectionActionPanel({
    required this.player,
    required this.busy,
    required this.onRequest,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    switch (player.connectionStatus) {
      case 'accepted':
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
            border:
                Border.all(color: AppColors.success.withValues(alpha: 0.25)),
          ),
          child: const Row(
            children: [
              Icon(Icons.people_alt_outlined, color: AppColors.success),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Ya forma parte de tu red',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        );
      case 'incoming_pending':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Este jugador te ha enviado una solicitud para jugar.',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
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
        );
      case 'outgoing_pending':
        return SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: null,
            icon: const Icon(Icons.schedule_outlined),
            label: const Text('Solicitud enviada'),
          ),
        );
      case 'rejected':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'No aceptó tu última solicitud.',
              style: TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: busy ? null : onRequest,
                icon: const Icon(Icons.person_add_alt_1),
                label: busy
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Jugamos?'),
              ),
            ),
          ],
        );
      default:
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: busy ? null : onRequest,
            icon: const Icon(Icons.person_add_alt_1),
            label: busy
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Jugamos?'),
          ),
        );
    }
  }
}

class _StatBox extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color iconColor;
  final Widget? below;

  const _StatBox({
    required this.icon,
    required this.value,
    required this.label,
    this.iconColor = AppColors.primary,
    this.below,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(height: 6),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 20)),
          if (below != null) below!,
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(color: AppColors.muted, fontSize: 10),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _StarRow extends StatelessWidget {
  final double value;
  const _StarRow({required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (i) {
        return Icon(
          Icons.star,
          size: 12,
          color: i < value.round() ? Colors.amber : AppColors.muted,
        );
      }),
    );
  }
}

class _RatingRow extends StatelessWidget {
  final RatingModel rating;
  const _RatingRow({required this.rating});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                    color: AppColors.surface2, shape: BoxShape.circle),
                child: const Icon(Icons.person_outline,
                    color: AppColors.muted, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(rating.raterName,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600)),
              ),
              Row(
                children: List.generate(
                    5,
                    (i) => Icon(
                          Icons.star,
                          size: 14,
                          color: i < rating.rating.round()
                              ? Colors.amber
                              : AppColors.muted,
                        )),
              ),
            ],
          ),
          if (rating.comment != null && rating.comment!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 40),
              child: Text(rating.comment!,
                  style: const TextStyle(color: AppColors.muted, fontSize: 13)),
            ),
          ],
          const Divider(color: AppColors.border, height: 16),
        ],
      ),
    );
  }
}

class _EditProfileSheet extends StatelessWidget {
  final TextEditingController nameCtrl;
  final TextEditingController bioCtrl;
  final TextEditingController phoneCtrl;
  final List<String> courtPreferences;
  final List<String> dominantHands;
  final List<String> availabilityPreferences;
  final List<String> matchPreferences;
  final String? gender;
  final DateTime? birthDate;
  final bool available;
  final ValueChanged<List<String>> onCourtPreferencesChanged;
  final ValueChanged<List<String>> onDominantHandsChanged;
  final ValueChanged<List<String>> onAvailabilityPreferencesChanged;
  final ValueChanged<List<String>> onMatchPreferencesChanged;
  final ValueChanged<String?> onGenderChanged;
  final VoidCallback onBirthDateTap;
  final void Function(bool) onAvailableChanged;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  const _EditProfileSheet({
    required this.nameCtrl,
    required this.bioCtrl,
    required this.phoneCtrl,
    required this.courtPreferences,
    required this.dominantHands,
    required this.availabilityPreferences,
    required this.matchPreferences,
    required this.gender,
    required this.birthDate,
    required this.available,
    required this.onCourtPreferencesChanged,
    required this.onDominantHandsChanged,
    required this.onAvailabilityPreferencesChanged,
    required this.onMatchPreferencesChanged,
    required this.onGenderChanged,
    required this.onBirthDateTap,
    required this.onAvailableChanged,
    required this.onSave,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Editar perfil',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 18)),
            const SizedBox(height: 16),
            TextField(
              controller: nameCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Nombre'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: gender,
              dropdownColor: AppColors.surface2,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Género'),
              hint: const Text(
                'Selecciona tu género',
                style: TextStyle(color: AppColors.muted),
              ),
              items: PlayerPreferenceCatalog.genderOptions
                  .map(
                    (option) => DropdownMenuItem(
                      value: option.value,
                      child: Text(option.label),
                    ),
                  )
                  .toList(),
              onChanged: onGenderChanged,
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: onBirthDateTap,
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Fecha de nacimiento',
                  suffixIcon: Icon(
                    Icons.calendar_today_outlined,
                    color: AppColors.muted,
                    size: 20,
                  ),
                ),
                child: Text(
                  birthDate == null
                      ? 'Selecciona tu fecha de nacimiento'
                      : DateFormat('dd/MM/yyyy').format(birthDate!),
                  style: TextStyle(
                    color: birthDate == null ? AppColors.muted : Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Teléfono (opcional)',
              ),
            ),
            const SizedBox(height: 12),
            PreferenceCheckboxGroup(
              title: 'Posición en pista',
              options: PlayerPreferenceCatalog.courtPreferences,
              selectedValues: courtPreferences,
              onChanged: onCourtPreferencesChanged,
            ),
            const SizedBox(height: 12),
            PreferenceCheckboxGroup(
              title: 'Preferencia de la mano',
              options: PlayerPreferenceCatalog.dominantHands,
              selectedValues: dominantHands,
              onChanged: onDominantHandsChanged,
            ),
            const SizedBox(height: 12),
            PreferenceCheckboxGroup(
              title: 'Disponibilidad horaria',
              options: PlayerPreferenceCatalog.availabilityPreferences,
              selectedValues: availabilityPreferences,
              onChanged: onAvailabilityPreferencesChanged,
            ),
            const SizedBox(height: 12),
            PreferenceCheckboxGroup(
              title: 'Modalidad de juego',
              options: PlayerPreferenceCatalog.matchPreferences,
              selectedValues: matchPreferences,
              onChanged: onMatchPreferencesChanged,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: bioCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Bio'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Switch(
                  value: available,
                  activeThumbColor: AppColors.primary,
                  onChanged: onAvailableChanged,
                ),
                const SizedBox(width: 8),
                const Text('Disponible para jugar',
                    style: TextStyle(color: Colors.white)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                    child: OutlinedButton(
                        onPressed: onCancel, child: const Text('Cancelar'))),
                const SizedBox(width: 12),
                Expanded(
                    child: ElevatedButton(
                        onPressed: onSave, child: const Text('Guardar'))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RatePlayerSheet extends StatelessWidget {
  final int rateValue;
  final TextEditingController commentCtrl;
  final void Function(int) onRateChanged;
  final VoidCallback onSubmit;
  final VoidCallback onCancel;

  const _RatePlayerSheet({
    required this.rateValue,
    required this.commentCtrl,
    required this.onRateChanged,
    required this.onSubmit,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Valorar jugador',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 18)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              return GestureDetector(
                onTap: () => onRateChanged(i + 1),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.star,
                    size: 36,
                    color: i < rateValue ? Colors.amber : AppColors.muted,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: commentCtrl,
            style: const TextStyle(color: Colors.white),
            decoration:
                const InputDecoration(hintText: 'Escribe un comentario...'),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                  child: OutlinedButton(
                      onPressed: onCancel, child: const Text('Cancelar'))),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: rateValue > 0 ? onSubmit : null,
                  child: const Text('Enviar valoración'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
