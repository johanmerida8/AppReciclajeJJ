import 'package:flutter/material.dart';

class ConditionSelector extends StatelessWidget {
  final String? selectedCondition;
  final Function(String)? onConditionSelected;
  final String labelText;
  final bool isEnabled;
  final String? Function(String?)? validator;

  const ConditionSelector({
    super.key,
    required this.selectedCondition,
    this.onConditionSelected,
    this.labelText = 'Estado',
    this.isEnabled = true,
    this.validator,
  });

  // ✅ Updated condition options matching your requirements
  static const List<Map<String, dynamic>> conditions = [
    {
      'value': 'Reciclable',
      'label': 'Reciclable',
      'color': Colors.green,
    },
    {
      'value': 'Moderado',
      'label': 'Moderado',
      'color': Colors.orange,
    },
    {
      'value': 'Dañado',
      'label': 'Dañado',
      'color': Colors.red,
    },
    {
      'value': 'Sin clasificación',
      'label': 'Sin clasificación',
      'color': Colors.grey,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return FormField<String>(
      validator: validator,
      builder: (FormFieldState<String> state) {
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

            // Container
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                border: Border.all(
                  color: state.hasError 
                      ? Colors.red 
                      : isEnabled
                          ? Colors.grey.shade300
                          : Colors.grey.shade200,
                  width: 1.0,
                ),
                borderRadius: BorderRadius.circular(12),
                color: isEnabled 
                    ? Colors.grey.shade50 
                    : Colors.grey.shade100, // ✅ Different color when disabled
              ),
              child: Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: conditions.map((condition) {
                  final isSelected = selectedCondition == condition['value'];
                  
                  return GestureDetector(
                    onTap: isEnabled && onConditionSelected != null 
                        ? () {
                            onConditionSelected!(condition['value']);
                            state.didChange(condition['value']);
                          }
                        : null, // ✅ Disable tap when not enabled
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected 
                            ? (isEnabled 
                                ? condition['color']
                                : condition['color'].withOpacity(0.5)) // ✅ Dimmed when disabled
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected 
                              ? (isEnabled 
                                  ? condition['color']
                                  : condition['color'].withOpacity(0.5))
                              : Colors.grey.shade300,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        condition['label'],
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: isSelected 
                              ? Colors.white
                              : isEnabled
                                  ? Colors.grey.shade700
                                  : Colors.grey.shade400, // ✅ Different text color when disabled
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