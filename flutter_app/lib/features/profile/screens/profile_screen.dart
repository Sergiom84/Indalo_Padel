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
import '../../../shared/widgets/padel_badge.dart';
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
      setState(() {
        _profile = Map<String, dynamic>.from(data['profile'] as Map);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) {
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
      setState(() {
        _profile = {
          ...?_profile,
          ...incoming,
          if (_profile?['nombre'] != null) 'nombre': _profile!['nombre'],
          if (_profile?['email'] != null) 'email': _profile!['email'],
        };
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perfil actualizado')),
      );
      ref.invalidate(currentProfileProvider);
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
          initialBio: (profile['bio'] ?? '').toString(),
          initialAvatarUrl: profile['avatar_url']?.toString(),
          initialCourtPreferences: PlayerPreferenceCatalog.parseValues(
            profile['court_preferences'],
          ),
          initialDominantHands: PlayerPreferenceCatalog.parseValues(
            profile['dominant_hands'],
          ),
          initialAvailabilityPreferences: PlayerPreferenceCatalog.parseValues(
            profile['availability_preferences'],
          ),
          initialMatchPreferences: PlayerPreferenceCatalog.parseValues(
            profile['match_preferences'],
          ),
          onSave: _updateProfile,
        );
      },
    );
  }

  Future<void> _logout() async {
    await appMediumImpact();
    await ref.read(authProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context) {
    final authUser = ref.watch(authProvider).user;
    final profile = _profile ?? <String, dynamic>{};
    final displayName = (profile['display_name'] ??
            profile['nombre'] ??
            authUser?.nombre ??
            'Jugador')
        .toString();
    final email = (profile['email'] ?? authUser?.email ?? '').toString();
    final availability = (profile['is_available'] ?? false) as bool;
    final avatarUrl = profile['avatar_url']?.toString();
    final preferenceSections = _PreferenceSummaryData.fromProfile(profile);

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
                                  value: '${profile['numeric_level'] ?? 0}',
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
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Preferencias de juego',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 14),
                              if (preferenceSections.isEmpty)
                                const Text(
                                  'Aún no has configurado tus preferencias.',
                                  style: TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 14,
                                  ),
                                )
                              else
                                for (var index = 0;
                                    index < preferenceSections.length;
                                    index++) ...[
                                  _PreferenceSummarySection(
                                    title: preferenceSections[index].title,
                                    labels: preferenceSections[index].labels,
                                  ),
                                  if (index < preferenceSections.length - 1)
                                    const SizedBox(height: 14),
                                ],
                            ],
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
                          subtitle: 'Nombre público, bio, foto y preferencias.',
                          onTap: _openEditSheet,
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
                      ],
                    ),
                  ],
                ),
    );
  }
}

class _EditProfileSheet extends StatefulWidget {
  final String initialDisplayName;
  final String initialBio;
  final String? initialAvatarUrl;
  final List<String> initialCourtPreferences;
  final List<String> initialDominantHands;
  final List<String> initialAvailabilityPreferences;
  final List<String> initialMatchPreferences;
  final Future<bool> Function(Map<String, dynamic> payload) onSave;

  const _EditProfileSheet({
    required this.initialDisplayName,
    required this.initialBio,
    required this.initialAvatarUrl,
    required this.initialCourtPreferences,
    required this.initialDominantHands,
    required this.initialAvailabilityPreferences,
    required this.initialMatchPreferences,
    required this.onSave,
  });

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late final TextEditingController _displayNameCtrl;
  late final TextEditingController _bioCtrl;
  late List<String> _courtPreferences;
  late List<String> _dominantHands;
  late List<String> _availabilityPreferences;
  late List<String> _matchPreferences;
  String? _avatarUrl;
  bool _saving = false;
  bool _pickingImage = false;

  @override
  void initState() {
    super.initState();
    _displayNameCtrl = TextEditingController(text: widget.initialDisplayName);
    _bioCtrl = TextEditingController(text: widget.initialBio);
    _courtPreferences = [...widget.initialCourtPreferences];
    _dominantHands = [...widget.initialDominantHands];
    _availabilityPreferences = [...widget.initialAvailabilityPreferences];
    _matchPreferences = [...widget.initialMatchPreferences];
    _avatarUrl = widget.initialAvatarUrl;
  }

  @override
  void dispose() {
    _displayNameCtrl.dispose();
    _bioCtrl.dispose();
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
    if (displayName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El nombre público no puede estar vacío'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    setState(() => _saving = true);
    final didSave = await widget.onSave({
      'display_name': displayName,
      'bio': _bioCtrl.text.trim(),
      'avatar_url': (_avatarUrl ?? '').trim(),
      'court_preferences': _courtPreferences,
      'dominant_hands': _dominantHands,
      'availability_preferences': _availabilityPreferences,
      'match_preferences': _matchPreferences,
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
        heightFactor: 0.9,
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
                    const SizedBox(height: 12),
                    PreferenceCheckboxGroup(
                      title: 'Preferencia en pista',
                      options: PlayerPreferenceCatalog.courtPreferences,
                      selectedValues: _courtPreferences,
                      enabled: !_saving,
                      onChanged: (values) =>
                          setState(() => _courtPreferences = values),
                    ),
                    const SizedBox(height: 12),
                    PreferenceCheckboxGroup(
                      title: 'Perfil del jugador',
                      options: PlayerPreferenceCatalog.dominantHands,
                      selectedValues: _dominantHands,
                      enabled: !_saving,
                      onChanged: (values) =>
                          setState(() => _dominantHands = values),
                    ),
                    const SizedBox(height: 12),
                    PreferenceCheckboxGroup(
                      title: 'Disponibilidad horaria',
                      options: PlayerPreferenceCatalog.availabilityPreferences,
                      selectedValues: _availabilityPreferences,
                      enabled: !_saving,
                      onChanged: (values) =>
                          setState(() => _availabilityPreferences = values),
                    ),
                    const SizedBox(height: 12),
                    PreferenceCheckboxGroup(
                      title: 'Modalidad de juego',
                      options: PlayerPreferenceCatalog.matchPreferences,
                      selectedValues: _matchPreferences,
                      enabled: !_saving,
                      onChanged: (values) =>
                          setState(() => _matchPreferences = values),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _bioCtrl,
                      maxLines: 5,
                      minLines: 4,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Bio',
                        hintText: 'Cuéntale a otros jugadores cómo juegas.',
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

class _PreferenceSummaryData {
  final String title;
  final List<String> labels;

  const _PreferenceSummaryData({
    required this.title,
    required this.labels,
  });

  static List<_PreferenceSummaryData> fromProfile(
    Map<String, dynamic> profile,
  ) {
    return PlayerPreferenceCatalog.sections
        .map(
          (section) => _PreferenceSummaryData(
            title: section.title,
            labels: PlayerPreferenceCatalog.labelsForValues(
              PlayerPreferenceCatalog.parseValues(profile[section.field]),
            ),
          ),
        )
        .where((section) => section.labels.isNotEmpty)
        .toList(growable: false);
  }
}

class _PreferenceSummarySection extends StatelessWidget {
  final String title;
  final List<String> labels;

  const _PreferenceSummarySection({
    required this.title,
    required this.labels,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
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
            for (final label in labels)
              PadelBadge(
                label: label,
                variant: PadelBadgeVariant.outline,
              ),
          ],
        ),
      ],
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
