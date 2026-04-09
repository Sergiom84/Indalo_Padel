import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/api/api_client.dart';
import '../../../shared/widgets/adaptive_pickers.dart';
import '../../../shared/widgets/loading_spinner.dart';
import '../../../shared/widgets/padel_badge.dart';
import '../models/match_model.dart';

PadelBadgeVariant _matchStatusVariant(String status) {
  switch (status) {
    case 'buscando':
      return PadelBadgeVariant.warning;
    case 'completo':
      return PadelBadgeVariant.success;
    case 'en_juego':
      return PadelBadgeVariant.info;
    case 'cancelado':
      return PadelBadgeVariant.danger;
    default:
      return PadelBadgeVariant.neutral;
  }
}

String _matchStatusLabel(String status) {
  switch (status) {
    case 'buscando':
      return 'Buscando';
    case 'completo':
      return 'Completo';
    case 'en_juego':
      return 'En juego';
    case 'finalizado':
      return 'Finalizado';
    case 'cancelado':
      return 'Cancelado';
    default:
      return status;
  }
}

class MatchListScreen extends ConsumerStatefulWidget {
  const MatchListScreen({super.key});

  @override
  ConsumerState<MatchListScreen> createState() => _MatchListScreenState();
}

class _MatchListScreenState extends ConsumerState<MatchListScreen> {
  bool _loading = true;
  List<MatchModel> _matches = [];
  List<dynamic> _venues = [];
  String _filterVenueId = '';
  String _filterDate = '';
  bool _showFilters = false;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _loading = true);
    try {
      final api = ref.read(apiClientProvider);
      final results = await Future.wait([
        api.get('/padel/matches').catchError((_) => {'matches': []}),
        api.get('/padel/venues').catchError((_) => {'venues': []}),
      ]);

      final matchesRaw = _asList(results[0] is Map ? results[0]['matches'] : results[0]);
      final venuesRaw = _asList(results[1] is Map ? results[1]['venues'] : results[1]);

      if (mounted) {
        setState(() {
          _matches = matchesRaw
              .map((m) => MatchModel.fromJson(m as Map<String, dynamic>))
              .toList();
          _venues = venuesRaw;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<dynamic> _asList(dynamic value) {
    if (value is List) {
      return value;
    }
    return [];
  }

  List<MatchModel> get _filtered {
    return _matches.where((m) {
      if (_filterVenueId.isNotEmpty && m.venueId?.toString() != _filterVenueId) {
        return false;
      }
      if (_filterDate.isNotEmpty && (m.matchDate?.substring(0, 10) ?? '') != _filterDate) {
        return false;
      }
      return true;
    }).toList();
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('EEE d MMM', 'es_ES').format(date);
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Scaffold(
      backgroundColor: AppColors.dark,
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.emoji_events, color: AppColors.primary, size: 22),
            SizedBox(width: 8),
            Text('Partidos'),
          ],
        ),
        backgroundColor: AppColors.surface,
        actions: [
          IconButton(
            icon: Icon(
              Icons.filter_list,
              color: _showFilters ? AppColors.primary : AppColors.muted,
            ),
            onPressed: () => setState(() => _showFilters = !_showFilters),
          ),
          IconButton(
            icon: const Icon(Icons.add, color: AppColors.primary),
            onPressed: () => context.push('/matches/create'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: LoadingSpinner())
          : Column(
              children: [
                // Filters
                if (_showFilters)
                  Container(
                    padding: const EdgeInsets.all(12),
                    color: AppColors.surface,
                    child: Column(
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: _filterVenueId.isEmpty ? null : _filterVenueId,
                          dropdownColor: AppColors.surface2,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'Sede',
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          hint: const Text('Todas las sedes', style: TextStyle(color: AppColors.muted)),
                          items: [
                            const DropdownMenuItem<String>(
                              value: null,
                              child: Text('Todas las sedes', style: TextStyle(color: AppColors.muted)),
                            ),
                            ..._venues.map((v) => DropdownMenuItem<String>(
                              value: v['id']?.toString() ?? '',
                              child: Text(v['name'] ?? v['nombre'] ?? '', style: const TextStyle(color: Colors.white)),
                            )),
                          ],
                          onChanged: (v) => setState(() => _filterVenueId = v ?? ''),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextButton.icon(
                                onPressed: () async {
                                  final picked = await showAdaptiveAppDatePicker(
                                    context: context,
                                    initialDate: DateTime.now(),
                                    firstDate: DateTime.now().subtract(const Duration(days: 30)),
                                    lastDate: DateTime.now().add(const Duration(days: 60)),
                                  );
                                  if (picked != null) {
                                    setState(() => _filterDate = DateFormat('yyyy-MM-dd').format(picked));
                                  }
                                },
                                icon: const Icon(Icons.calendar_today, size: 16),
                                label: Text(
                                  _filterDate.isEmpty ? 'Filtrar por fecha' : _filterDate,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            ),
                            if (_filterVenueId.isNotEmpty || _filterDate.isNotEmpty)
                              TextButton(
                                onPressed: () => setState(() {
                                  _filterVenueId = '';
                                  _filterDate = '';
                                }),
                                child: const Text('Limpiar', style: TextStyle(color: AppColors.muted, fontSize: 13)),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),

                // Match list
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.emoji_events, color: AppColors.border, size: 48),
                              const SizedBox(height: 12),
                              const Text('No se encontraron partidos', style: TextStyle(color: AppColors.muted)),
                              const SizedBox(height: 12),
                              TextButton(
                                onPressed: () => context.push('/matches/create'),
                                child: const Text('Crear el primero', style: TextStyle(color: AppColors.primary)),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          color: AppColors.primary,
                          backgroundColor: AppColors.surface,
                          onRefresh: _fetchData,
                          child: ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final match = filtered[index];
                              return GestureDetector(
                                onTap: () => context.push('/matches/${match.id}'),
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              const Icon(Icons.emoji_events, color: AppColors.primary, size: 18),
                                              const SizedBox(width: 8),
                                              Text(
                                                _formatDate(match.matchDate),
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 15,
                                                ),
                                              ),
                                            ],
                                          ),
                                          PadelBadge(
                                            label: _matchStatusLabel(match.status),
                                            variant: _matchStatusVariant(match.status),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      if (match.startTime != null)
                                        Row(
                                          children: [
                                            const Icon(Icons.access_time, color: AppColors.muted, size: 14),
                                            const SizedBox(width: 6),
                                            Text(
                                              match.startTime!.length >= 5
                                                  ? match.startTime!.substring(0, 5)
                                                  : match.startTime!,
                                              style: const TextStyle(color: AppColors.muted, fontSize: 13),
                                            ),
                                          ],
                                        ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(Icons.location_on_outlined, color: AppColors.muted, size: 14),
                                          const SizedBox(width: 6),
                                          Text(
                                            match.venueName ?? 'Sin sede',
                                            style: const TextStyle(color: AppColors.muted, fontSize: 13),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(Icons.people_outline, color: AppColors.muted, size: 14),
                                          const SizedBox(width: 6),
                                          Text(
                                            '${match.playerCount} / ${match.maxPlayers} jugadores',
                                            style: const TextStyle(color: AppColors.muted, fontSize: 13),
                                          ),
                                        ],
                                      ),
                                      if (match.minLevel != null && match.maxLevel != null) ...[
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            LevelBadge(level: match.minLevel),
                                            const SizedBox(width: 4),
                                            const Text('—', style: TextStyle(color: AppColors.muted)),
                                            const SizedBox(width: 4),
                                            LevelBadge(level: match.maxLevel),
                                          ],
                                        ),
                                      ],
                                      if (match.creatorName != null) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          'Creado por ${match.creatorName}',
                                          style: const TextStyle(color: AppColors.muted, fontSize: 12),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }
}
