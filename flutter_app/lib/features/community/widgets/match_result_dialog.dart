import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../models/community_model.dart';
import '../models/match_result_model.dart';
import '../providers/community_provider.dart';

Future<bool?> showMatchResultDialog(
  BuildContext context, {
  required CommunityPlanModel plan,
  MatchResultSubmissionModel? existingSubmission,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _MatchResultDialog(
      plan: plan,
      existingSubmission: existingSubmission,
    ),
  );
}

class _MatchResultDialog extends ConsumerStatefulWidget {
  final CommunityPlanModel plan;
  final MatchResultSubmissionModel? existingSubmission;

  const _MatchResultDialog({
    required this.plan,
    this.existingSubmission,
  });

  @override
  ConsumerState<_MatchResultDialog> createState() => _MatchResultDialogState();
}

class _MatchResultDialogState extends ConsumerState<_MatchResultDialog> {
  late final List<CommunityParticipantModel> _accepted;
  late final CommunityParticipantModel? _me;
  int _step = 0;
  int? _partnerUserId;
  int _winnerTeam = 1;
  final List<_SetInput> _sets = [
    _SetInput(),
    _SetInput(),
    _SetInput(),
  ];
  bool _busy = false;
  String? _error;

  bool get _hasExistingSubmission => widget.existingSubmission != null;

  @override
  void initState() {
    super.initState();
    _accepted = widget.plan.participants
        .where((p) => p.responseState == 'accepted')
        .toList(growable: false);
    _me = _accepted.firstWhere(
      (p) => p.isCurrentUser,
      orElse: () => widget.plan.participants.firstWhere(
        (p) => p.isCurrentUser,
        orElse: () => _accepted.isNotEmpty
            ? _accepted.first
            : widget.plan.participants.first,
      ),
    );

    final existing = widget.existingSubmission;
    if (existing != null) {
      _partnerUserId = existing.partnerUserId;
      _winnerTeam = existing.winnerTeam;
      for (var i = 0; i < existing.sets.length && i < _sets.length; i++) {
        _sets[i].aController.text = existing.sets[i].a.toString();
        _sets[i].bController.text = existing.sets[i].b.toString();
      }
    }

    if (_accepted.length == 4) {
      _step = 0;
    } else {
      _step = 1;
    }
  }

  @override
  void dispose() {
    for (final s in _sets) {
      s.dispose();
    }
    super.dispose();
  }

  CommunityParticipantModel? get _partner {
    if (_partnerUserId == null) return null;
    for (final p in _accepted) {
      if (p.userId == _partnerUserId) return p;
    }
    return null;
  }

  List<CommunityParticipantModel> get _rivals {
    if (_accepted.length != 4) {
      return _accepted.where((p) => p.userId != _me?.userId).toList();
    }
    return _accepted
        .where((p) => p.userId != _me?.userId && p.userId != _partnerUserId)
        .toList(growable: false);
  }

  static String _planDateTimeLabel(CommunityPlanModel plan) {
    final parsed = DateTime.tryParse(plan.scheduledDate);
    final dateStr = parsed != null
        ? '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}'
        : plan.scheduledDate;
    final timeStr = plan.scheduledTime.length >= 5
        ? plan.scheduledTime.substring(0, 5)
        : plan.scheduledTime;
    return '$dateStr · ${timeStr}h';
  }

  bool get _canGoNext {
    switch (_step) {
      case 0:
        return _partnerUserId != null;
      case 1:
        return _winnerTeam == 1 || _winnerTeam == 2;
      case 2:
        return _validSets().isNotEmpty;
      default:
        return false;
    }
  }

  List<SetScore> _validSets() {
    final result = <SetScore>[];
    for (final s in _sets) {
      final a = int.tryParse(s.aController.text.trim());
      final b = int.tryParse(s.bController.text.trim());
      if (a == null && b == null) continue;
      if (a == null || b == null) return const [];
      if (a < 0 || b < 0 || a > 7 || b > 7) return const [];
      result.add(SetScore(a: a, b: b));
    }
    return result;
  }

  void _next() {
    if (_step < 2) {
      setState(() {
        _step = _step == 0 ? 1 : 2;
        _error = null;
      });
    }
  }

  void _back() {
    if (_step == 2) {
      setState(() => _step = 1);
    } else if (_step == 1 && _accepted.length == 4) {
      setState(() => _step = 0);
    }
  }

