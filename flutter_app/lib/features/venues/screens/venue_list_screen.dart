import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/api/api_client.dart';
import '../../../shared/widgets/loading_spinner.dart';
import '../../../shared/widgets/padel_card.dart';
import '../../../shared/widgets/padel_badge.dart';
import '../models/venue_model.dart';

class VenueListScreen extends ConsumerStatefulWidget {
  const VenueListScreen({super.key});

  @override
  ConsumerState<VenueListScreen> createState() => _VenueListScreenState();
}

class _VenueListScreenState extends ConsumerState<VenueListScreen> {
  bool _loading = true;
  List<VenueModel> _venues = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchVenues();
  }

  Future<void> _fetchVenues() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final data = await api.get('/padel/venues');
      final list = (data is List ? data : (data['venues'] ?? [])) as List;
      if (mounted) {
        setState(() {
          _venues = list.map((v) => VenueModel.fromJson(v as Map<String, dynamic>)).toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error al cargar las sedes';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.dark,
      appBar: AppBar(
        title: const Text('Clubes'),
        backgroundColor: AppColors.surface,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.muted),
            onPressed: _fetchVenues,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: LoadingSpinner())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!, style: const TextStyle(color: AppColors.danger)),
                      const SizedBox(height: 12),
                      ElevatedButton(onPressed: _fetchVenues, child: const Text('Reintentar')),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: AppColors.primary,
                  backgroundColor: AppColors.surface,
                  onRefresh: _fetchVenues,
                  child: _venues.isEmpty
                      ? const Center(
                          child: Text(
                            'No hay clubes disponibles',
                            style: TextStyle(color: AppColors.muted),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _venues.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final venue = _venues[index];
                            return PadelCard(
                              onTap: () => context.push('/venues/${venue.id}'),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          venue.name,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            const Icon(Icons.location_on_outlined, color: AppColors.muted, size: 14),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                venue.location,
                                                style: const TextStyle(color: AppColors.muted, fontSize: 13),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            const Icon(Icons.business, color: AppColors.muted, size: 14),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${venue.courtCount} ${venue.courtCount == 1 ? 'pista' : 'pistas'}',
                                              style: const TextStyle(color: AppColors.muted, fontSize: 13),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right, color: AppColors.muted),
                                ],
                              ),
                            );
                          },
                        ),
                ),
    );
  }
}
