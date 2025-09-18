// ignore_for_file: use_build_context_synchronously, avoid_print

import 'package:flutter/material.dart';
import 'package:reciclaje_app/auth/auth_service.dart';
import 'package:reciclaje_app/components/my_button.dart';
import 'package:reciclaje_app/components/my_textfield.dart';
import 'package:reciclaje_app/components/password_validator.dart';
import 'package:reciclaje_app/database/users_database.dart';
import 'package:reciclaje_app/model/users.dart';
// import 'package:reciclaje_app/screen/home_screen.dart';
import 'package:reciclaje_app/screen/login_screen.dart';
import 'package:reciclaje_app/screen/navigation_screens.dart';
import 'package:reciclaje_app/utils/password_utils.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final authService = AuthService();
  final userDatabase = UsersDatabase();

  // text editing controllers
  // final nameController = TextEditingController();

  final namesController = TextEditingController();

  final emailController = TextEditingController();

  final passwordController = TextEditingController();

  final confirmPasswordController = TextEditingController();

  bool _showPasswordValidator = false;

  @override
  void initState() {
    super.initState();
    // listen to password field changes
    passwordController.addListener(() {
      setState(() {
        _showPasswordValidator = passwordController.text.isNotEmpty;
      });
    });
  }

  // sign user in method
  void signUserUp() async {
    final names = namesController.text;
    final email = emailController.text;
    final password = passwordController.text;
    final confirmPassword = confirmPasswordController.text;

    if (names.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty) {
      final snackBar = SnackBar(
        content: Text(
          'Por favor llena todos los campos',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.red,
      );
      ScaffoldMessenger.of(context).showSnackBar(snackBar);
      return;
    }

    // password validation
    if (!PasswordUtils.isPasswordValid(password)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La contraseña no cumple con todos los requisitos de seguridad'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Las contraseñas no coinciden'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // validate password strength
    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La contraseña debe tener al menos 6 caracteres'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final snackBar = SnackBar(
      content: Row(
        children: [
          CircularProgressIndicator(),
          SizedBox(width: 20),
          Text('Creando cuenta...'),
        ],
      ),
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(snackBar);
    }

    // attempt to sign up
    try {
      await authService.signUpWithEmailPassword(email, password);

      print("Usuario registrado: $email");

      // create user in the database
      final newUser = Users(
        names: names,
        email: email,
        // password: password,
        state: 1,
      );

      await userDatabase.createUser(newUser);
      print("Usuario creado en la base de datos: $email");

      // navigate to home screen
      if (mounted) {
        //hide the loading snackbar
        ScaffoldMessenger.of(context).hideCurrentSnackBar();

        // show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cuenta creada exitosamente!'),
            backgroundColor: Colors.green,
          ),
        );

        // navigate to home screen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const NavigationScreens()),
        );
      }
    }
    // catch any errors
    catch (e) {
      if (mounted) {
        //hide the loading snackbar
        ScaffoldMessenger.of(context).hideCurrentSnackBar();

        // show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al crear la cuenta: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      print("Error during registration: $e");
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
                              MyTextField(
                                controller: namesController,
                                hintText: 'Nombres',
                                obscureText: false, isEnabled: true,
                              ),
                              const SizedBox(height: 20),
                              MyTextField(
                                controller: emailController,
                                hintText: 'Correo',
                                obscureText: false, isEnabled: true,
                              ),
                              const SizedBox(height: 20),
                              MyTextField(
                                controller: passwordController,
                                hintText: 'Contraseña',
                                obscureText: true, isEnabled: true,
                              ),
                              const SizedBox(height: 20),
                              MyTextField(
                                controller: confirmPasswordController,
                                hintText: 'Confirmar contraseña',
                                obscureText: true, isEnabled: true,
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
                                PasswordValidator(password: passwordController.text),

                              const SizedBox(height: 40),
                              MyButton(
                                onTap: signUserUp, 
                                text: "Registrate",
                                color: Color(0xFF2D8A8A),
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
