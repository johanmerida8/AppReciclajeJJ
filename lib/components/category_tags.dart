import 'package:flutter/material.dart';
import 'package:reciclaje_app/model/category.dart';

class CategoryTags extends StatelessWidget {
  final List<Category> categories;
  final Category? selectedCategory;
  final Function(Category?)? onCategorySelected;
  final String? Function(Category?)? validator;
  final String labelText;
  final bool isEnabled;
  final Set<int> disabledCategoryIds;

  const CategoryTags({
    super.key,
    required this.categories,
    required this.selectedCategory,
    required this.onCategorySelected,
    this.validator,
    this.labelText = 'Categoría',
    this.isEnabled = true,
    this.disabledCategoryIds = const {},
  });

  @override
  Widget build(BuildContext context) {
    return FormField<Category>(
      validator: validator,
      builder: (FormFieldState<Category> state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Label
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text(
                labelText,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: isEnabled
                      ? const Color(0xFF2D8A8A)
                      : Colors.grey.shade600,
                ),
              ),
            ),
            
            // Tags container
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                border: Border.all(
                  color: state.hasError ? Colors.red : Colors.grey.shade300,
                  width: 1.0,
                ),
                borderRadius: BorderRadius.circular(12.0),
                color: isEnabled ? Colors.white : Colors.grey.shade200,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // hint cuando no hay seleccion
                  if (selectedCategory == null && categories.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Text(
                        'Selecciona una categoría de reciclaje',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  categories.isEmpty
                      ? const Text(
                          'No hay categorías disponibles',
                          style: TextStyle(
                            color: Colors.grey,
                            fontStyle: FontStyle.italic,
                          ),
                        )
                      : Wrap(
                          spacing: 8.0,
                          runSpacing: 8.0,
                          children: categories.map((category) {
                            final isSelected = selectedCategory?.id == category.id;
                            final isDisabled = disabledCategoryIds.contains(category.id ?? -1);
                            return GestureDetector(
                              onTap: isDisabled || !isEnabled ? null : () {
                                onCategorySelected?.call(category);
                                state.didChange(category);
                              },
                              child: Tooltip(
                                message: isDisabled 
                                    ? 'Ya tienes un artículo pendiente con esta categoría' 
                                    : category.name ?? 'Sin nombre',
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16.0,
                                    vertical: 8.0,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDisabled 
                                        ? Colors.grey.shade200 // ✅ Gris cuando está bloqueada
                                        : (isSelected ? const Color(0xFF2D8A8A) : Colors.white),
                                    borderRadius: BorderRadius.circular(20.0),
                                    border: Border.all(
                                      color: isDisabled 
                                          ? Colors.grey.shade400 
                                          : (isSelected ? const Color(0xFF2D8A8A) : Colors.grey.shade300),
                                      width: 1.5,
                                    ),
                                    boxShadow: isDisabled || !isSelected
                                        ? []
                                        : [
                                            BoxShadow(
                                              color: const Color(0xFF2D8A8A).withOpacity(0.3),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (isDisabled)
                                        Padding(
                                          padding: const EdgeInsets.only(right: 6.0),
                                          child: Icon(
                                            Icons.lock_outline,
                                            size: 16,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      Text(
                                        category.name ?? 'Sin nombre',
                                        style: TextStyle(
                                          color: isDisabled 
                                              ? Colors.grey.shade600 
                                              : (isSelected ? Colors.white : Colors.black87),
                                          fontWeight: isDisabled 
                                              ? FontWeight.w400 
                                              : (isSelected ? FontWeight.w600 : FontWeight.w500),
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                ],
              ),
            ),
            
            // Error message
            if (state.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  state.errorText!,
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
