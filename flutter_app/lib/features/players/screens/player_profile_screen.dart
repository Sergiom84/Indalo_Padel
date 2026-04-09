import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/api/api_client.dart';
import '../../../shared/widgets/loading_spinner.dart';
import '../../../shared/widgets/padel_badge.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/player_model.dart';

class PlayerProfileScreen extends ConsumerStatefulWidget {
  final String playerId;
  const PlayerProfileScreen({super.key, required this.playerId});

  @override
  ConsumerState<PlayerProfileScreen> createState() => _PlayerProfileScreenState();
}

class _PlayerProfileScreenState extends ConsumerState<PlayerProfileScreen> {
  bool _loading = true;
  PlayerModel? _player;
  List<RatingModel> _ratings = [];
  bool _isFavorited = false;

  // Edit form
  bool _editOpen = false;
  final _editNameCtrl = TextEditingController();
  final _editBioCtrl = TextEditingController();
  String _editSide = '';
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
    _rateCommentCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchPlayer() async {
    setState(() => _loading = true);
    try {
      final api = ref.read(apiClientProvider);
      final data = await api.get('/padel/players/${widget.playerId}');
      if (mounted) {
        final playerData = data['player'] as Map<String, dynamic>? ?? {};
        final ratingsData = data['ratings'] as List<dynamic>? ?? [];
        final player = PlayerModel.fromJson(playerData);
        setState(() {
          _player = player;
          _ratings = ratingsData
              .map((r) => RatingModel.fromJson(r as Map<String, dynamic>))
              .toList();
          _isFavorited = player.isFavorited;
          _editNameCtrl.text = player.displayName;
          _editBioCtrl.text = player.bio ?? '';
          _editSide = player.preferredSide ?? '';
          _editAvailable = player.isAvailable;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _updateProfile() async {
    try {
      final api = ref.read(apiClientProvider);
      await api.put('/padel/players/profile', data: {
        'display_name': _editNameCtrl.text.trim(),
        'preferred_side': _editSide,
        'bio': _editBioCtrl.text.trim(),
        'is_available': _editAvailable,
      });
      setState(() {
        _player = PlayerModel(
          userId: _player!.userId,
          displayName: _editNameCtrl.text.trim(),
          level: _player!.level,
          preferredSide: _editSide.isEmpty ? null : _editSide,
          isAvailable: _editAvailable,
          avgRating: _player!.avgRating,
          totalRatings: _player!.totalRatings,
          matchesPlayed: _player!.matchesPlayed,
          matchesWon: _player!.matchesWon,
          bio: _editBioCtrl.text.trim().isEmpty ? null : _editBioCtrl.text.trim(),
          isFavorited: _player!.isFavorited,
        );
        _editOpen = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  Future<void> _ratePlayer() async {
    if (_rateValue == 0) return;
    try {
      final api = ref.read(apiClientProvider);
      await api.post('/padel/players/${widget.playerId}/rate', data: {
        'rating': _rateValue,
        if (_rateCommentCtrl.text.trim().isNotEmpty) 'comment': _rateCommentCtrl.text.trim(),
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
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  Future<void> _toggleFavorite() async {
    try {
      final api = ref.read(apiClientProvider);
      await api.post('/padel/players/${widget.playerId}/favorite', data: {});
      setState(() => _isFavorited = !_isFavorited);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger),
        );
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
          child: Text('Jugador no encontrado', style: TextStyle(color: AppColors.muted)),
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
                      Container(
                        width: 64,
                        height: 64,
                        decoration: const BoxDecoration(
                          color: AppColors.surface2,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            player.displayName.isNotEmpty ? player.displayName[0].toUpperCase() : '?',
                            style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 28),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              player.displayName,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 20),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                LevelBadge(level: player.level),
                                if (player.preferredSide != null) ...[
                                  const SizedBox(width: 6),
                                  PadelBadge(label: player.preferredSide!, variant: PadelBadgeVariant.outline),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: player.isAvailable ? AppColors.success : AppColors.muted,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  player.isAvailable ? 'Disponible' : 'No disponible',
                                  style: TextStyle(
                                    color: player.isAvailable ? AppColors.success : AppColors.muted,
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
                              icon: const Icon(Icons.edit_outlined, color: AppColors.primary),
                              onPressed: () => setState(() => _editOpen = true),
                            )
                          else ...[
                            IconButton(
                              icon: const Icon(Icons.star_outline, color: AppColors.primary),
                              onPressed: () => setState(() => _rateOpen = true),
                            ),
                            IconButton(
                              icon: Icon(
                                _isFavorited ? Icons.favorite : Icons.favorite_outline,
                                color: _isFavorited ? Colors.red : AppColors.muted,
                              ),
                              onPressed: _toggleFavorite,
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
                      child: Text(player.bio!, style: const TextStyle(color: AppColors.muted, fontSize: 14)),
                    ),
                  ],
                  if (!isOwnProfile) ...[
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: null,
                        icon: const Icon(Icons.person_add_alt_1),
                        label: const Text('Invitar jugador (Próximamente)'),
                      ),
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
                          value: player.avgRating > 0 ? player.avgRating.toStringAsFixed(1) : '—',
                          label: 'Valoración\nmedia',
                          iconColor: Colors.amber,
                          below: player.avgRating > 0 ? _StarRow(value: player.avgRating) : null,
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
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  if (_ratings.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text('Aún no tiene valoraciones', style: TextStyle(color: AppColors.muted)),
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
              side: _editSide,
              available: _editAvailable,
              onSideChanged: (v) => setState(() => _editSide = v),
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
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20)),
          if (below != null) below!,
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 10), textAlign: TextAlign.center),
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
                decoration: const BoxDecoration(color: AppColors.surface2, shape: BoxShape.circle),
                child: const Icon(Icons.person_outline, color: AppColors.muted, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(rating.raterName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              ),
              Row(
                children: List.generate(5, (i) => Icon(
                  Icons.star,
                  size: 14,
                  color: i < rating.rating.round() ? Colors.amber : AppColors.muted,
                )),
              ),
            ],
          ),
          if (rating.comment != null && rating.comment!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 40),
              child: Text(rating.comment!, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
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
  final String side;
  final bool available;
  final void Function(String) onSideChanged;
  final void Function(bool) onAvailableChanged;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  const _EditProfileSheet({
    required this.nameCtrl,
    required this.bioCtrl,
    required this.side,
    required this.available,
    required this.onSideChanged,
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
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Editar perfil', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18)),
            const SizedBox(height: 16),
            TextField(
              controller: nameCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Nombre'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: side.isEmpty ? null : side,
              dropdownColor: AppColors.surface2,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Lado preferido'),
              hint: const Text('Sin preferencia', style: TextStyle(color: AppColors.muted)),
              items: const [
                DropdownMenuItem(value: null, child: Text('Sin preferencia', style: TextStyle(color: AppColors.muted))),
                DropdownMenuItem(value: 'drive', child: Text('Drive')),
                DropdownMenuItem(value: 'reves', child: Text('Revés')),
                DropdownMenuItem(value: 'ambos', child: Text('Ambos')),
              ],
              onChanged: (v) => onSideChanged(v ?? ''),
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
                const Text('Disponible para jugar', style: TextStyle(color: Colors.white)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: OutlinedButton(onPressed: onCancel, child: const Text('Cancelar'))),
                const SizedBox(width: 12),
                Expanded(child: ElevatedButton(onPressed: onSave, child: const Text('Guardar'))),
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
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Valorar jugador', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18)),
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
            decoration: const InputDecoration(hintText: 'Escribe un comentario...'),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: OutlinedButton(onPressed: onCancel, child: const Text('Cancelar'))),
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
