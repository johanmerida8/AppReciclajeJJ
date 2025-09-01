import 'package:flutter/material.dart';
import 'package:reciclaje_app/components/my_button.dart';
import 'package:reciclaje_app/components/my_textfield.dart';
import 'package:reciclaje_app/screen/login_screen.dart';

class RecoverPasswordScreen extends StatelessWidget {
  RecoverPasswordScreen({super.key});

  // text editing controllers
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();

  // sign user in method
  void signUserIn() {}

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
          child: SingleChildScrollView(
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
                      Container(
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
                        child: Padding(
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
                              MyTextfield(
                                controller: usernameController,
                                hintText: 'correo',
                                obscureText: false,
                              ),
                              const SizedBox(height: 40),
                              MyButton(
                                onTap: signUserIn,
                                text: "Enviar",
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
                    ],
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