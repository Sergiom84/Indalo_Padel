import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/platform/platform_helper.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/adaptive_pickers.dart';

class MatchCreateScreen extends ConsumerStatefulWidget {
  const MatchCreateScreen({super.key});

  @override
  ConsumerState<MatchCreateScreen> createState() => _MatchCreateScreenState();
}

class _MatchCreateScreenState extends ConsumerState<MatchCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  List<dynamic> _venues = [];
  bool _submitting = false;
  String? _error;

  String _matchDate = '';
  TimeOfDay? _startTime;
  String _venueId = '';
  String _matchType = 'abierto';
  int _minLevel = 1;
  int _maxLevel = 9;
  final _descCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchVenues();
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchVenues() async {
    try {
      final api = ref.read(apiClientProvider);
      final data = await api.get('/padel/venues');
      if (mounted) {
        setState(() {
          _venues = _asList(data is Map ? data['venues'] : data);
        });
      }
    } catch (_) {}
  }

  List<dynamic> _asList(dynamic value) {
    if (value is List) {
      return value;
    }
    return [];
  }

  Future<void> _pickDate() async {
    final picked = await showAdaptiveAppDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
    );
    if (picked != null) {
      await appSelectionHaptic();
      setState(() {
        _matchDate = '${picked.year.toString().padLeft(4, '0')}-'
            '${picked.month.toString().padLeft(2, '0')}-'
            '${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showAdaptiveAppTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 18, minute: 0),
    );
    if (picked != null) {
      await appSelectionHaptic();
      setState(() => _startTime = picked);
    }
  }

  Future<void> _submit() async {
    if (_matchDate.isEmpty || _startTime == null || _venueId.isEmpty) {
      setState(() => _error = 'Por favor completa fecha, hora y sede.');
      return;
    }
    if (_minLevel > _maxLevel) {
      setState(() => _error = 'El nivel mínimo no puede ser mayor que el máximo.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final api = ref.read(apiClientProvider);
      final startTimeStr =
          '${_startTime!.hour.toString().padLeft(2, '0')}:${_startTime!.minute.toString().padLeft(2, '0')}';

      final result = await api.post('/padel/matches', data: {
        'match_date': _matchDate,
        'start_time': startTimeStr,
        'venue_id': int.tryParse(_venueId) ?? _venueId,
        'match_type': _matchType,
        'min_level': _minLevel,
        'max_level': _maxLevel,
        if (_descCtrl.text.trim().isNotEmpty) 'description': _descCtrl.text.trim(),
      });

      final matchId = result?['id'] ?? result?['match']?['id'];
      if (mounted) {
        if (matchId != null) {
          context.go('/matches/$matchId');
        } else {
          context.go('/matches');
        }
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.dark,
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.emoji_events, color: AppColors.primary, size: 20),
            SizedBox(width: 8),
            Text('Crear partido'),
          ],
        ),
        backgroundColor: AppColors.surface,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Error
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                  ),
                  child: Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
                ),
                const SizedBox(height: 16),
              ],

              const Text(
                'Detalles del partido',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
              ),
              const SizedBox(height: 16),

              // Date & Time row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Fecha *', style: TextStyle(color: AppColors.muted, fontSize: 12)),
                        const SizedBox(height: 6),
                        GestureDetector(
                          onTap: _pickDate,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today, color: AppColors.muted, size: 16),
                                const SizedBox(width: 8),
                                Text(
                                  _matchDate.isEmpty ? 'Selecciona' : _matchDate,
                                  style: TextStyle(
                                    color: _matchDate.isEmpty ? AppColors.muted : Colors.white,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Hora *', style: TextStyle(color: AppColors.muted, fontSize: 12)),
                        const SizedBox(height: 6),
                        GestureDetector(
                          onTap: _pickTime,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.access_time, color: AppColors.muted, size: 16),
                                const SizedBox(width: 8),
                                Text(
                                  _startTime == null
                                      ? 'Selecciona'
                                      : '${_startTime!.hour.toString().padLeft(2, '0')}:${_startTime!.minute.toString().padLeft(2, '0')}',
                                  style: TextStyle(
                                    color: _startTime == null ? AppColors.muted : Colors.white,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Venue
              const Text('Sede *', style: TextStyle(color: AppColors.muted, fontSize: 12)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _venueId.isEmpty ? null : _venueId,
                dropdownColor: AppColors.surface2,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
                hint: const Text('Selecciona una sede', style: TextStyle(color: AppColors.muted)),
                items: _venues.map<DropdownMenuItem<String>>((v) {
                  return DropdownMenuItem<String>(
                    value: v['id']?.toString() ?? '',
                    child: Text(v['name'] ?? v['nombre'] ?? ''),
                  );
                }).toList(),
                onChanged: (v) => setState(() => _venueId = v ?? ''),
              ),
              const SizedBox(height: 16),

              // Match type
              const Text('Tipo de partido', style: TextStyle(color: AppColors.muted, fontSize: 12)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _matchType,
                dropdownColor: AppColors.surface2,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
                items: const [
                  DropdownMenuItem(value: 'abierto', child: Text('Abierto')),
                  DropdownMenuItem(value: 'privado', child: Text('Privado')),
                ],
                onChanged: (v) => setState(() => _matchType = v ?? 'abierto'),
              ),
              const SizedBox(height: 16),

              // Level range
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Nivel mínimo', style: TextStyle(color: AppColors.muted, fontSize: 12)),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<int>(
                          initialValue: _minLevel,
                          dropdownColor: AppColors.surface2,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          ),
                          items: List.generate(9, (i) => i + 1)
                              .map((n) => DropdownMenuItem(value: n, child: Text('Nivel $n')))
                              .toList(),
                          onChanged: (v) => setState(() => _minLevel = v ?? 1),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Nivel máximo', style: TextStyle(color: AppColors.muted, fontSize: 12)),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<int>(
                          initialValue: _maxLevel,
                          dropdownColor: AppColors.surface2,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          ),
                          items: List.generate(9, (i) => i + 1)
                              .map((n) => DropdownMenuItem(value: n, child: Text('Nivel $n')))
                              .toList(),
                          onChanged: (v) => setState(() => _maxLevel = v ?? 9),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Description
              const Text('Descripción', style: TextStyle(color: AppColors.muted, fontSize: 12)),
              const SizedBox(height: 6),
              TextField(
                controller: _descCtrl,
                maxLines: 3,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Información adicional sobre el partido...',
                ),
              ),
              const SizedBox(height: 24),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => context.pop(),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _submitting ? null : _submit,
                      child: _submitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.dark),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.save, size: 18),
                                SizedBox(width: 6),
                                Text('Crear partido', style: TextStyle(fontWeight: FontWeight.w800)),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
