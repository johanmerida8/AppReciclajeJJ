import 'package:flutter/material.dart';
import 'package:reciclaje_app/auth/auth_service.dart';
import 'package:reciclaje_app/components/my_button.dart';
import 'package:reciclaje_app/components/my_textfield.dart';
import 'package:reciclaje_app/screen/distribuidor/login_screen.dart';
import 'package:reciclaje_app/screen/distribuidor/otp_screen.dart';

class RecoverPasswordScreen extends StatefulWidget {
  const RecoverPasswordScreen({super.key});

  @override
  State<RecoverPasswordScreen> createState() => _RecoverPasswordScreenState();
}

class _RecoverPasswordScreenState extends State<RecoverPasswordScreen> {
  final authService = AuthService();

  // text editing controllers
  final usernameController = TextEditingController();

  final passwordController = TextEditingController();

  bool isLoading = false;

  // send OTP via email
  void resetPassword() async {
    if (usernameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor ingresa tu correo'))
      );
      return;
    }

    setState(() {
      isLoading = true;  
    });

    try {
      final email = usernameController.text.trim();
      print('🔍 Sending OTP to: $email');

      // Check rate limits first
      final eligibility = await authService.canRequestPasswordReset(email);
      
      if (eligibility['canReset'] != true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(eligibility['message'] ?? 'Por favor espera antes de intentar de nuevo'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 4),
          ),
        );
        setState(() {
          isLoading = false;  
        });
        return;
      }

      // 🆕 Send OTP via Supabase (free, unlimited)
      await authService.sendOTPToEmail(email);

      // Log the attempt
      await authService.logPasswordResetAttempt(email);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Código enviado a $email'),
          backgroundColor: Colors.green,
        ),
      );

      // Navigate to OTP verification screen
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => OTPScreen(email: email),
          ),
        );
      }
    } catch (e) {
      print('🚫 Error in resetPassword: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al enviar OTP: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
    finally {
      setState(() {
        isLoading = false;  
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight:
                    MediaQuery.of(context).size.height -
                    MediaQuery.of(context).padding.top,
              ),
              child: Stack(
                children: [
                  Column(
                    children: [
                      // Top section with decorative elements
                      Container(
                        height: MediaQuery.of(context).size.height * 0.4,
                        child: Stack(
                          children: [
                            // Large leaf decoration
                            Positioned(
                              top: 0,
                              left: -120,
                              child: Image.asset(
                                'lib/images/Leaf.png',
                                width: 300,
                                height: 300,
                                fit: BoxFit.contain,
                              ),
                            ),
                            // Welcome text
                            const Positioned(
                              bottom: 80,
                              left: 50,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Hola!',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 48,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Restablece tu contraseña',
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
                      // Login form card
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          constraints: BoxConstraints(
                            minHeight: MediaQuery.of(context).size.height * 0.6,
                          ),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(30),
                              topRight: Radius.circular(30),
                            ),
                          ),
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(30.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // const SizedBox(
                                //   height: 60,
                                // ), // Extra space for the pot
                                Row(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 25.0,
                                      ),
                                      child: const Text(
                                        'Restablecer contraseña',
                                        style: TextStyle(
                                          color: Color(0xFF2D8A8A),
                                          fontSize: 17,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                        
                                    Spacer(),
                        
                                    Image.asset(
                                        'lib/images/Pot2.png',
                                        width: 80,
                                        height: 120,
                                        fit: BoxFit.contain,
                                      ),
                        
                                  ],
                                ),
                                const SizedBox(height: 40),
                                MyTextField(
                                  controller: usernameController,
                                  hintText: 'correo',
                                  obscureText: false, 
                                  isEnabled: true,
                                ),
                                const SizedBox(height: 40),
                                MyButton(
                                  onTap: isLoading ? null : resetPassword,
                                  text: isLoading ? "Enviando..." : "Enviar",
                                  color: Color(0xFF2D8A8A),
                                ),
                                const SizedBox(height: 80),
                                Center(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      GestureDetector(
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) {
                                                return LoginScreen();
                                              },
                                            ),
                                          );
                                        },
                                        child: Text(
                                          'Volver al inicio de sesion ',
                                          style: TextStyle(color: Colors.grey),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 30),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
    );
  }
}