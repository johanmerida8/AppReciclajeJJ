import 'package:flutter/material.dart';
import '/theme/app_colors.dart';
import '/theme/app_spacing.dart';
import '/theme/app_text_styles.dart';

class CustomSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final String hintText;

  const CustomSearchBar({
    super.key,
    required this.controller,
    this.onChanged,
    this.hintText = 'Buscar...',
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: AppTextStyles.textMedium.copyWith(
        fontWeight: FontWeight.w400,
        fontSize: 16, // <-- tamaño del texto escrito
      ),
      cursorColor: AppColors.fondoGrisOscuro,
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.all(4.0), // <-- aquí
        prefixIcon: const Icon(
          Icons.search,
          color: AppColors.fondoGrisOscuro,
          size: 22,
        ),
        hintText: hintText,
        hintStyle: AppTextStyles.textMedium.copyWith(
          fontWeight: FontWeight.w400,
          fontSize: 16, // <-- tamaño del texto escrito
        ),
        filled: true,
        fillColor: AppColors.fondoGrisClaro,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
          borderSide: const BorderSide(
            color: AppColors.fondoGrisClaro,
            width: 0.8,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
          borderSide: const BorderSide(
            color: AppColors.fondoGrisOscuro,
            width: 1.6,
          ),
        ),
      ),
    );
  }
}

