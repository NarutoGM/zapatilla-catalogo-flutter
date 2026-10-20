import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../controllers/auth_controller.dart';
import '../widgets/admin_dialog.dart';
import '../widgets/header_card.dart';
import '../widgets/login_form.dart';
import '../widgets/role_selector.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: 'cliente@pizzo.com');
    _passwordController = TextEditingController(text: '123456');
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _checkAdminRestriction(AuthController authController) {
    if (authController.isAdminRestricted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        AdminDialog.show(
          context,
          onDismiss: () {
            authController.clearAdminRestriction();
            _passwordController.clear();
          },
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authController = context.watch<AuthController>();

    // Escucha si un admin intentó iniciar sesión
    _checkAdminRestriction(authController);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 450),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Tarjeta de Encabezado Superior (PIZZO VELOCITY)
                  const HeaderCard(),
                  const SizedBox(height: 20),

                  // 2. Simulador / Selector de Rol (Cliente vs Admin)
                  RoleSelector(
                    onRoleChanged: (email, password) {
                      setState(() {
                        _emailController.text = email;
                        _passwordController.text = password;
                      });
                    },
                  ),
                  const SizedBox(height: 20),

                  // 3. Formulario de Iniciar Sesión (Email, Contraseña, Entrar, Google)
                  LoginForm(
                    emailController: _emailController,
                    passwordController: _passwordController,
                    onLoginSuccess: () {
                      Navigator.of(context).pushReplacementNamed('/home');
                    },
                  ),
                  const SizedBox(height: 24),

                  // 4. Pie de página con enlace interactivo
                  Center(
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Text(
                          '¿No tienes cuenta? ',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Redirigiendo a registro de cliente...'),
                              ),
                            );
                          },
                          child: const Text(
                            'Regístrate como Cliente',
                            style: TextStyle(
                              color: AppColors.primaryLight,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
