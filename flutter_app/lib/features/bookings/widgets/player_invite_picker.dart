import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/loading_spinner.dart';
import '../../../shared/widgets/padel_badge.dart';
import '../../players/models/player_model.dart';

Future<List<PlayerModel>?> showPlayerInvitePicker({
  required BuildContext context,
  required List<PlayerModel> selectedPlayers,
}) {
  return showModalBottomSheet<List<PlayerModel>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _PlayerInvitePickerSheet(initialSelection: selectedPlayers),
  );
}

class _PlayerInvitePickerSheet extends ConsumerStatefulWidget {
  final List<PlayerModel> initialSelection;

  const _PlayerInvitePickerSheet({required this.initialSelection});

  @override
  ConsumerState<_PlayerInvitePickerSheet> createState() =>
      _PlayerInvitePickerSheetState();
}

class _PlayerInvitePickerSheetState
    extends ConsumerState<_PlayerInvitePickerSheet> {
  final _searchCtrl = TextEditingController();
  final _selected = <int, PlayerModel>{};
  Timer? _debounce;
  bool _loading = false;
  List<PlayerModel> _players = [];

  @override
  void initState() {
    super.initState();
    for (final player in widget.initialSelection) {
      _selected[player.userId] = player;
    }
    _searchCtrl.addListener(_onSearchChanged);
    _search();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _search);
  }

  Future<void> _search() async {
    setState(() => _loading = true);
    try {
      final api = ref.read(apiClientProvider);
      final query = _searchCtrl.text.trim();
      final params = <String, dynamic>{};
      if (query.isNotEmpty) {
        params['name'] = query;
      }

      final queryString = params.entries
          .map((entry) =>
              '${entry.key}=${Uri.encodeComponent(entry.value.toString())}')
          .join('&');
      final response = await api.get(
          '/padel/players/search${queryString.isNotEmpty ? '?$queryString' : ''}');
      final rawList = response is Map ? (response['players'] ?? []) : response;
      final players = (rawList as List)
          .whereType<Map>()
          .map((player) =>
              PlayerModel.fromJson(Map<String, dynamic>.from(player)))
          .toList();

      if (!mounted) {
        return;
      }
      setState(() {
        _players = players;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _loading = false);
    }
  }

  void _toggle(PlayerModel player) {
    setState(() {
      if (_selected.containsKey(player.userId)) {
        _selected.remove(player.userId);
      } else {
        _selected[player.userId] = player;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.88,
          minChildSize: 0.55,
          maxChildSize: 0.95,
          builder: (context, controller) {
            return Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Invitar jugadores',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context)
                            .pop(_selected.values.toList()),
                        child: Text('Hecho (${_selected.length})'),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _searchCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Buscar jugadores de la app',
                      prefixIcon:
                          Icon(Icons.search, color: AppColors.muted, size: 20),
                    ),
                  ),
                ),
                if (_selected.isNotEmpty)
                  SizedBox(
                    height: 52,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      itemCount: _selected.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final player = _selected.values.elementAt(index);
                        return InputChip(
                          backgroundColor: AppColors.surface2,
                          selectedColor:
                              AppColors.primary.withValues(alpha: 0.18),
                          label: Text(player.displayName),
                          labelStyle: const TextStyle(color: Colors.white),
                          onDeleted: () => _toggle(player),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 8),
                Expanded(
                  child: _loading
                      ? const Center(child: LoadingSpinner())
                      : _players.isEmpty
                          ? const Center(
                              child: Text(
                                'No se encontraron jugadores',
                                style: TextStyle(color: AppColors.muted),
                              ),
                            )
                          : ListView.separated(
                              controller: controller,
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                              itemCount: _players.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final player = _players[index];
                                final selected =
                                    _selected.containsKey(player.userId);
                                return InkWell(
                                  onTap: () => _toggle(player),
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: AppColors.surface2,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: selected
                                            ? AppColors.primary
                                            : AppColors.border,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 42,
                                          height: 42,
                                          decoration: const BoxDecoration(
                                            color: AppColors.surface,
                                            shape: BoxShape.circle,
                                          ),
                                          alignment: Alignment.center,
                                          child: Text(
                                            player.displayName.isNotEmpty
                                                ? player.displayName[0]
                                                    .toUpperCase()
                                                : '?',
                                            style: const TextStyle(
                                              color: AppColors.primary,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                player.displayName,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              if (player.email != null) ...[
                                                const SizedBox(height: 4),
                                                Text(
                                                  player.email!,
                                                  style: const TextStyle(
                                                    color: AppColors.muted,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                              const SizedBox(height: 6),
                                              Wrap(
                                                spacing: 6,
                                                runSpacing: 6,
                                                children: [
                                                  LevelBadge(
                                                      level: player.level),
                                                  PadelBadge(
                                                    label: player.isAvailable
                                                        ? 'Disponible'
                                                        : 'No disponible',
                                                    variant: player.isAvailable
                                                        ? PadelBadgeVariant
                                                            .success
                                                        : PadelBadgeVariant
                                                            .warning,
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        Checkbox(
                                          value: selected,
                                          onChanged: (_) => _toggle(player),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
