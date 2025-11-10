import 'package:flutter/material.dart';
import 'app_colors.dart';

// 'very small, small, medium, large, very large'
class AppTextStyles {

  static const textVerySmall = TextStyle(
    fontSize: 10,
    color: AppColors.grisLetra,
  );

  static const textSmall = TextStyle(
    fontSize: 12,
    color: AppColors.grisLetra,
  );

  static const textMedium = TextStyle(
    fontSize: 14,
    color: AppColors.grisLetra,
  );

  static const textLarge= TextStyle(
    fontSize: 16,
    color: AppColors.grisOscuroLetra,
  );

  static const title= TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: AppColors.verdeOscuro,
  );
}
