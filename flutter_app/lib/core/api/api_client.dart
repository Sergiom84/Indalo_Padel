import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../storage/secure_storage.dart';

// Base URL for different environments:
// Android emulator: http://10.0.2.2:3010/api
// iOS simulator / macOS: http://localhost:3010/api
// Real device: replace with LAN IP e.g. http://192.168.1.100:3010/api
const String _baseUrl = 'http://10.0.2.2:3010/api';

class ApiClient {
  late final Dio _dio;

  // Navigator key for redirecting on 401 – injected by app
  void Function()? onUnauthorized;

  ApiClient() {
    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await SecureStorage.getToken();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          await SecureStorage.clearAll();
          onUnauthorized?.call();
        }
        handler.next(error);
      },
    ));
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? queryParameters}) async {
    try {
      final response = await _dio.get(path, queryParameters: queryParameters);
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<dynamic> post(String path, {dynamic data}) async {
    try {
      final response = await _dio.post(path, data: data);
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<dynamic> put(String path, {dynamic data}) async {
    try {
      final response = await _dio.put(path, data: data);
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<dynamic> delete(String path) async {
    try {
      final response = await _dio.delete(path);
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
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
}

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  const ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

// Riverpod provider
final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());
