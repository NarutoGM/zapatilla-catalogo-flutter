import 'package:flutter/material.dart';

class AppColors {
  // Colores primarios y gradientes
  static const Color primary = Color(0xFF1E3A8A);      // Azul Oscuro
  static const Color primaryLight = Color(0xFF2563EB); // Azul Vibrante
  static const Color primaryAccent = Color(0xFF3B82F6);

  // Verde Velocity (Badge)
  static const Color velocityGreen = Color(0xFF10B981); // Verde neón/vibrante
  static const Color velocityGreenDark = Color(0xFF059669);

  // Gradiente de la tarjeta superior
  static const LinearGradient headerGradient = LinearGradient(
    colors: [
      Color(0xFF0F172A), // Slate 900
      Color(0xFF1E3A8A), // Azul primario
      Color(0xFF2563EB), // Azul vibrante
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Fondos y neutros
  static const Color background = Color(0xFFF8FAFC);
  static const Color cardBackground = Colors.white;
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color border = Color(0xFFE2E8F0);

  // Estados
  static const Color error = Color(0xFFEF4444);
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
}
