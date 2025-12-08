import 'package:flutter/material.dart';
import '/theme/app_text_styles.dart';
import '/theme/app_colors.dart';
import '/components/admin/points_calculator.dart';
import '/model/admin/cycle_star_model.dart';

class StarPointsWidget extends StatelessWidget {
  final String title;
  final List<CycleStarModel> starValues;
  final bool reverseOrder; // true: empieza con 5 estrellas

  const StarPointsWidget({
    super.key,
    required this.title,
    required this.starValues,
    this.reverseOrder = false,
  });

  @override
  Widget build(BuildContext context) {
    final starsList = reverseOrder ? starValues.reversed.toList() : starValues;

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
            starsList.isEmpty
                ? const Text(
                    "No hay valores configurados.",
                    style: AppTextStyles.textSmall,
                  )
                : Column(
                    children: starsList.map((star) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Row(
                              children: List.generate(5, (index) {
                                return Icon(
                                  index < star.stars ? Icons.star : Icons.star_border,
                                  color: Colors.amber,
                                  size: 22,
                                );
                              }),
                            ),
                            const Spacer(),
                            Text(
                              "${star.points} pts",
                              style: AppTextStyles.textMedium.copyWith(
                                color: AppColors.grisLetra,
                              ),
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
