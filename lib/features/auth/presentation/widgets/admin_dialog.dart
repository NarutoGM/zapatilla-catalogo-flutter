import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class AdminDialog extends StatelessWidget {
  final VoidCallback onDismiss;
  final VoidCallback? onOpenAdminPanel;

  const AdminDialog({
    super.key,
    required this.onDismiss,
    this.onOpenAdminPanel,
  });

  static Future<void> show(
    BuildContext context, {
    required VoidCallback onDismiss,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AdminDialog(
          onDismiss: () {
            Navigator.of(dialogContext).pop();
            onDismiss();
          },
          onOpenAdminPanel: () {
            Navigator.of(dialogContext).pop();
            onDismiss();
            Navigator.of(context).pushReplacementNamed('/admin');
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
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primaryLight.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.admin_panel_settings_rounded,
                color: AppColors.primaryLight,
                size: 40,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Modo Administrador Detectado',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Desde el panel /admin puedes subir modelos 3D (.glb), fotos de zapatillas y gestionar precios o stock directamente en Firebase.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 24),
            if (onOpenAdminPanel != null) ...[
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: onOpenAdminPanel,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryLight,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.dashboard_customize_rounded, size: 18),
                  label: const Text(
                    'Entrar al Panel Admin (/admin)',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton(
                onPressed: onDismiss,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Volver al Login de Cliente',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
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
