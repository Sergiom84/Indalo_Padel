import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/loading_spinner.dart';
import '../../../shared/widgets/padel_card.dart';
import '../providers/venue_provider.dart';

class VenueListScreen extends ConsumerWidget {
  const VenueListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final venuesAsync = ref.watch(venueListProvider);

    return Scaffold(
      backgroundColor: AppColors.dark,
      appBar: AppBar(
        title: const Text('Clubes'),
        backgroundColor: AppColors.surface,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.muted),
            onPressed: () => ref.invalidate(venueListProvider),
          ),
        ],
      ),
      body: venuesAsync.when(
        loading: () => const Center(child: LoadingSpinner()),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Error al cargar las sedes',
                  style: TextStyle(color: AppColors.danger)),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => ref.invalidate(venueListProvider),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
        data: (venues) => RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: AppColors.surface,
          onRefresh: () async => ref.invalidate(venueListProvider),
          child: venues.isEmpty
              ? const Center(
                  child: Text(
                    'No hay clubes disponibles',
                    style: TextStyle(color: AppColors.muted),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: venues.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final venue = venues[index];
                    final courtsLabel = venue.courtCount > 0
                        ? '${venue.courtCount} ${venue.courtCount == 1 ? 'pista' : 'pistas'}'
                        : 'Pistas no localizadas';
                    final statusColor = venue.isComingSoon
                        ? AppColors.warning
                        : AppColors.success;
                    final statusLabel = venue.isComingSoon
                        ? 'Próximamente'
                        : 'Disponible';
                    return PadelCard(
                      onTap: venue.isComingSoon
                          ? null
                          : () => context.push('/venues/${venue.id}'),
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
                                    const Icon(Icons.location_on_outlined,
                                        color: AppColors.muted, size: 14),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        venue.location,
                                        style: const TextStyle(
                                            color: AppColors.muted,
                                            fontSize: 13),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.business,
                                        color: AppColors.muted, size: 14),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        courtsLabel,
                                        style: const TextStyle(
                                            color: AppColors.muted, fontSize: 13),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: statusColor.withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Text(
                                    statusLabel,
                                    style: TextStyle(
                                      color: statusColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            venue.isComingSoon
                                ? Icons.lock_clock_outlined
                                : Icons.chevron_right,
                            color: AppColors.muted,
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
