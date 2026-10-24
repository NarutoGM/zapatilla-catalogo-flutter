import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
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

  /// Obtiene automáticamente el token JWT de administrador del backend
  /// (`admin@zapatillas.com` / `Admin123*`) si aún no se ha autenticado.
  Future<String> ensureAdminToken() async {
    if (_accessToken != null && _accessToken!.isNotEmpty) {
      return _accessToken!;
    }
    final auth = await login(
      email: 'admin@zapatillas.com',
      password: 'Admin123*',
    );
    return auth.accessToken;
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
  // 2. CATÁLOGO Y ADMINISTRACIÓN DE ZAPATILLAS (/zapatillas)
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

  /// `POST /zapatillas/upload` (Solo ADMIN)
  /// Sube una imagen (`.png`, `.jpg`, `.webp`) o un modelo 3D (`.glb`) a Firebase Storage
  /// y devuelve su URL pública.
  Future<String> uploadFileBytes({
    required Uint8List bytes,
    required String fileName,
  }) async {
    await ensureAdminToken();
    final uri = Uri.parse('$_baseUrl/zapatillas/upload');
    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll(_headers(jsonBody: false));

    final lower = fileName.toLowerCase();
    MediaType contentType;
    if (lower.endsWith('.glb')) {
      contentType = MediaType('model', 'gltf-binary');
    } else if (lower.endsWith('.png')) {
      contentType = MediaType('image', 'png');
    } else if (lower.endsWith('.webp')) {
      contentType = MediaType('image', 'webp');
    } else {
      contentType = MediaType('image', 'jpeg');
    }

    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: fileName,
        contentType: contentType,
      ),
    );

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    final data = _decodeBody(response);

    if (response.statusCode >= 200 &&
        response.statusCode < 300 &&
        data is Map<String, dynamic> &&
        data['url'] is String) {
      return data['url'] as String;
    }

    throw ApiException(
      _extractErrorMessage(data, 'Error al subir archivo a Firebase Storage'),
      statusCode: response.statusCode,
    );
  }

  /// `POST /zapatillas` (Solo ADMIN)
  Future<Zapatilla> createZapatilla(Map<String, dynamic> payload) async {
    await ensureAdminToken();
    final uri = Uri.parse('$_baseUrl/zapatillas');
    final response = await http.post(
      uri,
      headers: _headers(),
      body: jsonEncode(payload),
    );

    final data = _decodeBody(response);
    if (response.statusCode >= 200 &&
        response.statusCode < 300 &&
        data is Map<String, dynamic>) {
      return Zapatilla.fromJson(data);
    }
    throw ApiException(
      _extractErrorMessage(data, 'Error al crear la zapatilla'),
      statusCode: response.statusCode,
    );
  }

  /// `PATCH /zapatillas/:id` (Solo ADMIN)
  Future<Zapatilla> updateZapatilla(
    String id,
    Map<String, dynamic> payload,
  ) async {
    await ensureAdminToken();
    final uri = Uri.parse('$_baseUrl/zapatillas/$id');
    final response = await http.patch(
      uri,
      headers: _headers(),
      body: jsonEncode(payload),
    );

    final data = _decodeBody(response);
    if (response.statusCode >= 200 &&
        response.statusCode < 300 &&
        data is Map<String, dynamic>) {
      return Zapatilla.fromJson(data);
    }
    throw ApiException(
      _extractErrorMessage(data, 'Error al actualizar la zapatilla'),
      statusCode: response.statusCode,
    );
  }

  /// `DELETE /zapatillas/:id` (Solo ADMIN - Soft Delete)
  Future<void> deactivateZapatilla(String id) async {
    await ensureAdminToken();
    final uri = Uri.parse('$_baseUrl/zapatillas/$id');
    final response = await http.delete(uri, headers: _headers(jsonBody: false));

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }
    final data = _decodeBody(response);
    throw ApiException(
      _extractErrorMessage(data, 'Error al desactivar la zapatilla'),
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
