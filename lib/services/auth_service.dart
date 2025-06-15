import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Flujo de estado de autenticación
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Iniciar sesión con correo y contraseña
  Future<UserCredential?> signInWithEmailAndPassword(
      String email, String password) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Registrar nuevo usuario con correo y contraseña
  Future<UserCredential?> registerWithEmailAndPassword(
      String email, String password) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Iniciar sesión con Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Iniciar el flujo de autenticación de Google
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw FirebaseAuthException(
          code: 'sign_in_canceled',
          message: 'El inicio de sesión fue cancelado por el usuario',
        );
      }

      // Obtener los detalles de autenticación
      final GoogleSignInAuthentication googleAuth = 
          await googleUser.authentication;

      // Verificar que tengamos tanto el token de acceso como el ID
      if (googleAuth.accessToken == null || googleAuth.idToken == null) {
        throw FirebaseAuthException(
          code: 'missing_auth_tokens',
          message: 'No se pudieron obtener los tokens de autenticación',
        );
      }

      // Crear una credencial con Google
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Iniciar sesión en Firebase con la credencial de Google
      return await _auth.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw FirebaseAuthException(
        code: 'sign_in_failed',
        message: 'Error al iniciar sesión con Google: ${e.toString()}',
      );
    }
  }

  // Cerrar sesión
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (e) {
      throw FirebaseAuthException(
        code: 'sign_out_failed',
        message: 'Error al cerrar sesión: ${e.toString()}',
      );
    }
  }

  // Restablecer contraseña
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Obtener usuario actual
  User? get currentUser => _auth.currentUser;

  // Manejador de errores de autenticación
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No se encontró un usuario con este correo.';
      case 'wrong-password':
        return 'Contraseña incorrecta.';
      case 'email-already-in-use':
        return 'Este correo ya está en uso.';
      case 'invalid-email':
        return 'El correo electrónico no es válido.';
      case 'weak-password':
        return 'La contraseña es demasiado débil.';
      case 'user-disabled':
        return 'Esta cuenta ha sido deshabilitada.';
      case 'too-many-requests':
        return 'Demasiados intentos. Por favor, inténtalo de nuevo más tarde.';
      case 'operation-not-allowed':
        return 'Esta operación no está permitida.';
      case 'account-exists-with-different-credential':
        return 'Ya existe una cuenta con el mismo correo pero con credenciales diferentes.';
      case 'invalid-credential':
        return 'Credenciales inválidas.';
      case 'invalid-verification-code':
        return 'Código de verificación inválido.';
      case 'invalid-verification-id':
        return 'ID de verificación inválido.';
      default:
        return 'Ocurrió un error inesperado. Por favor, inténtalo de nuevo.';
    }
  }
}
