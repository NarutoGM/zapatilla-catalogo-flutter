import 'package:flutter/material.dart';
// TODO: Descomentar importaciones de Firebase cuando el backend esté configurado
// import 'package:firebase_core/firebase_core.dart';
// import 'firebase_options.dart';

import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'features/admin/presentation/screens/admin_screen.dart';
import 'features/admin/presentation/screens/reports_dashboard_screen.dart';
import 'features/auth/presentation/controllers/auth_controller.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/home/presentation/screens/cart_screen.dart';
import 'features/home/presentation/screens/home_screen.dart';
import 'services/cart_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // TODO: Descomentar para inicializar Firebase cuando se configure 'firebase_options.dart'
  // await Firebase.initializeApp(
  //   options: DefaultFirebaseOptions.currentPlatform,
  // );

  runApp(const PizzoApp());
}

class PizzoApp extends StatelessWidget {
  const PizzoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthController()),
        ChangeNotifierProvider(create: (_) => CartService()),
      ],
      child: MaterialApp(
        title: 'Pizzo Velocity - Catálogo 3D',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        initialRoute: '/login',
        routes: {
          '/login': (context) => const LoginScreen(),
          '/home': (context) => const HomeScreen(),
          '/cart': (context) => const CartScreen(),
          '/admin': (context) => const AdminScreen(),
          '/reports': (context) => const ReportsDashboardScreen(),
        },
      ),
    );
  }
}
