import 'package:flutter/material.dart';

class PasswordValidator extends StatelessWidget {
  final String password;

  const PasswordValidator({super.key, required this.password});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Requisitos de contraseña:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D8A8A),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          _buildRequirement(
            'Al menos 8 caracteres',
            password.length >= 8,
          ),
          _buildRequirement(
            'Al menos 1 letra mayúscula (A-Z)',
            password.contains(RegExp(r'[A-Z]')),
          ),
          _buildRequirement(
            'Al menos 1 letra minúscula (a-z)',
            password.contains(RegExp(r'[a-z]')),
          ),
          _buildRequirement(
            'Al menos 1 número (0-9)',
            password.contains(RegExp(r'[0-9]')),
          ),
          _buildRequirement(
            'Al menos 1 carácter especial (@#\$%^&*)',
            password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]')),
          ),
        ],
      ),
    );
  }

  Widget _buildRequirement(String requirement, bool isMet) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            isMet ? Icons.check_circle : Icons.cancel,
            color: isMet ? Colors.green : Colors.red,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              requirement,
              style: TextStyle(
                color: isMet ? Colors.green : Colors.red,
                fontSize: 12,
                fontWeight: isMet ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}