import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/user_model.dart';
import '../models/zapatilla.dart';

/// Excepción legible para errores de la API.
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  const ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

/// Servicio HTTP conectado al backend NestJS (`zapatilla-catalogo-back`).
///
/// Detecta automáticamente si corre en emulador Android (`http://10.0.2.2:3001`)
/// o en web/escritorio (`http://localhost:3001`), y permite sobreescribir `baseUrl`.
class ApiService {
  String _baseUrl;
  String? _accessToken;

  ApiService({String? baseUrl, String? accessToken})
      : _baseUrl = baseUrl ?? defaultBaseUrl,
        _accessToken = accessToken;

  static String get defaultBaseUrl {
    if (kIsWeb) return 'http://localhost:3001';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3001';
    }
    return 'http://localhost:3001';
  }

  String get baseUrl => _baseUrl;
  set baseUrl(String value) => _baseUrl = value;

  String? get accessToken => _accessToken;
  void setAccessToken(String? token) => _accessToken = token;

  Map<String, String> _headers({bool jsonBody = true}) {
    return {
      if (jsonBody) 'Content-Type': 'application/json',
      if (_accessToken != null && _accessToken!.isNotEmpty)
        'Authorization': 'Bearer $_accessToken',
    };
  }

  // ===========================================================================
  // 1. AUTENTICACIÓN (/auth)
  // ===========================================================================

  /// `POST /auth/login`
  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    final uri = Uri.parse('$_baseUrl/auth/login');
    final response = await http.post(
      uri,
      headers: _headers(),
      body: jsonEncode({'email': email, 'password': password}),
    );

    final data = _decodeBody(response);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final auth = AuthResponse.fromJson(data as Map<String, dynamic>);
      _accessToken = auth.accessToken;
      return auth;
    }
    throw ApiException(
      _extractErrorMessage(data, 'Error al iniciar sesión'),
      statusCode: response.statusCode,
    );
  }

  /// `POST /auth/register`
  Future<AuthResponse> register({
    required String nombre,
    required String email,
    required String password,
    String? telefono,
  }) async {
    final uri = Uri.parse('$_baseUrl/auth/register');
    final response = await http.post(
      uri,
      headers: _headers(),
      body: jsonEncode({
        'nombre': nombre,
        'email': email,
        'password': password,
        if (telefono != null && telefono.isNotEmpty) 'telefono': telefono,
      }),
    );

    final data = _decodeBody(response);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final auth = AuthResponse.fromJson(data as Map<String, dynamic>);
      _accessToken = auth.accessToken;
      return auth;
    }
    throw ApiException(
      _extractErrorMessage(data, 'Error al registrar usuario'),
      statusCode: response.statusCode,
    );
  }

  // ===========================================================================
  // 2. CATÁLOGO DE ZAPATILLAS (/zapatillas)
  // ===========================================================================

  /// `GET /zapatillas` (o `GET /zapatillas?all=true` para admin)
  Future<List<Zapatilla>> getZapatillas({bool includeInactive = false}) async {
    final query = includeInactive ? '?all=true' : '';
    final uri = Uri.parse('$_baseUrl/zapatillas$query');
    final response = await http.get(uri, headers: _headers(jsonBody: false));

    final data = _decodeBody(response);
    if (response.statusCode >= 200 && response.statusCode < 300 && data is List) {
      return data
          .whereType<Map<String, dynamic>>()
          .map(Zapatilla.fromJson)
          .toList();
    }
    throw ApiException(
      _extractErrorMessage(data, 'No se pudo cargar el catálogo de zapatillas'),
      statusCode: response.statusCode,
    );
  }

  /// `GET /zapatillas/:id`
  Future<Zapatilla> getZapatillaById(String id) async {
    final uri = Uri.parse('$_baseUrl/zapatillas/$id');
    final response = await http.get(uri, headers: _headers(jsonBody: false));

    final data = _decodeBody(response);
    if (response.statusCode >= 200 &&
        response.statusCode < 300 &&
        data is Map<String, dynamic>) {
      return Zapatilla.fromJson(data);
    }
    throw ApiException(
      _extractErrorMessage(data, 'No se encontró la zapatilla solicitada'),
      statusCode: response.statusCode,
    );
  }

  // ===========================================================================
  // Helpers privados
  // ===========================================================================

  dynamic _decodeBody(http.Response response) {
    if (response.bodyBytes.isEmpty) return null;
    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      return response.body;
    }
  }

  String _extractErrorMessage(dynamic data, String fallback) {
    if (data is Map<String, dynamic>) {
      final msg = data['message'];
      if (msg is List && msg.isNotEmpty) {
        return msg.join(', ');
      }
      if (msg is String && msg.isNotEmpty) {
        return msg;
      }
    }
    return fallback;
  }
}
