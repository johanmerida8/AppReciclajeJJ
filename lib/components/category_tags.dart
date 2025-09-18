import 'package:flutter/material.dart';
import 'package:reciclaje_app/model/category.dart';

class CategoryTags extends StatelessWidget {
  final List<Category> categories;
  final Category? selectedCategory;
  final Function(Category?) onCategorySelected;
  final String? Function(Category?)? validator;
  final String labelText;

  const CategoryTags({
    super.key,
    required this.categories,
    required this.selectedCategory,
    required this.onCategorySelected,
    this.validator,
    this.labelText = 'Categoría',
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
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF2D8A8A),
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
                color: Colors.grey.shade50,
              ),
              child: categories.isEmpty
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
                        return GestureDetector(
                          onTap: () {
                            onCategorySelected(category);
                            state.didChange(category);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                              vertical: 8.0,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected 
                                  ? const Color(0xFF2D8A8A)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(20.0),
                              border: Border.all(
                                color: isSelected 
                                    ? const Color(0xFF2D8A8A)
                                    : Colors.grey.shade300,
                                width: 1.5,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: const Color(0xFF2D8A8A).withOpacity(0.3),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : [],
                            ),
                            child: Text(
                              category.name ?? 'Sin nombre',
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.black87,
                                fontWeight: isSelected 
                                    ? FontWeight.w600 
                                    : FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
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
