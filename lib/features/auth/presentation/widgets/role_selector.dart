import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../models/user_model.dart';
import '../controllers/auth_controller.dart';

class RoleSelector extends StatelessWidget {
  final Function(String email, String password)? onRoleChanged;

  const RoleSelector({
    super.key,
    this.onRoleChanged,
  });

  @override
  Widget build(BuildContext context) {
    final authController = context.watch<AuthController>();
    final selectedRole = authController.selectedSimulatedRole;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.border.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          // Pill Cliente
          Expanded(
            child: _buildRolePill(
              context: context,
              title: 'Cliente',
              icon: Icons.person_outline,
              isSelected: selectedRole == UserRole.client,
              onTap: () {
                authController.setSimulatedRole(UserRole.client);
                if (onRoleChanged != null) {
                  onRoleChanged!('cliente@pizzo.com', '123456');
                }
              },
            ),
          ),
          const SizedBox(width: 4),

          // Pill Admin
          Expanded(
            child: _buildRolePill(
              context: context,
              title: 'Admin',
              icon: Icons.shield_outlined,
              isSelected: selectedRole == UserRole.admin,
              onTap: () {
                authController.setSimulatedRole(UserRole.admin);
                if (onRoleChanged != null) {
                  onRoleChanged!('admin@pizzo.com', '123456');
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRolePill({
    required BuildContext context,
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? AppColors.primaryLight : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? AppColors.primaryLight : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
