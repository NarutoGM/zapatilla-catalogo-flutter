import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../controllers/auth_controller.dart';

class LoginForm extends StatefulWidget {
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final VoidCallback onLoginSuccess;

  const LoginForm({
    super.key,
    required this.emailController,
    required this.passwordController,
    required this.onLoginSuccess,
  });

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool _obscurePassword = true;
  bool _sendingPasswordReset = false;

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: isError ? AppColors.error : null,
        ),
      );
  }

  Future<void> _submitLogin() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    FocusScope.of(context).unfocus();

    try {
      final authController = context.read<AuthController>();
      final success = await authController.loginWithEmail(
        email: widget.emailController.text.trim(),
        password: widget.passwordController.text,
      );

      if (!mounted) return;

      if (success) {
        widget.onLoginSuccess();
      }
      // Los errores de autenticación se muestran desde AuthController.
    } catch (_) {
      _showMessage(
        'No se pudo iniciar sesión. Inténtalo nuevamente.',
        isError: true,
      );
    }
  }

  Future<void> _submitGoogleLogin() async {
    FocusScope.of(context).unfocus();

    try {
      final authController = context.read<AuthController>();
      final success = await authController.loginWithGoogle();

      if (!mounted) return;

      if (success) {
        widget.onLoginSuccess();
      }
      // Los errores de autenticación se muestran desde AuthController.
    } catch (_) {
      _showMessage(
        'No se pudo iniciar sesión con Google. Verifica la configuración e inténtalo otra vez.',
        isError: true,
      );
    }
  }

  Future<void> _resetPassword() async {
    final email = widget.emailController.text.trim();

    if (email.isEmpty) {
      _showMessage(
        'Escribe tu correo electrónico para recuperar la contraseña.',
        isError: true,
      );
      return;
    }

    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      _showMessage(
        'Ingresa un correo electrónico válido.',
        isError: true,
      );
      return;
    }

    setState(() => _sendingPasswordReset = true);
    FocusScope.of(context).unfocus();

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

      if (!mounted) return;
      _showMessage(
        'Si existe una cuenta asociada, recibirás instrucciones para recuperar tu contraseña.',
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      // Evita revelar innecesariamente si una dirección está registrada.
      if (e.code == 'invalid-email') {
        _showMessage('El correo electrónico no es válido.', isError: true);
      } else if (e.code == 'too-many-requests') {
        _showMessage(
          'Se realizaron demasiados intentos. Espera un momento e inténtalo de nuevo.',
          isError: true,
        );
      } else {
        _showMessage(
          'No se pudo enviar el correo de recuperación. Comprueba la configuración de Firebase e inténtalo otra vez.',
          isError: true,
        );
      }
    } catch (_) {
      if (!mounted) return;
      _showMessage(
        'Ocurrió un error al solicitar la recuperación de contraseña.',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _sendingPasswordReset = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authController = context.watch<AuthController>();
    final isLoading = authController.isLoading;
    final errorMessage = authController.errorMessage;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Iniciar Sesión',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 20),

            if (errorMessage != null && errorMessage.trim().isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.error.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: AppColors.error,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        errorMessage,
                        style: const TextStyle(
                          color: AppColors.error,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            const Text(
              'Correo electrónico *',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: widget.emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autocorrect: false,
              enabled: !isLoading && !_sendingPasswordReset,
              decoration: const InputDecoration(
                hintText: 'cliente@pizzo.com',
                prefixIcon: Icon(
                  Icons.email_outlined,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
              ),
              validator: (value) {
                final email = value?.trim() ?? '';

                if (email.isEmpty) {
                  return 'Ingresa tu correo electrónico.';
                }

                if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                    .hasMatch(email)) {
                  return 'Ingresa un correo electrónico válido.';
                }

                return null;
              },
            ),
            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Contraseña *',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                TextButton(
                  onPressed: isLoading || _sendingPasswordReset
                      ? null
                      : _resetPassword,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    _sendingPasswordReset
                        ? 'Enviando...'
                        : '¿Olvidaste tu contraseña?',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryLight,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: widget.passwordController,
              obscureText: _obscurePassword,
              enabled: !isLoading && !_sendingPasswordReset,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) {
                if (!isLoading) _submitLogin();
              },
              decoration: InputDecoration(
                hintText: '••••••••',
                prefixIcon: const Icon(
                  Icons.lock_outline,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
                suffixIcon: IconButton(
                  tooltip: _obscurePassword
                      ? 'Mostrar contraseña'
                      : 'Ocultar contraseña',
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Ingresa tu contraseña.';
                }

                if (value.length < 6) {
                  return 'La contraseña debe tener al menos 6 caracteres.';
                }

                return null;
              },
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: isLoading || _sendingPasswordReset
                    ? null
                    : _submitLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryLight,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                  AppColors.primaryLight.withOpacity(0.6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: isLoading
                    ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
                    : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Entrar',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 20,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            Row(
              children: [
                const Expanded(
                  child: Divider(
                    color: AppColors.border,
                    thickness: 1,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'O CONTINÚA CON',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                      color: AppColors.textSecondary.withOpacity(0.8),
                    ),
                  ),
                ),
                const Expanded(
                  child: Divider(
                    color: AppColors.border,
                    thickness: 1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton(
                onPressed: isLoading || _sendingPasswordReset
                    ? null
                    : _submitGoogleLogin,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(
                    color: AppColors.border,
                    width: 1.2,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GoogleLogo(size: 20),
                    SizedBox(width: 10),
                    Text(
                      'Continuar con Google',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Logo multicolor de Google.
/// Usa la imagen oficial y muestra una alternativa si no hay conexión.
class GoogleLogo extends StatelessWidget {
  final double size;

  const GoogleLogo({super.key, this.size = 20});

  @override
  Widget build(BuildContext context) {
    return Image.network(
      'https://developers.google.com/identity/images/g-logo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return Icon(
          Icons.g_mobiledata,
          size: size + 4,
          color: const Color(0xFF4285F4),
        );
      },
    );
  }
}