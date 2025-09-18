import 'package:flutter/material.dart';

class MyDropdown<T> extends StatelessWidget {
  final T? value;
  final List<T> items;
  final String Function(T) getDisplayText;
  final void Function(T?) onChanged;
  final String hintText;
  final Widget? prefixIcon;
  final String? Function(T?)? validator;

  const MyDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.getDisplayText,
    required this.onChanged,
    required this.hintText,
    this.prefixIcon,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      value: value,
      decoration: InputDecoration(
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.secondary,
          ),
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(
            color: Color(0xFF2D8A8A),
          ),
        ),
        errorBorder: const OutlineInputBorder(
          borderSide: BorderSide(
            color: Colors.red,
          ),
        ),
        focusedErrorBorder: const OutlineInputBorder(
          borderSide: BorderSide(
            color: Colors.red,
          ),
        ),
        fillColor: Theme.of(context).colorScheme.surface,
        filled: true,
        hintText: hintText,
        hintStyle: const TextStyle(
          color: Colors.grey,
        ),
        prefixIcon: prefixIcon,
      ),
      items: items.map((item) {
        return DropdownMenuItem<T>(
          value: item,
          child: Text(getDisplayText(item)),
        );
      }).toList(),
      onChanged: onChanged,
      validator: validator,
    );
  }
}
