import 'package:flutter/material.dart';
import '../../data/auth_service.dart';
import '../../models/user_model.dart';

class AuthController extends ChangeNotifier {
  final AuthService _authService;

  AuthController({AuthService? authService})
      : _authService = authService ?? AuthService();

  // Estados
  bool _isLoading = false;
  String? _errorMessage;
  bool _isAdminRestricted = false;
  UserRole _selectedSimulatedRole = UserRole.client;
  UserModel? _currentUser;

  // Getters
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAdminRestricted => _isAdminRestricted;
  UserRole get selectedSimulatedRole => _selectedSimulatedRole;
  UserModel? get currentUser => _currentUser;

  /// Cambia el rol simulado (Cliente / Admin) en la UI
  void setSimulatedRole(UserRole role) {
    _selectedSimulatedRole = role;
    _errorMessage = null;
    notifyListeners();
  }

  /// Limpia los errores acumulados
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Cierra el modal de restricción de administrador y limpia estados
  void clearAdminRestriction() {
    _isAdminRestricted = false;
    _errorMessage = null;
    notifyListeners();
  }

  /// Inicio de sesión con Correo y Contraseña
  Future<bool> loginWithEmail({
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    _errorMessage = null;
    _isAdminRestricted = false;

    try {
      // ----------------------------------------------------------------------
      // MODO SIMULADO (Sin Firebase por ahora)
      // ----------------------------------------------------------------------
      final userModel = await _authService.signInWithEmailAndPasswordSimulated(
        email: email,
        password: password,
        simulatedRole: _selectedSimulatedRole,
      );

      // Verificación de Rol y Detección de Administrador en la app móvil
      if (userModel.role == UserRole.admin) {
        _isAdminRestricted = true;
        _setLoading(false);
        return false;
      }

      // Permite acceso a clientes
      _currentUser = userModel;
      _setLoading(false);
      return true;

      /* ----------------------------------------------------------------------
      // IMPLEMENTACIÓN REAL DE FIREBASE (Descomentar cuando Firebase esté activo)
      // ----------------------------------------------------------------------
      final credential = await _authService.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = credential.user?.uid;
      if (uid == null) {
        throw Exception('No se obtuvo el identificador de usuario.');
      }

      UserModel userModel = await _authService.getUserRole(uid);

      if (email.contains('admin') || _selectedSimulatedRole == UserRole.admin) {
        userModel = UserModel(
          uid: uid,
          email: email,
          displayName: userModel.displayName ?? 'Administrador',
          photoUrl: userModel.photoUrl,
          role: UserRole.admin,
        );
      }

      if (userModel.role == UserRole.admin) {
        await _authService.signOut();
        _isAdminRestricted = true;
        _setLoading(false);
        return false;
      }

      _currentUser = userModel;
      _setLoading(false);
      return true;
      ---------------------------------------------------------------------- */
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _setLoading(false);
      return false;
    }
  }

  /// Inicio de sesión con Google
  Future<bool> loginWithGoogle() async {
    _setLoading(true);
    _errorMessage = null;
    _isAdminRestricted = false;

    try {
      // ----------------------------------------------------------------------
      // MODO SIMULADO (Sin Firebase por ahora)
      // ----------------------------------------------------------------------
      final userModel = await _authService.signInWithGoogleSimulated(
        simulatedRole: _selectedSimulatedRole,
      );

      if (userModel.role == UserRole.admin) {
        _isAdminRestricted = true;
        _setLoading(false);
        return false;
      }

      _currentUser = userModel;
      _setLoading(false);
      return true;

      /* ----------------------------------------------------------------------
      // IMPLEMENTACIÓN REAL DE FIREBASE (Descomentar cuando Firebase esté activo)
      // ----------------------------------------------------------------------
      final credential = await _authService.signInWithGoogle();
      final uid = credential.user?.uid;

      if (uid == null) {
        throw Exception('Error al obtener usuario de Google.');
      }

      UserModel userModel = await _authService.getUserRole(uid);

      if (_selectedSimulatedRole == UserRole.admin) {
        userModel = UserModel(
          uid: uid,
          email: credential.user?.email ?? '',
          displayName: credential.user?.displayName,
          photoUrl: credential.user?.photoURL,
          role: UserRole.admin,
        );
      }

      if (userModel.role == UserRole.admin) {
        await _authService.signOut();
        _isAdminRestricted = true;
        _setLoading(false);
        return false;
      }

      _currentUser = userModel;
      _setLoading(false);
      return true;
      ---------------------------------------------------------------------- */
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _setLoading(false);
      return false;
    }
  }

  /// Cierra sesión de usuario
  Future<void> logout() async {
    await _authService.signOut();
    _currentUser = null;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
