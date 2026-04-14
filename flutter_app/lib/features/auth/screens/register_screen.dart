import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/utils/player_preferences.dart';
import '../../../shared/widgets/preference_checkbox_group.dart';
import '../providers/auth_provider.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _nombreCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  String _mainLevel = 'bajo';
  String _subLevel = 'medio';
  List<String> _courtPreferences = const [];
  List<String> _dominantHands = const [];
  List<String> _availabilityPreferences = const [];
  List<String> _matchPreferences = const [];
  bool _loading = false;
  bool _obscurePassword = true;
  String? _error;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_nombreCtrl.text.trim().isEmpty ||
        _emailCtrl.text.trim().isEmpty ||
        _passwordCtrl.text.isEmpty) {
      setState(() => _error = 'Por favor rellena todos los campos');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ref.read(authProvider.notifier).register({
        'nombre': _nombreCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'password': _passwordCtrl.text,
        'main_level': _mainLevel,
        'sub_level': _subLevel,
        'court_preferences': _courtPreferences,
        'dominant_hands': _dominantHands,
        'availability_preferences': _availabilityPreferences,
        'match_preferences': _matchPreferences,
      });

      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text(
            result.emailDeliveryFailed ? 'Cuenta creada' : 'Revisa tu correo',
            style: const TextStyle(color: Colors.white),
          ),
          content: Text(
            result.message,
            style: const TextStyle(color: AppColors.muted),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                context.go('/login');
              },
              child: const Text('Ir al login'),
            ),
          ],
        ),
      );
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> options,
    required void Function(String) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: value,
          dropdownColor: AppColors.surface2,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          items: options
              .map((o) =>
                  DropdownMenuItem(value: o, child: Text(_capitalize(o))))
              .toList(),
          onChanged: (v) => v != null ? onChanged(v) : null,
        ),
      ],
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.dark,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              const Center(
                child: Text(
                  'Crea tu perfil de jugador',
                  style: TextStyle(color: AppColors.muted, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 28),

              // Error
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.danger.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    _error!,
                    style:
                        const TextStyle(color: AppColors.danger, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Nombre
              TextFormField(
                controller: _nombreCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Nombre',
                  prefixIcon: Icon(Icons.person_outline,
                      color: AppColors.muted, size: 20),
                ),
              ),
              const SizedBox(height: 12),

              // Email
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'tu@email.com',
                  prefixIcon: Icon(Icons.mail_outline,
                      color: AppColors.muted, size: 20),
                ),
              ),
              const SizedBox(height: 12),

              // Password
              TextFormField(
                controller: _passwordCtrl,
                obscureText: _obscurePassword,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Contraseña',
                  prefixIcon: const Icon(Icons.lock_outline,
                      color: AppColors.muted, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: AppColors.muted,
                      size: 20,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Level grid
              Row(
                children: [
                  Expanded(
                    child: _buildDropdown(
                      label: 'Nivel',
                      value: _mainLevel,
                      options: const ['bajo', 'medio', 'alto'],
                      onChanged: (v) => setState(() => _mainLevel = v),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildDropdown(
                      label: 'Sub-nivel',
                      value: _subLevel,
                      options: const ['bajo', 'medio', 'alto'],
                      onChanged: (v) => setState(() => _subLevel = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              PreferenceCheckboxGroup(
                title: 'Preferencia en pista',
                options: PlayerPreferenceCatalog.courtPreferences,
                selectedValues: _courtPreferences,
                onChanged: (values) =>
                    setState(() => _courtPreferences = values),
              ),
              const SizedBox(height: 16),

              PreferenceCheckboxGroup(
                title: 'Perfil del jugador',
                options: PlayerPreferenceCatalog.dominantHands,
                selectedValues: _dominantHands,
                onChanged: (values) => setState(() => _dominantHands = values),
              ),
              const SizedBox(height: 16),

              PreferenceCheckboxGroup(
                title: 'Disponibilidad horaria',
                options: PlayerPreferenceCatalog.availabilityPreferences,
                selectedValues: _availabilityPreferences,
                onChanged: (values) =>
                    setState(() => _availabilityPreferences = values),
              ),
              const SizedBox(height: 16),

              PreferenceCheckboxGroup(
                title: 'Modalidad de juego',
                options: PlayerPreferenceCatalog.matchPreferences,
                selectedValues: _matchPreferences,
                onChanged: (values) =>
                    setState(() => _matchPreferences = values),
              ),
              const SizedBox(height: 24),

              // Submit
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.dark),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Crear mi cuenta',
                                style: TextStyle(
                                    fontWeight: FontWeight.w900, fontSize: 15)),
                            SizedBox(width: 8),
                            Icon(Icons.arrow_forward, size: 18),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 20),

              // Login link
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      '¿Ya tienes cuenta? ',
                      style: TextStyle(color: AppColors.muted, fontSize: 14),
                    ),
                    GestureDetector(
                      onTap: () => context.go('/login'),
                      child: const Text(
                        'Inicia sesión',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
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
