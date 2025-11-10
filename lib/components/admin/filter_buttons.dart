import 'package:flutter/material.dart';
import '/theme/app_colors.dart';
import '/theme/app_text_styles.dart';
import '/theme/app_spacing.dart';

class FilterButtons extends StatelessWidget {
  final bool archivedOnly;
  final bool ascending;
  final VoidCallback onArchivedToggle;
  final VoidCallback onOrderToggle;

  const FilterButtons({
    super.key,
    required this.archivedOnly,
    required this.ascending,
    required this.onArchivedToggle,
    required this.onOrderToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _buildButton(
          icon: Icons.archive,
          label: 'Archivados',
          active: archivedOnly,
          onPressed: onArchivedToggle,
        ),
        const SizedBox(width: AppSpacing.spacingSmall),
        _buildButton(
          icon: ascending ? Icons.arrow_upward : Icons.arrow_downward,
          label: ascending ? 'Ascendente' : 'Descendente',
          active: false,
          onPressed: onOrderToggle,
        ),
      ],
    );
  }

  Widget _buildButton({
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor:
            active ? AppColors.verdeOscuro : AppColors.fondoGrisClaro,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 6,
        ),
        //visualDensity: VisualDensity.compact,
        elevation: 0,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 18, // 👈 ícono un poco más pequeño
            color: active ? AppColors.fondoBlanco : AppColors.grisOscuroLetra,
          ),
          const SizedBox(width: 4), // 👈 espacio entre ícono y texto
          Text(
            label,
            style: AppTextStyles.textMedium.copyWith(
              fontSize: 14, // 👈 texto más pequeño
              color: active ? AppColors.fondoBlanco : AppColors.grisOscuroLetra,
            ),
          ),
        ],
      ),
    );
  }
}
