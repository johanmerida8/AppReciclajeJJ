import 'package:flutter/material.dart';
import 'package:reciclaje_app/components/my_button.dart';
import 'package:reciclaje_app/components/my_textfield.dart';
import 'package:reciclaje_app/components/password_validator.dart';
import 'package:reciclaje_app/database/employee_database.dart';
import 'package:reciclaje_app/screen/employee/employee_navigation_screens.dart';
import 'package:reciclaje_app/utils/password_utils.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EmployeeChangePasswordScreen extends StatefulWidget {
  final Map<String, dynamic> employeeData; // Contains employee + user data

  const EmployeeChangePasswordScreen({super.key, required this.employeeData});

  @override
  State<EmployeeChangePasswordScreen> createState() => _EmployeeChangePasswordScreenState();
}

class _EmployeeChangePasswordScreenState extends State<EmployeeChangePasswordScreen> {
  final EmployeeDatabase _employeeDb = EmployeeDatabase();
  
  final newPasswordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  
  bool _showPasswordValidator = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    newPasswordController.addListener(() {
      setState(() {
        _showPasswordValidator = newPasswordController.text.isNotEmpty;
      });
    });
  }

  Future<void> _changePassword() async {
    final newPassword = newPasswordController.text;
    final confirmPassword = confirmPasswordController.text;

    if (newPassword.isEmpty || confirmPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor completa todos los campos')),
      );
      return;
    }

    if (newPassword != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Las contraseñas no coinciden')),
      );
      return;
    }

    if (!PasswordUtils.isPasswordValid(newPassword)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La contraseña no cumple con los requisitos')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = widget.employeeData['user'];
      final userEmail = user['email'] as String;
      final userId = user['idUser'] as int;

      // Create Supabase auth account for the employee
      await Supabase.instance.client.auth.signUp(
        email: userEmail,
        password: newPassword,
      );

      // Activate employee - clear temp password and set state=1
      await _employeeDb.activateEmployee(userId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Contraseña creada y cuenta activada exitosamente'),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate to employee navigation screens
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const EmployeeNavigationScreens()),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al crear contraseña: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.employeeData['user'];
    final userName = user['names'] as String?;
    
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2D8A8A), Color(0xFF1A6B6B)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Warning Icon
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.lock_reset,
                      size: 60,
                      color: Color(0xFF2D8A8A),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Title
                  const Text(
                    'Cambio de Contraseña Requerido',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),

                  // Subtitle
                  const Text(
                    'Por seguridad, debes cambiar tu contraseña temporal',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),

                  // Form Card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Bienvenido,',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey,
                          ),
                        ),
                        Text(
                          userName ?? 'Empleado',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2D8A8A),
                          ),
                        ),
                        const SizedBox(height: 24),

                        MyTextField(
                          controller: newPasswordController,
                          hintText: 'Nueva Contraseña',
                          obscureText: true,
                          isEnabled: !_isLoading,
                        ),
                        
                        if (_showPasswordValidator) ...[
                          const SizedBox(height: 8),
                          PasswordValidator(password: newPasswordController.text),
                        ],

                        const SizedBox(height: 16),
                        
                        MyTextField(
                          controller: confirmPasswordController,
                          hintText: 'Confirmar Nueva Contraseña',
                          obscureText: true,
                          isEnabled: !_isLoading,
                        ),

                        const SizedBox(height: 24),

                        MyButton(
                          onTap: _isLoading ? () {} : _changePassword,
                          text: _isLoading ? "Cambiando..." : "Cambiar Contraseña",
                          color: const Color(0xFF2D8A8A),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
