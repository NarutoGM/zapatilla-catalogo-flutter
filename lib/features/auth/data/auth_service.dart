// TODO: Descomentar importaciones de Firebase cuando el backend esté configurado
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_model.dart';

class AuthService {
  /* ========================================================================
   * IMPLEMENTACIÓN FIREBASE (Comentada para modo simulación / prototipo UI)
   * Descomentar las propiedades y métodos de Firebase cuando se vincule el proyecto.
   * ========================================================================
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  User? get currentUser => _auth.currentUser;
  */

  /// Simulación de inicio de sesión con correo y contraseña
  Future<UserModel> signInWithEmailAndPasswordSimulated({
    required String email,
    required String password,
    required UserRole simulatedRole,
  }) async {
    // Simula retardo de red de backend
    await Future.delayed(const Duration(milliseconds: 600));

    final isEmailAdmin = email.contains('admin') || simulatedRole == UserRole.admin;
    final role = isEmailAdmin ? UserRole.admin : UserRole.client;

    return UserModel(
      uid: 'mock_uid_${DateTime.now().millisecondsSinceEpoch}',
      email: email,
      displayName: role == UserRole.admin ? 'Administrador Pizzo' : 'Cliente Pizzo',
      role: role,
    );
  }

  /// Simulación de inicio de sesión con Google
  Future<UserModel> signInWithGoogleSimulated({
    required UserRole simulatedRole,
  }) async {
    await Future.delayed(const Duration(milliseconds: 800));

    return UserModel(
      uid: 'google_mock_uid_123',
      email: 'cliente.google@pizzo.com',
      displayName: 'Usuario Google Pizzo',
      photoUrl: 'https://via.placeholder.com/150',
      role: simulatedRole,
    );
  }

  /// Cierra la sesión activa
  Future<void> signOut() async {
    /*
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    await _auth.signOut();
    */
    await Future.delayed(const Duration(milliseconds: 200));
  }

  /* ========================================================================
   * MÉTODOS DE FIREBASE REALES (ACTIVAR CUANDO HAYA ACCESO A FIREBASE)
   * ========================================================================

  /// Inicia sesión con correo y contraseña en Firebase
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return credential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('Error inesperado al iniciar sesión: $e');
    }
  }

  /// Inicia sesión con Google
  Future<UserCredential> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw Exception('Inicio de sesión con Google cancelado por el usuario.');
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      return await _auth.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('Error de autenticación con Google: ${e.toString()}');
    }
  }

  /// Obtiene o consulta la información completa y el rol del usuario desde Firestore (`users/{uid}`)
  Future<UserModel> getUserRole(String uid) async {
    try {
      final docSnapshot = await _firestore.collection('users').doc(uid).get();

      if (!docSnapshot.exists || docSnapshot.data() == null) {
        final user = _auth.currentUser;
        return UserModel(
          uid: uid,
          email: user?.email ?? '',
          displayName: user?.displayName,
          photoUrl: user?.photoURL,
          role: UserRole.client,
        );
      }

      return UserModel.fromMap(docSnapshot.data()!, uid);
    } on FirebaseException catch (e) {
      throw Exception('Error al consultar Firestore: ${e.message}');
    } catch (e) {
      throw Exception('No se pudo verificar el rol del usuario: $e');
    }
  }

  /// Manejo estructurado de excepciones de FirebaseAuth
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No existe ninguna cuenta registrada con este correo electrónico.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Contraseña o credenciales incorrectas. Verifique e intente de nuevo.';
      case 'invalid-email':
        return 'El formato del correo electrónico no es válido.';
      case 'user-disabled':
        return 'Esta cuenta de usuario ha sido deshabilitada.';
      case 'network-request-failed':
        return 'Error de conexión a internet. Compruebe su red e reintente.';
      case 'too-many-requests':
        return 'Demasiados intentos fallidos. Intente nuevamente más tarde.';
      default:
        return e.message ?? 'Error de autenticación (${e.code}).';
    }
  }
  */
}
