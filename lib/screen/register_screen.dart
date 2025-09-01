import 'package:flutter/material.dart';
import 'package:reciclaje_app/components/my_button.dart';
import 'package:reciclaje_app/components/my_textfield.dart';
import 'package:reciclaje_app/screen/login_screen.dart';

class RegisterScreen extends StatelessWidget {
  RegisterScreen({super.key});

  // text editing controllers
  final nameController = TextEditingController();
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  // sign user in method
  void signUserUp() {

  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF2D8A8A),
              Color(0xFF1A6B6B),
            ],
          )
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top
              ),
              child: Stack(
                children: [
                  Column(
                    children: [
                      // Top section with decorative elements
                      Container(
                        height: MediaQuery.of(context).size.height * 0.25,
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
                            // const Positioned(
                            //   bottom: 80,
                            //   left: 50,
                            //   child: Column(
                            //     crossAxisAlignment: CrossAxisAlignment.start,
                            //     children: [
                            //       Text(
                            //         'Hola!',
                            //         style: TextStyle(
                            //           color: Colors.white,
                            //           fontSize: 48,
                            //           fontWeight: FontWeight.bold,
                            //         ),
                            //       ),
                            //       SizedBox(height: 8),
                            //       Text(
                            //         'bienvenido a la comunidad',
                            //         style: TextStyle(
                            //           color: Colors.white,
                            //           fontSize: 16,
                            //           fontWeight: FontWeight.w300
                            //         ),
                            //       ),
                            //     ],
                            //   ),
                            // ),
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
                              // const SizedBox(height: 60), // Extra space for the pot
                              Row(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 25.0,
                                    ),
                                    child: const Text(
                                      'Registrate',
                                      style: TextStyle(
                                        color: Color(0xFF2D8A8A),
                                        fontSize: 24,
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
                                controller: nameController,
                                hintText: 'nombres',
                                obscureText: false,
                              ),
                              const SizedBox(height: 20),
                              MyTextfield(
                                controller: usernameController,
                                hintText: 'correo',
                                obscureText: false,
                              ),
                              const SizedBox(height: 20),
                              MyTextfield(
                                controller: passwordController,
                                hintText: 'contraseña',
                                obscureText: true,
                              ),
                              const SizedBox(height: 20),
                              MyTextfield(
                                controller: confirmPasswordController,
                                hintText: 'Confirmar contraseña',
                                obscureText: true,
                              ),
                              const SizedBox(height: 40),
                              MyButton(
                                onTap: signUserUp,
                                text: "Registrate"
                              ),
                              const SizedBox(height: 80),
                              Center(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Ya tienes cuenta? ',
                                      style: TextStyle(color: Colors.grey),
                                    ),
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
                                        'Inicia Sesion',
                                        style: TextStyle(
                                          color: Color(0xFF2D8A8A),
                                          fontWeight: FontWeight.bold,
                                        ),
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
                  // Pot image positioned between sections
                  // Positioned(
                  //   top: MediaQuery.of(context).size.height * 0.4 - 130, // Position at the overlap
                  //   right: 50,
                  //   child: Container(
                  //     child: Image.asset(
                  //       'lib/images/Pot2.png',
                  //       width: 120,
                  //       height: 180,
                  //       fit: BoxFit.contain,
                  //     ),
                  //   ),
                  // ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}