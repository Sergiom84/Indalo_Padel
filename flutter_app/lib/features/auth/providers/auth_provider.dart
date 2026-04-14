import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/storage/secure_storage.dart';

// ---------------------------------------------------------------------------
// User model
// ---------------------------------------------------------------------------
class UserModel {
  final int id;
  final String email;
  final String nombre;

  const UserModel({
    required this.id,
    required this.email,
    required this.nombre,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as int? ?? 0,
      email: json['email'] as String? ?? '',
      nombre: (json['nombre'] ?? json['name'] ?? '') as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'nombre': nombre,
      };
}

// ---------------------------------------------------------------------------
// Auth state
// ---------------------------------------------------------------------------
class AuthState {
  final UserModel? user;
  final bool loading;
  final String? error;

  const AuthState({this.user, this.loading = false, this.error});

  bool get isAuthenticated => user != null;

  AuthState copyWith({
    UserModel? user,
    bool? loading,
    String? error,
    bool clearUser = false,
    bool clearError = false,
  }) {
    return AuthState(
      user: clearUser ? null : (user ?? this.user),
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class AuthActionResult {
  final String message;
  final bool emailDeliveryFailed;

  const AuthActionResult({
    required this.message,
    this.emailDeliveryFailed = false,
  });

  factory AuthActionResult.fromJson(Map<String, dynamic> json) {
    return AuthActionResult(
      message: (json['message'] as String?) ?? '',
      emailDeliveryFailed: json['email_delivery_failed'] as bool? ?? false,
    );
  }
}

// ---------------------------------------------------------------------------
// Auth Notifier
// ---------------------------------------------------------------------------
class AuthNotifier extends StateNotifier<AuthState> {
  final ApiClient _api;

  AuthNotifier(this._api) : super(const AuthState(loading: true)) {
    _init();
  }

  Future<void> _init() async {
    final token = await SecureStorage.getToken();
    if (token == null || token.isEmpty) {
      state = const AuthState();
      return;
    }
    try {
      final data = await _api.get('/padel/auth/verify');
      final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);
      await SecureStorage.saveUser(jsonEncode(user.toJson()));
      state = AuthState(user: user);
    } catch (_) {
      await SecureStorage.clearAll();
      state = const AuthState();
    }
  }

  Future<void> login(String email, String password) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final data = await _api.post('/padel/auth/login', data: {
        'email': email,
        'password': password,
      });
      final token = data['token'] as String;
      final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);
      await SecureStorage.saveToken(token);
      await SecureStorage.saveUser(jsonEncode(user.toJson()));
      state = AuthState(user: user);
    } catch (e) {
      state =
          state.copyWith(loading: false, error: e.toString(), clearUser: false);
      rethrow;
    }
  }

  Future<AuthActionResult> register(Map<String, dynamic> userData) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final data = Map<String, dynamic>.from(
        await _api.post('/padel/auth/register', data: userData) as Map,
      );
      state = state.copyWith(loading: false, clearError: true);
      return AuthActionResult.fromJson(data);
    } catch (e) {
      state =
          state.copyWith(loading: false, error: e.toString(), clearUser: false);
      rethrow;
    }
  }

  Future<AuthActionResult> resendVerification(String email) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final data = Map<String, dynamic>.from(
        await _api.post('/padel/auth/resend-verification', data: {
          'email': email,
        }) as Map,
      );
      state = state.copyWith(loading: false, clearError: true);
      return AuthActionResult.fromJson(data);
    } catch (e) {
      state =
          state.copyWith(loading: false, error: e.toString(), clearUser: false);
      rethrow;
    }
  }

  Future<void> logout() async {
    await SecureStorage.clearAll();
    state = const AuthState();
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final api = ref.watch(apiClientProvider);
  return AuthNotifier(api);
});
