import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/api/api_client.dart';
import '../../../shared/widgets/loading_spinner.dart';
import '../models/venue_model.dart';

class VenueDetailScreen extends ConsumerStatefulWidget {
  final String venueId;
  const VenueDetailScreen({super.key, required this.venueId});

  @override
  ConsumerState<VenueDetailScreen> createState() => _VenueDetailScreenState();
}

class _VenueDetailScreenState extends ConsumerState<VenueDetailScreen> {
  bool _loadingVenue = true;
  bool _loadingAvailability = false;
  VenueModel? _venue;
  AvailabilityModel? _availability;
  String? _error;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _fetchVenue();
  }

  Future<void> _fetchVenue() async {
    try {
      final api = ref.read(apiClientProvider);
      final data = await api.get('/padel/venues/${widget.venueId}');
      final venueData = data is Map
          ? (data['venue'] != null
              ? {
                  ...Map<String, dynamic>.from(data['venue'] as Map),
                  'courts': data['courts'] ?? [],
                }
              : Map<String, dynamic>.from(data as Map))
          : <String, dynamic>{};
      if (mounted) {
        setState(() {
          _venue = VenueModel.fromJson(venueData);
          _loadingVenue = false;
        });
        _fetchAvailability();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error al cargar la sede';
          _loadingVenue = false;
        });
      }
    }
  }

  Future<void> _fetchAvailability() async {
    if (!mounted) return;
    setState(() => _loadingAvailability = true);
    try {
      final api = ref.read(apiClientProvider);
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final data = await api.get('/padel/venues/${widget.venueId}/availability?date=$dateStr');
      if (mounted) {
        setState(() {
          _availability = AvailabilityModel.fromJson(data as Map<String, dynamic>);
          _loadingAvailability = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingAvailability = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.primary,
            onPrimary: AppColors.dark,
            surface: AppColors.surface2,
            onSurface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _availability = null;
      });
      _fetchAvailability();
    }
  }

  void _handleSlotTap(CourtModel court, TimeSlotModel slot, double? price) {
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    context.push(
      '/booking/${court.id}',
      extra: {
        'date': dateStr,
        'start_time': slot.startTime,
        'venue_name': _venue?.name ?? '',
        'court_name': court.name,
        'price': price,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingVenue) {
      return Scaffold(
        backgroundColor: AppColors.dark,
        appBar: AppBar(backgroundColor: AppColors.surface),
        body: const Center(child: LoadingSpinner()),
      );
    }

    if (_error != null || _venue == null) {
      return Scaffold(
        backgroundColor: AppColors.dark,
        appBar: AppBar(backgroundColor: AppColors.surface),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_error ?? 'Sede no encontrada', style: const TextStyle(color: AppColors.danger)),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: () => context.pop(), child: const Text('Volver')),
            ],
          ),
        ),
      );
    }

    final venue = _venue!;
    final courts = _availability?.courts ?? [];
    final timeSlots = _availability?.timeSlots ?? [];

    return Scaffold(
      backgroundColor: AppColors.dark,
      appBar: AppBar(
        title: Text(venue.name),
        backgroundColor: AppColors.surface,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Venue info card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, color: AppColors.primary, size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text(venue.location, style: const TextStyle(color: Colors.white))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.business, color: AppColors.primary, size: 18),
                      const SizedBox(width: 8),
                      Text('${venue.courtCount} pistas', style: const TextStyle(color: Colors.white)),
                    ],
                  ),
                  if (venue.openingTime != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.access_time, color: AppColors.primary, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          '${venue.openingTime?.substring(0, 5)} - ${venue.closingTime?.substring(0, 5)}',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Courts list
            if (venue.courts.isNotEmpty) ...[
              const Text('Pistas', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: venue.courts.map((court) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surface2,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(court.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                        if (court.surfaceType != null)
                          Text(court.surfaceType!, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                        if (court.isIndoor != null)
                          Text(
                            court.isIndoor! ? 'Cubierta' : 'Exterior',
                            style: const TextStyle(color: AppColors.muted, fontSize: 12),
                          ),
                      ],
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],

            // Availability section
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
                  Row(
                    children: [
                      const Icon(Icons.calendar_month, color: AppColors.primary, size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Disponibilidad',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                      ),
                      GestureDetector(
                        onTap: _pickDate,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.surface2,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today, color: AppColors.muted, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                DateFormat('dd/MM/yyyy').format(_selectedDate),
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_loadingAvailability)
                    const Center(child: LoadingSpinner())
                  else if (courts.isEmpty || timeSlots.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          'No hay disponibilidad para esta fecha',
                          style: TextStyle(color: AppColors.muted),
                        ),
                      ),
                    )
                  else ...[
                    // Legend
                    Row(
                      children: [
                        Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.green.withOpacity(0.5)),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text('Disponible', style: TextStyle(color: AppColors.muted, fontSize: 12)),
                        const SizedBox(width: 16),
                        Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.red.withOpacity(0.5)),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text('Ocupado', style: TextStyle(color: AppColors.muted, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Availability grid
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(AppColors.surface2),
                        dataRowColor: WidgetStateProperty.all(AppColors.dark.withOpacity(0.3)),
                        columnSpacing: 8,
                        horizontalMargin: 8,
                        columns: [
                          const DataColumn(
                            label: Text('Hora', style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600)),
                          ),
                          ...courts.map(
                            (court) => DataColumn(
                              label: Text(
                                court.name,
                                style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ],
                        rows: timeSlots.map((slot) {
                          return DataRow(
                            cells: [
                              DataCell(
                                Text(
                                  slot.startTime.length >= 5 ? slot.startTime.substring(0, 5) : slot.startTime,
                                  style: const TextStyle(color: Colors.white, fontSize: 13),
                                ),
                              ),
                              ...courts.map((court) {
                                final courtSlot = slot.courts[court.id.toString()];
                                final isAvailable = courtSlot?.available ?? false;
                                final price = courtSlot?.price;

                                return DataCell(
                                  GestureDetector(
                                    onTap: isAvailable ? () => _handleSlotTap(court, slot, price) : null,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isAvailable
                                            ? Colors.green.withOpacity(0.15)
                                            : Colors.red.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: isAvailable
                                              ? Colors.green.withOpacity(0.4)
                                              : Colors.red.withOpacity(0.3),
                                        ),
                                      ),
                                      child: Text(
                                        isAvailable
                                            ? (price != null ? '${price.toStringAsFixed(0)}€' : 'Libre')
                                            : 'Ocupado',
                                        style: TextStyle(
                                          color: isAvailable ? Colors.green : Colors.red.withOpacity(0.6),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
