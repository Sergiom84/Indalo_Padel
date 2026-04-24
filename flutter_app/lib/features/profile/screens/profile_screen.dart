import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/platform/platform_helper.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/current_profile_provider.dart';
import '../../../shared/utils/player_preferences.dart';
import '../../../shared/utils/profile_image_picker.dart';
import '../../../shared/widgets/loading_spinner.dart';
import '../../../shared/widgets/preference_checkbox_group.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../../auth/providers/auth_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _loading = true;
  bool _saving = false;
  String? _error;
  Map<String, dynamic>? _profile;

  void _syncProfileState(Map<String, dynamic> profile) {
    _profile = profile;
  }

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final data = await api.get('/padel/players/profile');
      if (!mounted) {
        return;
      }
      ref
          .read(currentProfileProvider.notifier)
          .setProfile(Map<String, dynamic>.from(data['profile'] as Map));
      setState(() {
        _syncProfileState(Map<String, dynamic>.from(data['profile'] as Map));
        _loading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      final cachedProfile = ref.read(currentProfileProvider).valueOrNull;
      if (cachedProfile != null) {
        setState(() {
          _syncProfileState(Map<String, dynamic>.from(cachedProfile));
          _loading = false;
          _error = null;
        });
        return;
      }
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<bool> _updateProfile(Map<String, dynamic> payload) async {
    setState(() => _saving = true);
    try {
      final api = ref.read(apiClientProvider);
      final data = await api.put('/padel/players/profile', data: payload);
      if (!mounted) {
        return false;
      }
      final incoming = Map<String, dynamic>.from(data['profile'] as Map);
      final mergedProfile = <String, dynamic>{
        ...?_profile,
        ...incoming,
        if (_profile?['nombre'] != null) 'nombre': _profile!['nombre'],
        if (_profile?['email'] != null) 'email': _profile!['email'],
      };
      setState(() {
        _syncProfileState(mergedProfile);
      });
      ref.read(currentProfileProvider.notifier).setProfile(mergedProfile);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perfil actualizado')),
      );
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.danger,
          ),
        );
      }
      return false;
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _openPreferencesSheet() async {
    final profile = _profile ?? <String, dynamic>{};
    final preferences = PlayerPreferencesModel.fromJson(profile);
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _PreferencesSheet(
          initialCourt: preferences.courtPreferences,
          initialHands: preferences.dominantHands,
          initialAvailability: preferences.availabilityPreferences,
          initialMatch: preferences.matchPreferences,
          onSave: (payload) => _updateProfile(payload),
        );
      },
    );
  }

  Future<void> _openEditSheet() async {
    final profile = _profile ?? <String, dynamic>{};

    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _EditProfileSheet(
          initialDisplayName: (profile['display_name'] ??
                  profile['nombre'] ??
                  ref.read(authProvider).user?.nombre ??
                  '')
              .toString(),
          initialAvatarUrl: profile['avatar_url']?.toString(),
          onSave: _updateProfile,
        );
      },
    );
  }

  Future<void> _logout() async {
    await appMediumImpact();
    await ref.read(authProvider.notifier).logout();
  }

  Future<void> _deleteAccount() async {
    await appMediumImpact();
    if (!mounted) {
      return;
    }
    final request = await showModalBottomSheet<_DeleteAccountRequest>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _DeleteAccountSheet(),
    );

    if (request == null) {
      return;
    }

    setState(() => _saving = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.delete('/padel/players/profile', data: request.toJson());
      ref.read(currentProfileProvider.notifier).setProfile(null);
      await ref.read(authProvider.notifier).logout();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authUser = ref.watch(authProvider).user;
    final profile = _profile ?? <String, dynamic>{};
    final preferences = PlayerPreferencesModel.fromJson(profile);
    final displayName = (profile['display_name'] ??
            profile['nombre'] ??
            authUser?.nombre ??
            'Jugador')
        .toString();
    final email = (profile['email'] ?? authUser?.email ?? '').toString();
    final availability = (profile['is_available'] ?? false) as bool;
    final avatarUrl = profile['avatar_url']?.toString();

    return Scaffold(
      backgroundColor: AppColors.dark,
      appBar: AppBar(
        title: Text(isCupertinoPlatform ? 'Perfil' : 'Tu perfil'),
      ),
      body: _loading
          ? const LoadingSpinner()
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _error!,
                        style: const TextStyle(color: AppColors.danger),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _fetchProfile,
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              UserAvatar(
                                displayName: displayName,
                                avatarUrl: avatarUrl,
                                size: 68,
                                fontSize: 24,
                                backgroundColor:
                                    AppColors.primary.withValues(alpha: 0.16),
                                borderColor: AppColors.border,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      displayName,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 24,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      email,
                                      style: const TextStyle(
                                        color: AppColors.muted,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: _openEditSheet,
                                icon: Icon(
                                  isCupertinoPlatform
                                      ? CupertinoIcons.pencil
                                      : Icons.edit_outlined,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: _ProfileMetric(
                                  label: 'Nivel',
                                  value: preferences.level.label(
                                    fallbackNumericLevel:
                                        _asInt(profile['numeric_level']),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _ProfileMetric(
                                  label: 'Valoración',
                                  value: '${profile['avg_rating'] ?? '0.0'}',
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _ProfileMetric(
                                  label: 'Partidos',
                                  value: '${profile['matches_played'] ?? 0}',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _ProfileGroup(
                      children: [
                        SwitchListTile.adaptive(
                          value: availability,
                          onChanged: _saving
                              ? null
                              : (value) =>
                                  _updateProfile({'is_available': value}),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                          ),
                          title: const Text(
                            'Disponible para jugar',
                            style: TextStyle(color: Colors.white),
                          ),
                          subtitle: const Text(
                            'Aparecerás en búsquedas y favoritos activos.',
                            style: TextStyle(color: AppColors.muted),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _ProfileGroup(
                      children: [
                        _ProfileActionTile(
                          icon: isCupertinoPlatform
                              ? CupertinoIcons.pencil_circle
                              : Icons.edit_note,
                          title: 'Editar perfil',
                          subtitle: 'Foto, nombre público y contraseña.',
                          onTap: _openEditSheet,
                        ),
                        _ProfileActionTile(
                          icon: isCupertinoPlatform
                              ? CupertinoIcons.slider_horizontal_3
                              : Icons.tune,
                          title: 'Preferencias',
                          subtitle:
                              'Posición, mano, disponibilidad y modalidad.',
                          onTap: _openPreferencesSheet,
                        ),
                        _ProfileActionTile(
                          icon: isCupertinoPlatform
                              ? CupertinoIcons.arrow_right_square
                              : Icons.logout,
                          title: 'Cerrar sesión',
                          subtitle: 'Sal de esta cuenta en el dispositivo.',
                          danger: true,
                          onTap: _logout,
                        ),
                        _ProfileActionTile(
                          icon: isCupertinoPlatform
                              ? CupertinoIcons.delete
                              : Icons.delete_outline,
                          title: 'Eliminar cuenta',
                          subtitle:
                              'Borra tu perfil y cierra la sesión en este dispositivo.',
                          danger: true,
                          onTap: _saving ? () {} : _deleteAccount,
                        ),
                      ],
                    ),
                  ],
                ),
    );
  }
}

class _DeleteAccountRequest {
  final String reason;
  final String? otherReason;

  const _DeleteAccountRequest({
    required this.reason,
    this.otherReason,
  });

  Map<String, dynamic> toJson() => {
        'reason': reason,
        if (otherReason != null && otherReason!.trim().isNotEmpty)
          'other_reason': otherReason!.trim(),
      };
}

class _DeleteReasonOption {
  final String value;
  final String label;

  const _DeleteReasonOption(this.value, this.label);
}

const _deleteReasonOptions = [
  _DeleteReasonOption('no_uso_la_app', 'No uso la app'),
  _DeleteReasonOption('no_me_gusta', 'No me gusta'),
  _DeleteReasonOption('no_es_lo_que_buscaba', 'No es lo que buscaba'),
  _DeleteReasonOption('otros', 'Otros'),
];

class _DeleteAccountSheet extends StatefulWidget {
  const _DeleteAccountSheet();

  @override
  State<_DeleteAccountSheet> createState() => _DeleteAccountSheetState();
}

class _DeleteAccountSheetState extends State<_DeleteAccountSheet> {
  late final TextEditingController _confirmationCtrl;
  late final TextEditingController _otherReasonCtrl;
  String _reason = _deleteReasonOptions.first.value;

  bool get _canDelete => _confirmationCtrl.text.trim() == 'ELIMINAR';

  @override
  void initState() {
    super.initState();
    _confirmationCtrl = TextEditingController()..addListener(_onChanged);
    _otherReasonCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _confirmationCtrl
      ..removeListener(_onChanged)
      ..dispose();
    _otherReasonCtrl.dispose();
    super.dispose();
  }

  void _onChanged() {
    setState(() {});
  }

  void _submit() {
    Navigator.of(context).pop(
      _DeleteAccountRequest(
        reason: _reason,
        otherReason: _otherReasonCtrl.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Eliminar cuenta',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Tu cuenta se desactivará, tus datos personales se anonimizarán y se cerrará la sesión.',
                style: TextStyle(color: AppColors.muted, height: 1.35),
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                initialValue: _reason,
                decoration: const InputDecoration(labelText: 'Motivo'),
                dropdownColor: AppColors.surface2,
                iconEnabledColor: AppColors.muted,
                items: _deleteReasonOptions
                    .map(
                      (option) => DropdownMenuItem<String>(
                        value: option.value,
                        child: Text(option.label),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() => _reason = value);
                },
              ),
              if (_reason == 'otros') ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _otherReasonCtrl,
                  maxLines: 3,
                  maxLength: 500,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Observaciones',
                  ),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _confirmationCtrl,
                textCapitalization: TextCapitalization.characters,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Escribe ELIMINAR para confirmar',
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.danger,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _canDelete ? _submit : null,
                      child: const Text('Eliminar'),
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

class _PreferencesSheet extends StatefulWidget {
  final List<String> initialCourt;
  final List<String> initialHands;
  final List<String> initialAvailability;
  final List<String> initialMatch;
  final Future<bool> Function(Map<String, dynamic> payload) onSave;

  const _PreferencesSheet({
    required this.initialCourt,
    required this.initialHands,
    required this.initialAvailability,
    required this.initialMatch,
    required this.onSave,
  });

  @override
  State<_PreferencesSheet> createState() => _PreferencesSheetState();
}

class _PreferencesSheetState extends State<_PreferencesSheet> {
  late List<String> _court;
  late List<String> _hands;
  late List<String> _availability;
  late List<String> _match;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _court = List.of(widget.initialCourt);
    _hands = List.of(widget.initialHands);
    _availability = List.of(widget.initialAvailability);
    _match = List.of(widget.initialMatch);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final didSave = await widget.onSave({
      'court_preferences': _court,
      'dominant_hands': _hands,
      'availability_preferences': _availability,
      'match_preferences': _match,
    });
    if (!mounted) return;
    setState(() => _saving = false);
    if (didSave) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final availabilityDayValues = PlayerPreferenceCatalog.availabilityDayValues(
      _availability,
    );
    final availabilityTimeValues =
        PlayerPreferenceCatalog.availabilityTimeValues(_availability);

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Preferencias',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 20),
            PreferenceCheckboxGroup(
              title: 'Preferencia en pista',
              options: PlayerPreferenceCatalog.courtPreferences,
              selectedValues: _court,
              enabled: !_saving,
              onChanged: (v) => setState(() => _court = v),
            ),
            const SizedBox(height: 14),
            PreferenceCheckboxGroup(
              title: 'Perfil del jugador',
              options: PlayerPreferenceCatalog.dominantHands,
              selectedValues: _hands,
              enabled: !_saving,
              onChanged: (v) => setState(() => _hands = v),
            ),
            const SizedBox(height: 14),
            PreferenceCheckboxGroup(
              title: 'Horario de preferencia · Días',
              options: PlayerPreferenceCatalog.availabilityDayPreferences,
              selectedValues: availabilityDayValues,
              enabled: !_saving,
              onChanged: (v) => setState(
                () => _availability = PlayerPreferenceCatalog
                    .mergeAvailabilityValues(
                  dayValues: v,
                  timeValues: availabilityTimeValues,
                ),
              ),
            ),
            const SizedBox(height: 14),
            PreferenceCheckboxGroup(
              title: 'Horario de preferencia · Franja',
              options: PlayerPreferenceCatalog.availabilityTimePreferences,
              selectedValues: availabilityTimeValues,
              enabled: !_saving,
              onChanged: (v) => setState(
                () => _availability = PlayerPreferenceCatalog
                    .mergeAvailabilityValues(
                  dayValues: availabilityDayValues,
                  timeValues: v,
                ),
              ),
            ),
            const SizedBox(height: 14),
            PreferenceCheckboxGroup(
              title: 'Modalidad de juego',
              options: PlayerPreferenceCatalog.matchPreferences,
              selectedValues: _match,
              enabled: !_saving,
              onChanged: (v) => setState(() => _match = v),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Guardando...' : 'Guardar preferencias'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditProfileSheet extends StatefulWidget {
  final String initialDisplayName;
  final String? initialAvatarUrl;
  final Future<bool> Function(Map<String, dynamic> payload) onSave;

  const _EditProfileSheet({
    required this.initialDisplayName,
    required this.initialAvatarUrl,
    required this.onSave,
  });

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late final TextEditingController _displayNameCtrl;
  late final TextEditingController _newPasswordCtrl;
  late final TextEditingController _confirmPasswordCtrl;
  String? _avatarUrl;
  bool _saving = false;
  bool _pickingImage = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    _displayNameCtrl = TextEditingController(text: widget.initialDisplayName);
    _newPasswordCtrl = TextEditingController();
    _confirmPasswordCtrl = TextEditingController();
    _avatarUrl = widget.initialAvatarUrl;
  }

  @override
  void dispose() {
    _displayNameCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    setState(() => _pickingImage = true);
    try {
      final imageDataUrl = await pickProfileImageAsDataUrl();
      if (imageDataUrl == null) {
        return;
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _avatarUrl = imageDataUrl;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo cargar la foto: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _pickingImage = false);
      }
    }
  }

  Future<void> _save() async {
    final displayName = _displayNameCtrl.text.trim();
    final newPassword = _newPasswordCtrl.text;
    final confirmPassword = _confirmPasswordCtrl.text;

    if (displayName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El nombre público no puede estar vacío'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    if (newPassword.isNotEmpty && newPassword.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La nueva contraseña debe tener al menos 6 caracteres'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    if (newPassword != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La confirmación de contraseña no coincide'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    setState(() => _saving = true);
    final didSave = await widget.onSave({
      'display_name': displayName,
      'avatar_url': (_avatarUrl ?? '').trim(),
      if (newPassword.isNotEmpty) 'new_password': newPassword,
    });
    if (!mounted) {
      return;
    }
    setState(() => _saving = false);
    if (didSave) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: FractionallySizedBox(
        heightFactor: 0.76,
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 12, 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Editar perfil',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _saving || _pickingImage ? null : _save,
                      child: Text(
                        _saving ? 'Guardando...' : 'Guardar',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      onPressed: _saving
                          ? null
                          : () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.close, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  children: [
                    Center(
                      child: Column(
                        children: [
                          UserAvatar(
                            displayName: _displayNameCtrl.text.trim().isEmpty
                                ? widget.initialDisplayName
                                : _displayNameCtrl.text.trim(),
                            avatarUrl: _avatarUrl,
                            size: 96,
                            fontSize: 30,
                            backgroundColor: AppColors.surface2,
                            borderColor: AppColors.border,
                          ),
                          const SizedBox(height: 14),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 10,
                            runSpacing: 8,
                            children: [
                              OutlinedButton.icon(
                                onPressed: _saving || _pickingImage
                                    ? null
                                    : _pickAvatar,
                                icon: Icon(
                                  _pickingImage
                                      ? Icons.hourglass_top
                                      : Icons.photo_library_outlined,
                                ),
                                label: Text(
                                  _pickingImage
                                      ? 'Abriendo galería...'
                                      : 'Elegir foto',
                                ),
                              ),
                              if ((_avatarUrl ?? '').isNotEmpty)
                                TextButton(
                                  onPressed: _saving
                                      ? null
                                      : () => setState(() => _avatarUrl = ''),
                                  child: const Text('Quitar foto'),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _displayNameCtrl,
                      style: const TextStyle(color: Colors.white),
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Nombre público',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Modificar contraseña',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Déjala vacía si no quieres cambiarla.',
                      style: TextStyle(
                        color: AppColors.muted,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _newPasswordCtrl,
                      obscureText: _obscurePassword,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Nueva contraseña',
                        suffixIcon: IconButton(
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: AppColors.muted,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _confirmPasswordCtrl,
                      obscureText: _obscureConfirmPassword,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Confirmar contraseña',
                        suffixIcon: IconButton(
                          onPressed: () => setState(
                            () => _obscureConfirmPassword =
                                !_obscureConfirmPassword,
                          ),
                          icon: Icon(
                            _obscureConfirmPassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: AppColors.muted,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _saving
                            ? null
                            : () => Navigator.of(context).maybePop(),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _saving ? null : _save,
                        child: Text(
                          _saving ? 'Guardando...' : 'Guardar cambios',
                        ),
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

class _ProfileMetric extends StatelessWidget {
  final String label;
  final String value;

  const _ProfileMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Text(
            value,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _ProfileGroup extends StatelessWidget {
  final List<Widget> children;

  const _ProfileGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(children: children),
    );
  }
}

class _ProfileActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool danger;
  final VoidCallback onTap;

  const _ProfileActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.danger : Colors.white;
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Icon(icon, color: danger ? AppColors.danger : AppColors.primary),
      title: Text(
        title,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: AppColors.muted),
      ),
      trailing: Icon(
        isCupertinoPlatform
            ? CupertinoIcons.chevron_right
            : Icons.chevron_right,
        color: AppColors.muted,
      ),
    );
  }
}

int? _asInt(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}