  Future<void> _submit() async {
    final sets = _validSets();
    if (sets.isEmpty) {
      setState(() => _error = 'Indica al menos un set válido.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(communityActionsProvider).submitMatchResult(
            planId: widget.plan.id,
            partnerUserId: _accepted.length == 4 ? _partnerUserId : null,
            winnerTeam: _winnerTeam,
            sets: sets,
          );
      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _hasExistingSubmission
                ? 'Resultado actualizado. Esperando confirmación del resto.'
                : 'Resultado enviado. Esperando confirmación del resto.',
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'No se pudo enviar: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.emoji_events,
                      color: AppColors.primary, size: 22),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Resultado del partido',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.muted),
                    onPressed:
                        _busy ? null : () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                _planDateTimeLabel(widget.plan),
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 13,
                ),
              ),
              if (_hasExistingSubmission) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.28),
                    ),
                  ),
                  child: const Text(
                    'Hemos recuperado tu envío anterior para que puedas revisarlo o corregirlo.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              _StepIndicator(
                current: _step,
                total: _accepted.length == 4 ? 3 : 2,
              ),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: _buildStepContent(),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: const TextStyle(color: AppColors.danger, fontSize: 13),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  if ((_step == 2) || (_step == 1 && _accepted.length == 4))
                    TextButton(
                      onPressed: _busy ? null : _back,
                      child: const Text('Atrás'),
                    ),
                  const Spacer(),
                  if (_step < 2)
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.dark,
                      ),
                      onPressed: (_busy || !_canGoNext) ? null : _next,
                      child: const Text('Siguiente'),
                    )
                  else
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.dark,
                      ),
                      onPressed: (_busy || !_canGoNext) ? null : _submit,
                      child: _busy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: AppColors.dark),
                            )
                          : Text(
                              _hasExistingSubmission ? 'Actualizar' : 'Enviar'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepContent() {
    if (_step == 0) {
      return _buildPartnerStep();
    }
    if (_step == 1) {
      return _buildWinnerStep();
    }
    return _buildSetsStep();
  }

  Widget _buildPartnerStep() {
    final others = _accepted.where((p) => p.userId != _me?.userId).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '¿Cuál fue tu pareja?',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Selecciona con quién jugaste en el mismo equipo.',
          style: TextStyle(color: AppColors.muted, fontSize: 13),
        ),
        const SizedBox(height: 12),
        ...others.map(
          (p) => _SelectableTile(
            title: p.displayName,
            selected: _partnerUserId == p.userId,
            onTap: () => setState(() => _partnerUserId = p.userId),
          ),
        ),
      ],
    );
  }

  Widget _buildWinnerStep() {
    final myName = _me?.displayName ?? 'Tú';
    final partnerName = _partner?.displayName;
    final rivals = _rivals.map((p) => p.displayName).toList();

    final myLabel = partnerName != null ? '$myName + $partnerName' : myName;
    final rivalLabel = rivals.isEmpty ? 'Equipo rival' : rivals.join(' + ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '¿Qué equipo ganó?',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        _SelectableTile(
          title: myLabel,
          subtitle: 'Mi equipo',
          selected: _winnerTeam == 1,
          onTap: () => setState(() => _winnerTeam = 1),
        ),
        _SelectableTile(
          title: rivalLabel,
          subtitle: 'Equipo rival',
          selected: _winnerTeam == 2,
          onTap: () => setState(() => _winnerTeam = 2),
        ),
      ],
    );
  }

  Widget _buildSetsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '¿Cuál fue el resultado?',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Mi equipo / Equipo rival. Deja el tercer set vacío si no se jugó.',
          style: TextStyle(color: AppColors.muted, fontSize: 13),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < _sets.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                SizedBox(
                  width: 56,
                  child: Text(
                    'Set ${i + 1}',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 13,
                    ),
                  ),
                ),
                Expanded(child: _setField(_sets[i].aController, 'Mi equipo')),
                const SizedBox(width: 8),
                const Text('-',
                    style: TextStyle(color: AppColors.muted, fontSize: 16)),
                const SizedBox(width: 8),
                Expanded(child: _setField(_sets[i].bController, 'Rival')),
              ],
            ),
          ),
      ],
    );
  }

  Widget _setField(TextEditingController controller, String hint) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      maxLength: 1,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        hintText: hint,
        counterText: '',
        isDense: true,
        filled: true,
        fillColor: AppColors.surface2,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
      ),
      style: const TextStyle(color: Colors.white, fontSize: 16),
    );
  }
}

class _SetInput {
  final TextEditingController aController = TextEditingController();
  final TextEditingController bController = TextEditingController();

  void dispose() {
    aController.dispose();
    bController.dispose();
  }
}

class _StepIndicator extends StatelessWidget {
  final int current;
  final int total;

  const _StepIndicator({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    final displayCurrent = total == 2 ? current : current;
    return Row(
      children: List.generate(total, (i) {
        final active = i <= displayCurrent - (total == 2 ? 1 : 0);
        return Expanded(
          child: Container(
            height: 3,
            margin: EdgeInsets.only(right: i == total - 1 ? 0 : 4),
            decoration: BoxDecoration(
              color: active ? AppColors.primary : AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }
}

class _SelectableTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _SelectableTile({
    required this.title,
    this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.12)
                : AppColors.surface2,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? AppColors.primary : AppColors.muted,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                        ),
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
