import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class AdminDialog extends StatelessWidget {
  final VoidCallback onDismiss;

  const AdminDialog({
    super.key,
    required this.onDismiss,
  });

  static Future<void> show(BuildContext context, {required VoidCallback onDismiss}) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // Modal bloqueante
      builder: (BuildContext dialogContext) {
        return AdminDialog(
          onDismiss: () {
            Navigator.of(dialogContext).pop();
            onDismiss();
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      elevation: 10,
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icono de Escudo de Advertencia / Seguridad
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.shield_outlined,
                color: AppColors.warning,
                size: 40,
              ),
            ),
            const SizedBox(height: 18),

            // Título
            const Text(
              'Acceso Restringido',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),

            // Mensaje explicativo
            const Text(
              'La administración del catálogo y la subida de modelos .glb debe realizarse exclusivamente desde la versión web (/admin). Esta aplicación móvil está habilitada únicamente para clientes.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 24),

            // Botón de acción: "Entendido"
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: onDismiss,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Entendido',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
