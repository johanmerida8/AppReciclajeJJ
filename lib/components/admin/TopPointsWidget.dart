import 'package:flutter/material.dart';
import '/theme/app_text_styles.dart';
import '/theme/app_colors.dart';
import '/theme/app_spacing.dart';
import '/components/admin/points_calculator.dart'; // CarryOverTier

class TopPointsWidget extends StatelessWidget {
  final String title;
  final List<CarryOverTier> tiers;

  const TopPointsWidget({
    super.key,
    required this.title,
    required this.tiers,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.fondoBlanco,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: AppTextStyles.textMedium.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            tiers.isEmpty
                ? const Text(
                    "No hay distribución de puntos disponible.",
                    style: AppTextStyles.textSmall,
                  )
                : Column(
                    children: tiers.map((tier) {
                      final tierUsers = tier.positionEnd - tier.positionStart + 1;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Puestos y usuarios
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Puesto${tier.positionStart != tier.positionEnd ? 's' : ''} "
                                  "${tier.positionStart}"
                                  "${tier.positionStart != tier.positionEnd ? '-${tier.positionEnd}' : ''}",
                                  style: AppTextStyles.textMedium,
                                ),
                                Text(
                                  "$tierUsers usuario${tierUsers > 1 ? 's' : ''}",
                                  style: AppTextStyles.textSmall.copyWith(
                                      color: AppColors.grisLetra),
                                ),
                              ],
                            ),
                            // Estrellas y puntos
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: List.generate(5, (index) {
                                    return Icon(
                                      index < tier.stars ? Icons.star : Icons.star_border,
                                      color: Colors.amber,
                                      size: 18,
                                    );
                                  }),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "${tier.points} pts",
                                  style: AppTextStyles.textMedium
                                      .copyWith(color: AppColors.grisLetra),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          ],
        ),
      ),
    );
  }
}
