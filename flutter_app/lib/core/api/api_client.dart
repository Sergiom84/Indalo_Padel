import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../storage/secure_storage.dart';

const String _configuredBaseUrl = String.fromEnvironment('API_BASE_URL');
const int _defaultApiPort = 3011;

String? resolveBaseUrl() {
  if (_configuredBaseUrl.trim().isNotEmpty) {
    return _normalizeBaseUrl(_configuredBaseUrl);
  }

  final localWebBaseUrl = _resolveLocalWebBaseUrl();
  if (localWebBaseUrl != null) {
    return localWebBaseUrl;
  }

  if (kReleaseMode) {
    // Sin --dart-define=API_BASE_URL explícito, fallback a la URL de producción.
    // Permite flutter run --release / flutter run -d Chrome --release sin flags extra.
    return 'https://indalo-padel.onrender.com/api';
  }

  if (kIsWeb ||
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux) {
    return 'http://localhost:$_defaultApiPort/api';
  }

  if (defaultTargetPlatform == TargetPlatform.android) {
    return 'http://10.0.2.2:$_defaultApiPort/api';
  }

  return 'http://localhost:$_defaultApiPort/api';
}

String? _resolveLocalWebBaseUrl() {
  if (!kIsWeb) {
    return null;
  }

  final host = Uri.base.host;
  if (!_isLocalWebHost(host)) {
    return null;
  }

  final scheme = Uri.base.scheme.isNotEmpty ? Uri.base.scheme : 'http';
  return '$scheme://$host:$_defaultApiPort/api';
}

bool _isLocalWebHost(String host) {
  if (host.isEmpty) {
    return false;
  }

  final normalized = host.trim().toLowerCase();
  if (normalized == 'localhost' || normalized == '127.0.0.1') {
    return true;
  }

  return normalized == '::1';
}

String _normalizeBaseUrl(String baseUrl) {
  final trimmed = baseUrl.trim();
  final uri = Uri.tryParse(trimmed);
  if (uri == null || uri.scheme.isEmpty || uri.host.isEmpty) {
    return trimmed;
  }

  final normalizedPath = uri.path == '/' || uri.path.isEmpty
      ? '/api'
      : uri.path.replaceFirst(RegExp(r'/+$'), '');

  return uri.replace(path: normalizedPath).toString();
}

class ApiClient {
  late final Dio _dio;
  final String? _baseUrl;

  void Function()? onUnauthorized;

  ApiClient() : _baseUrl = resolveBaseUrl() {
    _dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl ?? '',
        // Render free tier puede tardar 30-60s en despertar tras un cold start.
        // Mantenemos timeouts generosos para tolerarlo sin abortar la primera
        // petición tras periodos de inactividad.
        connectTimeout: const Duration(seconds: 60),
        receiveTimeout: const Duration(seconds: 90),
        sendTimeout: const Duration(seconds: 60),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    if (_baseUrl == null) {
      debugPrint(
        'API_BASE_URL no configurada para release. '
        'La app no podra conectar hasta recompilar con --dart-define.',
      );
    } else {
      debugPrint('Usando API base URL: $_baseUrl');
    }

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await SecureStorage.getToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          if (_isAuthFailure(error)) {
            await SecureStorage.clearAll();
            onUnauthorized?.call();
          }
          handler.next(error);
        },
      ),
    );
  }

  Future<dynamic> get(String path,
      {Map<String, dynamic>? queryParameters}) async {
    _ensureBaseUrlConfigured();
    try {
      final response = await _dio.get(path, queryParameters: queryParameters);
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<dynamic> post(String path, {dynamic data}) async {
    _ensureBaseUrlConfigured();
    try {
      final response = await _dio.post(path, data: data);
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<dynamic> put(String path, {dynamic data}) async {
    _ensureBaseUrlConfigured();
    try {
      final response = await _dio.put(path, data: data);
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<dynamic> delete(String path, {dynamic data}) async {
    _ensureBaseUrlConfigured();
    try {
      final response = await _dio.delete(path, data: data);
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  void _ensureBaseUrlConfigured() {
    if (_baseUrl != null && _baseUrl!.isNotEmpty) {
      return;
    }

    throw const ApiConfigurationException(
      'API_BASE_URL no configurada. '
      'Para builds custom usa --dart-define=API_BASE_URL=https://TU_API/api',
    );
  }

  Exception _handleError(DioException e) {
    final data = e.response?.data;
    String message = 'Error de conexión';
    if (data is Map && data['error'] != null) {
      message = data['error'].toString();
    } else if (e.message != null) {
      message = e.message!;
    }
    return ApiException(message, statusCode: e.response?.statusCode);
  }

  bool _isAuthFailure(DioException error) {
    final status = error.response?.statusCode;
    if (status == 401) {
      return true;
    }

    if (status != 403) {
      return false;
    }

    final data = error.response?.data;
    if (data is! Map) {
      return false;
    }

    final code = data['code']?.toString();
    if (code == 'TOKEN_EXPIRED' || code == 'INVALID_TOKEN') {
      return true;
    }

    final message = data['error']?.toString().toLowerCase();
    return message == 'token invalido' ||
        message == 'token inválido' ||
        message == 'token expirado';
  }
}

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  const ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class ApiConfigurationException implements Exception {
  final String message;
  const ApiConfigurationException(this.message);

  @override
  String toString() => message;
}

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());
