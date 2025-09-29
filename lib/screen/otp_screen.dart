// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:reciclaje_app/auth/auth_service.dart';
import 'package:reciclaje_app/components/my_button.dart';
import 'package:reciclaje_app/screen/reset_password.dart';
// import 'package:reciclaje_app/screen/reset_password_screen.dart';

class OTPScreen extends StatefulWidget {
  final String email;

  const OTPScreen({super.key, required this.email});

  @override
  State<OTPScreen> createState() => _OTPScreenState();
}

class _OTPScreenState extends State<OTPScreen> {
  final authService = AuthService();
  final List<TextEditingController> otpControllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> focusNodes = List.generate(6, (_) => FocusNode());

  bool isLoading = false;
  String otpCode = '';

  @override
  void dispose() {
    for (var controller in otpControllers) {
      controller.dispose();
    }
    for (var node in focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void verifyOTP() async {
    setState(() {
      isLoading = true;
    });

    otpCode = otpControllers.map((controller) => controller.text).join();

    if (otpCode.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor digite todos los dígitos')),
      );
      setState(() {
        isLoading = false;
      });
      return;
    }

    try {
      final isValid = await authService.verifyOTP(widget.email, otpCode);

      if (isValid) {
        // clean up expired OTPs when verification is successful
        await authService.cleanupExpiredOTPs();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('OTP verificado con éxito')),
        );
        // Navigate to reset password screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ResetPasswordScreen(email: widget.email, otp: otpCode),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('OTP inválido o expirado')),
        );
        // limpiar los campos de OTP
        for (var controller in otpControllers) {
          controller.clear();
        }
        focusNodes[0].requestFocus();
      }
    } catch (e) {
      print('🚫 Error in verifyOTP: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al verificar OTP'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void resendOTP() async {
    try {
      // check cooldown before allowing resend
      final eligibility = await authService.canRequestPasswordReset(widget.email);

      if (!eligibility['canReset']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(eligibility['message']),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // generate and send new OTP
      await authService.generateAndSendOTP(widget.email);

      // log the password reset attempt
      await authService.logPasswordResetAttempt(widget.email);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('OTP reenviado con éxito a ${widget.email}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al reenviar OTP: $e')),
      );
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
          child: Column(
            children: [
              // Top section
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.3,
                child: Stack(
                  children: [
                    // Back button
                    Positioned(
                      top: 20,
                      left: 20,
                      child: IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                      ),
                    ),
                    // Title
                    const Positioned(
                      bottom: 40,
                      left: 50,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Verificación',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Ingresa el código de 6 dígitos',
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
              // OTP form card
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
                    padding: const EdgeInsets.all(30.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 40),
                        Text(
                          'Código enviado a',
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
                        // OTP Input Fields
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: List.generate(6, (index) {
                            return SizedBox(
                              width: 45,
                              height: 55,
                              child: TextField(
                                controller: otpControllers[index],
                                focusNode: focusNodes[index],
                                textAlign: TextAlign.center,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(1),
                                ],
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2D8A8A),
                                ),
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: Colors.grey),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: Color(0xFF2D8A8A), width: 2),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.grey[300]!),
                                  ),
                                  fillColor: Colors.grey[50],
                                  filled: true,
                                ),
                                onChanged: (value) {
                                  if (value.isNotEmpty && index < 5) {
                                    focusNodes[index + 1].requestFocus();
                                  } else if (value.isEmpty && index > 0) {
                                    focusNodes[index - 1].requestFocus();
                                  }
                                },
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 40),
                        // Verify button
                        MyButton(
                          onTap: isLoading ? null : verifyOTP,
                          text: isLoading ? "Verificando..." : "Verificar",
                          color: Color(0xFF2D8A8A),
                        ),
                        const SizedBox(height: 30),
                        // Resend OTP
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '¿No recibiste el código? ',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            GestureDetector(
                              onTap: resendOTP,
                              child: const Text(
                                'Reenviar',
                                style: TextStyle(
                                  color: Color(0xFF2D8A8A),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
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