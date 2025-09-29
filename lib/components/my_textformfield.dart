import 'package:flutter/material.dart';

class MyTextFormField extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final String text;
  final bool obscureText;
  final FocusNode? focusNode;
  final Function(String)? onChanged;
  final bool isEnabled;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;

  const MyTextFormField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.text,
    required this.obscureText,
    this.focusNode,
    this.onChanged,
    required this.isEnabled,
    this.prefixIcon,
    this.suffixIcon,
    this.validator,
  });

  @override
  State<MyTextFormField> createState() => _MyTextFormFieldState();
}

class _MyTextFormFieldState extends State<MyTextFormField> {
  bool isPasswordVisible = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ✅ Label text above the text field
        Text(
          widget.text,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        // ✅ Text form field
        TextFormField(
          controller: widget.controller,
          obscureText: widget.obscureText && !isPasswordVisible,
          focusNode: widget.focusNode,
          onChanged: widget.onChanged,
          validator: widget.validator,
          decoration: InputDecoration(
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.secondary,
              ),
            ),
            focusedBorder: const OutlineInputBorder(
              borderSide: BorderSide(
                color: Color(0xFF2D8A8A)
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
            hintText: widget.hintText,
            hintStyle: const TextStyle(
              color: Colors.grey
            ),
            enabled: widget.isEnabled,
            prefixIcon: widget.prefixIcon,
            suffixIcon: widget.suffixIcon ?? (widget.obscureText ? IconButton(
              icon: Icon(
                isPasswordVisible ? Icons.visibility : Icons.visibility_off,
              ),
              onPressed: () {
                setState(() {
                  isPasswordVisible = !isPasswordVisible;
                });
              },
            ) : null),
          ),
        ),
      ],
    );
  }
}
