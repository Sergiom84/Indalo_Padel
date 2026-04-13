import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_client.dart';
import '../../../core/platform/platform_helper.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/current_profile_provider.dart';
import '../../../shared/widgets/adaptive_pickers.dart';
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
  List<String> _courtPreferences = const [];
  List<String> _dominantHands = const [];
  List<String> _availabilityPreferences = const [];
  List<String> _matchPreferences = const [];
  String? _gender;
  String? _birthDate;
  String? _phone;

  void _syncProfileState(Map<String, dynamic> profile) {
    _profile = profile;
    _courtPreferences = PlayerPreferenceCatalog.parseValues(
      profile['court_preferences'],
    );
    _dominantHands = PlayerPreferenceCatalog.parseValues(
      profile['dominant_hands'],
    );
    _availabilityPreferences = PlayerPreferenceCatalog.parseValues(
      profile['availability_preferences'],
    );
    _matchPreferences = PlayerPreferenceCatalog.parseValues(
      profile['match_preferences'],
    );
    _gender = _nullableString(profile['gender']);
    _birthDate = _nullableString(profile['birth_date']);
    _phone = _nullableString(profile['phone']);
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
      setState(() {
        _syncProfileState(Map<String, dynamic>.from(data['profile'] as Map));
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
        _syncProfileState({
          ...?_profile,
          ...incoming,
          if (_profile?['nombre'] != null) 'nombre': _profile!['nombre'],
          if (_profile?['email'] != null) 'email': _profile!['email'],
        });
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
          initialAvatarUrl: profile['avatar_url']?.toString(),
          initialGender: _gender,
          initialBirthDate: _birthDate,
          initialPhone: _phone,
          onSave: _updateProfile,
        );
      },
    );
  }

  Future<void> _openPreferencesSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _PreferencesSheet(
          initialCourtPreferences: _courtPreferences,
          initialDominantHands: _dominantHands,
          initialAvailabilityPreferences: _availabilityPreferences,
          initialMatchPreferences: _matchPreferences,
          onSave: _updateProfile,
        );
      },
    );
  }

  Future<void> _deleteProfile(String reason) async {
    setState(() => _saving = true);

    try {
      final api = ref.read(apiClientProvider);
      final data = await api.delete(
        '/padel/players/profile',
        data: {'reason': reason},
      );
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            (data['message'] ?? 'Perfil eliminado correctamente').toString(),
          ),
        ),
      );
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

  Future<void> _openDeleteProfileSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _DeleteProfileSheet(
          saving: _saving,
          onDelete: _deleteProfile,
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
    final personalInfo = _buildPersonalInfoItems(
      gender: _gender,
      birthDate: _birthDate,
      phone: _phone,
    );

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
                                    if (personalInfo.isNotEmpty) ...[
                                      const SizedBox(height: 10),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: personalInfo
                                            .map(
                                              (item) => _ProfileInfoChip(
                                                icon: item.icon,
                                                label: item.label,
                                              ),
                                            )
                                            .toList(),
                                      ),
                                    ],
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
                        _ProfileActionTile(
                          icon: isCupertinoPlatform
                              ? CupertinoIcons.pencil_circle
                              : Icons.edit_note,
                          title: 'Editar perfil',
                          subtitle:
                              'Foto, nombre público, datos personales y contraseña.',
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
                              ? CupertinoIcons.delete
                              : Icons.delete_outline,
                          title: 'Eliminar perfil',
                          subtitle:
                              'Selecciona el motivo antes de dar de baja tu cuenta.',
                          danger: true,
                          onTap: _openDeleteProfileSheet,
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
  final String? initialAvatarUrl;
  final String? initialGender;
  final String? initialBirthDate;
  final String? initialPhone;
  final Future<bool> Function(Map<String, dynamic> payload) onSave;

  const _EditProfileSheet({
    required this.initialDisplayName,
    required this.initialAvatarUrl,
    required this.initialGender,
    required this.initialBirthDate,
    required this.initialPhone,
    required this.onSave,
  });

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late final TextEditingController _displayNameCtrl;
  late final TextEditingController _newPasswordCtrl;
  late final TextEditingController _confirmPasswordCtrl;
  late final TextEditingController _phoneCtrl;
  String? _avatarUrl;
  String? _gender;
  DateTime? _birthDate;
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
    _phoneCtrl = TextEditingController(text: widget.initialPhone ?? '');
    _avatarUrl = widget.initialAvatarUrl;
    _gender = widget.initialGender;
    _birthDate = _tryParseDate(widget.initialBirthDate);
  }

  @override
  void dispose() {
    _displayNameCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    _phoneCtrl.dispose();
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

    if (_gender == null || _birthDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El género y la fecha de nacimiento son obligatorios'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    setState(() => _saving = true);
    final didSave = await widget.onSave({
      'display_name': displayName,
      'avatar_url': (_avatarUrl ?? '').trim(),
      'gender': _gender,
      'birth_date': DateFormat('yyyy-MM-dd').format(_birthDate!),
      'phone': _phoneCtrl.text.trim(),
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

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showAdaptiveAppDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(1900, 1, 1),
      lastDate: now,
    );
    if (picked != null && mounted) {
      setState(() => _birthDate = picked);
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
                    DropdownButtonFormField<String>(
                      initialValue: _gender,
                      dropdownColor: AppColors.surface2,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Género',
                      ),
                      hint: const Text(
                        'Selecciona tu género',
                        style: TextStyle(color: AppColors.muted),
                      ),
                      items: PlayerPreferenceCatalog.genderOptions
                          .map(
                            (option) => DropdownMenuItem(
                              value: option.value,
                              child: Text(option.label),
                            ),
                          )
                          .toList(),
                      onChanged: _saving
                          ? null
                          : (value) => setState(() => _gender = value),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: _saving ? null : _pickBirthDate,
                      borderRadius: BorderRadius.circular(12),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Fecha de nacimiento',
                          suffixIcon: Icon(
                            Icons.calendar_today_outlined,
                            color: AppColors.muted,
                            size: 20,
                          ),
                        ),
                        child: Text(
                          _birthDate == null
                              ? 'Selecciona tu fecha de nacimiento'
                              : DateFormat('dd/MM/yyyy').format(_birthDate!),
                          style: TextStyle(
                            color: _birthDate == null
                                ? AppColors.muted
                                : Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Teléfono (opcional)',
                      ),
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

class _PreferencesSheet extends StatefulWidget {
  final List<String> initialCourtPreferences;
  final List<String> initialDominantHands;
  final List<String> initialAvailabilityPreferences;
  final List<String> initialMatchPreferences;
  final Future<bool> Function(Map<String, dynamic> payload) onSave;

  const _PreferencesSheet({
    required this.initialCourtPreferences,
    required this.initialDominantHands,
    required this.initialAvailabilityPreferences,
    required this.initialMatchPreferences,
    required this.onSave,
  });

  @override
  State<_PreferencesSheet> createState() => _PreferencesSheetState();
}

class _PreferencesSheetState extends State<_PreferencesSheet> {
  late List<String> _courtPreferences;
  late List<String> _dominantHands;
  late List<String> _availabilityPreferences;
  late List<String> _matchPreferences;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _courtPreferences = [...widget.initialCourtPreferences];
    _dominantHands = [...widget.initialDominantHands];
    _availabilityPreferences = [...widget.initialAvailabilityPreferences];
    _matchPreferences = [...widget.initialMatchPreferences];
  }

  Future<void> _save() async {
    setState(() => _saving = true);

    final didSave = await widget.onSave({
      'court_preferences': _courtPreferences,
      'dominant_hands': _dominantHands,
      'availability_preferences': _availabilityPreferences,
      'match_preferences': _matchPreferences,
    });

    if (!mounted) {
      return;
    }

    if (didSave) {
      Navigator.of(context).pop();
      return;
    }

    setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 18, 20, 20 + bottomInset),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Preferencias',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Ajusta posición, mano, disponibilidad y modalidad.',
                  style: TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 20),
                PreferenceCheckboxGroup(
                  title: 'Posición en pista',
                  options: PlayerPreferenceCatalog.courtPreferences,
                  selectedValues: _courtPreferences,
                  enabled: !_saving,
                  onChanged: (values) =>
                      setState(() => _courtPreferences = values),
                ),
                const SizedBox(height: 12),
                PreferenceCheckboxGroup(
                  title: 'Preferencia de la mano',
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
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    child: Text(
                      _saving ? 'Guardando...' : 'Guardar preferencias',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DeleteProfileSheet extends StatefulWidget {
  final bool saving;
  final Future<void> Function(String reason) onDelete;

  const _DeleteProfileSheet({
    required this.saving,
    required this.onDelete,
  });

  @override
  State<_DeleteProfileSheet> createState() => _DeleteProfileSheetState();
}

class _DeleteProfileSheetState extends State<_DeleteProfileSheet> {
  String? _selectedReason;

  Future<void> _confirmDelete() async {
    final reason = _selectedReason;
    if (reason == null) {
      return;
    }

    Navigator.of(context).pop();
    await widget.onDelete(reason);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Eliminar perfil',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Nos podrías indicar por qué lo vas a eliminar?',
                style: TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 16),
              RadioGroup<String>(
                groupValue: _selectedReason,
                onChanged: widget.saving
                    ? (_) {}
                    : (value) => setState(() => _selectedReason = value),
                child: Column(
                  children: PlayerPreferenceCatalog.accountDeletionReasons
                      .map(
                        (option) => RadioListTile<String>(
                          value: option.value,
                          enabled: !widget.saving,
                          selected: _selectedReason == option.value,
                          activeColor: AppColors.primary,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            option.label,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
              ),
              if (_selectedReason != null) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonal(
                    onPressed: widget.saving ? null : _confirmDelete,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.danger.withValues(alpha: 0.18),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Eliminar perfil'),
                  ),
                ),
              ],
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

class _ProfileInfoItem {
  final IconData icon;
  final String label;

  const _ProfileInfoItem({
    required this.icon,
    required this.label,
  });
}

class _ProfileInfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _ProfileInfoChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.primary, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

List<_ProfileInfoItem> _buildPersonalInfoItems({
  required String? gender,
  required String? birthDate,
  required String? phone,
}) {
  final items = <_ProfileInfoItem>[];
  final genderLabel = PlayerPreferenceCatalog.labelForGender(gender);

  if (genderLabel.isNotEmpty) {
    items.add(
      _ProfileInfoItem(
        icon: Icons.person_outline,
        label: genderLabel,
      ),
    );
  }

  final parsedBirthDate = _tryParseDate(birthDate);
  if (parsedBirthDate != null) {
    items.add(
      _ProfileInfoItem(
        icon: Icons.cake_outlined,
        label: DateFormat('dd/MM/yyyy').format(parsedBirthDate),
      ),
    );
  }

  final cleanPhone = _nullableString(phone);
  if (cleanPhone != null) {
    items.add(
      _ProfileInfoItem(
        icon: Icons.phone_outlined,
        label: cleanPhone,
      ),
    );
  }

  return items;
}

String? _nullableString(dynamic value) {
  if (value == null) {
    return null;
  }

  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

DateTime? _tryParseDate(String? value) {
  if (value == null || value.trim().isEmpty) {
    return null;
  }

  try {
    return DateTime.parse(value);
  } catch (_) {
    return null;
  }
}
