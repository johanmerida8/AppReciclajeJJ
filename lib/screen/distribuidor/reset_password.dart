// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:reciclaje_app/auth/auth_service.dart';
import 'package:reciclaje_app/components/my_button.dart';
import 'package:reciclaje_app/components/my_textfield.dart';
import 'package:reciclaje_app/components/password_validator.dart';
import 'package:reciclaje_app/screen/distribuidor/login_screen.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String email;
  final String otp;

  const ResetPasswordScreen({
    super.key,
    required this.email,
    required this.otp,
  });

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final authService = AuthService();
  final newPasswordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  bool _showPasswordValidator = false;

  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    newPasswordController.addListener(() {
      setState(() {
        _showPasswordValidator = newPasswordController.text.isNotEmpty;
        print('New password input changed: ${newPasswordController.text}');
      });
    });
  }

  // @override
  // void dispose() {
  //   newPasswordController.dispose();
  //   confirmPasswordController.dispose();
  //   super.dispose();
  // }

  void resetPassword() async {
    if (newPasswordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor ingresa una nueva contraseña')),
      );
      return;
    }

    if (newPasswordController.text.trim() != confirmPasswordController.text.trim()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Las contraseñas no coinciden')),
      );
      return;
    }

    if (newPasswordController.text.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La contraseña debe tener al menos 8 caracteres')),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      print('🔐 Updating password via Supabase for: ${widget.email}');

      // 🆕 Update password using Supabase (user is already authenticated via OTP)
      await authService.updatePasswordAfterSupabaseOTP(
        newPasswordController.text.trim(),
      );

      // Log the password reset attempt
      await authService.logPasswordResetAttempt(widget.email);
      
      // 🆕 Sign out immediately to prevent AuthGate from redirecting to home
      await authService.signOut();
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Contraseña restablecida con éxito'),
          backgroundColor: Colors.green,
        ),
      );

      // Navigate to login screen
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    } catch (e) {
      print('🚫 Error in resetPassword: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al restablecer la contraseña: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: null, // Explicitly set to null
      body: Container(
        height: MediaQuery.of(context).size.height,
        width: MediaQuery.of(context).size.width,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2D8A8A), Color(0xFF1A6B6B)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top section
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.3,
                child: Stack(
                  children: [
                    // Title
                    const Positioned(
                      bottom: 40,
                      left: 50,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Nueva',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Contraseña',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Ingresa tu nueva contraseña',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Reset password form
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 30.0),
                    child: Column(
                      children: [
                        const SizedBox(height: 40),
                        Text(
                          'Creando nueva contraseña para',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.email,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2D8A8A),
                          ),
                        ),
                        const SizedBox(height: 40),
                        // New password field
                        MyTextField(
                          controller: newPasswordController,
                          hintText: 'Nueva contraseña',
                          obscureText: true,
                          isEnabled: true,
                        ),

                        if (_showPasswordValidator) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 25),
                            child: Row(
                              children: [
                                // Text(
                                //   'Seguridad: ',
                                //   style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                // ),
                                // Text(
                                //   PasswordUtils.getPasswordStrength(passwordController.text),
                                //   style: TextStyle(
                                //     fontSize: 12,
                                //     fontWeight: FontWeight.bold,
                                //     color: PasswordUtils.getPasswordStrengthColor(passwordController.text),
                                //   ),
                                // ),
                              ],
                            ),
                          ),
                        ],

                        if (_showPasswordValidator)
                          PasswordValidator(password: newPasswordController.text),
                          
                        const SizedBox(height: 20),
                        // Confirm password field
                        MyTextField(
                          controller: confirmPasswordController,
                          hintText: 'Confirmar contraseña',
                          obscureText: true,
                          isEnabled: true,
                        ),
                        const SizedBox(height: 40),
                        // Reset button
                        MyButton(
                          onTap: isLoading ? null : resetPassword,
                          text: isLoading ? "Guardando..." : "Restablecer Contraseña",
                          color: Color(0xFF2D8A8A),
                        ),
                        const SizedBox(height: 50),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}