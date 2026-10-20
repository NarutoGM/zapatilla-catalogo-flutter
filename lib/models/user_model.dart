/// Modelo de usuario y respuesta de autenticación alineado con `/auth/login` y `/auth/register`.
class UserModel {
  final String id;
  final String nombre;
  final String email;
  final String rol; // "cliente" | "admin"
  final String? telefono;

  const UserModel({
    required this.id,
    required this.nombre,
    required this.email,
    required this.rol,
    this.telefono,
  });

  bool get isAdmin => rol.toLowerCase() == 'admin';

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: (json['id'] ?? '').toString(),
      nombre: (json['nombre'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      rol: (json['rol'] ?? 'cliente').toString(),
      telefono: json['telefono'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'email': email,
      'rol': rol,
      if (telefono != null) 'telefono': telefono,
    };
  }
}

class AuthResponse {
  final String message;
  final UserModel user;
  final String accessToken;

  const AuthResponse({
    required this.message,
    required this.user,
    required this.accessToken,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      message: (json['message'] ?? '').toString(),
      user: UserModel.fromJson(
        (json['user'] as Map<String, dynamic>?) ?? const {},
      ),
      accessToken: (json['accessToken'] ?? '').toString(),
    );
  }
}
