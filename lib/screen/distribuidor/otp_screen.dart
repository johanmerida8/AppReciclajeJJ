// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:reciclaje_app/auth/auth_service.dart';
import 'package:reciclaje_app/components/my_button.dart';
import 'package:reciclaje_app/screen/distribuidor/reset_password.dart';
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
  void initState() {
    super.initState();
    // 🆕 Auto-paste OTP from clipboard when screen loads
    _tryAutoPasteOTP();
  }

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

  // 🆕 Try to auto-paste OTP from clipboard
  Future<void> _tryAutoPasteOTP() async {
    try {
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      if (clipboardData != null && clipboardData.text != null) {
        final clipText = clipboardData.text!.trim();
        
        // Check if clipboard contains a 6-digit number
        if (RegExp(r'^\d{6}$').hasMatch(clipText)) {
          // Auto-fill the OTP fields
          for (int i = 0; i < 6; i++) {
            otpControllers[i].text = clipText[i];
          }
          
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Código pegado automáticamente'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
          
          // Focus on last field
          focusNodes[5].requestFocus();
        }
      }
    } catch (e) {
      // Silent fail - user can still type manually
      print('Could not auto-paste OTP: $e');
    }
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
      // 🆕 Use Supabase's built-in OTP verification
      final isValid = await authService.verifySupabaseOTP(widget.email, otpCode);

      if (isValid) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ OTP verificado con éxito'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Navigate to reset password screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ResetPasswordScreen(
              email: widget.email, 
              otp: otpCode,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ OTP inválido o expirado'),
            backgroundColor: Colors.red,
          ),
        );
        
        // Clear OTP fields
        for (var controller in otpControllers) {
          controller.clear();
        }
        focusNodes[0].requestFocus();
      }
    } catch (e) {
      print('🚫 Error in verifyOTP: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al verificar OTP: $e'),
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
      // Check cooldown before allowing resend (optional)
      final eligibility = await authService.canRequestPasswordReset(widget.email);

      if (eligibility['canReset'] == false) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(eligibility['message'] ?? 'Por favor espera antes de reenviar'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // 🆕 Resend OTP via Supabase
      await authService.sendOTPToEmail(widget.email);

      // Log the attempt
      await authService.logPasswordResetAttempt(widget.email);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ OTP reenviado a ${widget.email}'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al reenviar OTP: $e'),
          backgroundColor: Colors.red,
        ),
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
                              width: 50,
                              height: 60,
                              child: RawKeyboardListener(
                                focusNode: FocusNode(),
                                onKey: (event) {
                                  // 🆕 Handle backspace key
                                  if (event is RawKeyDownEvent && 
                                      event.logicalKey == LogicalKeyboardKey.backspace) {
                                    if (otpControllers[index].text.isEmpty && index > 0) {
                                      // Move to previous field and clear it
                                      focusNodes[index - 1].requestFocus();
                                      Future.delayed(const Duration(milliseconds: 50), () {
                                        otpControllers[index - 1].clear();
                                      });
                                    }
                                  }
                                },
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
                                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
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
                                      // Move to next field when digit entered
                                      focusNodes[index + 1].requestFocus();
                                    } else if (value.isEmpty && index > 0) {
                                      // Move back when field becomes empty
                                      focusNodes[index - 1].requestFocus();
                                    }
                                  },
                                  onTap: () {
                                    // 🆕 Select all text when tapping on field
                                    otpControllers[index].selection = TextSelection(
                                      baseOffset: 0,
                                      extentOffset: otpControllers[index].text.length,
                                    );
                                  },
                                ),
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 20),
                        // 🆕 Paste button
                        TextButton.icon(
                          onPressed: () async {
                            try {
                              final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
                              if (clipboardData != null && clipboardData.text != null) {
                                final clipText = clipboardData.text!.replaceAll(RegExp(r'\s+'), '');
                                
                                // Check if clipboard contains at least 6 digits
                                final digits = clipText.replaceAll(RegExp(r'\D'), '');
                                if (digits.length >= 6) {
                                  // Fill the OTP fields
                                  for (int i = 0; i < 6; i++) {
                                    otpControllers[i].text = digits[i];
                                  }
                                  
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('✅ Código pegado'),
                                      backgroundColor: Colors.green,
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                  
                                  // Focus on last field
                                  focusNodes[5].requestFocus();
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('❌ El portapapeles no contiene un código válido'),
                                      backgroundColor: Colors.orange,
                                    ),
                                  );
                                }
                              }
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('❌ No se pudo pegar el código'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.content_paste, size: 20),
                          label: const Text('Pegar código'),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF2D8A8A),
                          ),
                        ),
                        const SizedBox(height: 20),
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