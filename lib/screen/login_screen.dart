import 'package:flutter/material.dart';
import 'package:reciclaje_app/auth/auth_service.dart';
import 'package:reciclaje_app/components/my_button.dart';
import 'package:reciclaje_app/components/my_textfield.dart';
// import 'package:reciclaje_app/screen/home_screen.dart';
import 'package:reciclaje_app/screen/navigation_screens.dart';
import 'package:reciclaje_app/screen/recover_password.dart';
import 'package:reciclaje_app/screen/register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {

  final authService = AuthService();

  // text editing controllers
  final usernameController = TextEditingController();

  final passwordController = TextEditingController();

  // sign user in method
  void signUserIn() async {

    if (usernameController.text.isEmpty || passwordController.text.isEmpty) {
      final snackBar = SnackBar(
        content: Text(
          'Por favor ingrese su correo y contraseña',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.red,
      );
      ScaffoldMessenger.of(context).showSnackBar(snackBar);
      return;
    }

    final snackBar = SnackBar(
      content: Row(
        children: [
          CircularProgressIndicator(),
          SizedBox(width: 20),
          Text('Iniciando sesion...'),
        ],
      ),
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(snackBar);
    }

    // prepare data
    final email = usernameController.text;
    final password = passwordController.text;

    try {
      await authService.signInWithEmailPassword(
        email, password);
        
        print("Login successful for user: $email");

        // Navigate to home screen
        if (mounted) {
          //hide the loading snackbar
          ScaffoldMessenger.of(context).hideCurrentSnackBar();

          // navigate to home screen
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const NavigationScreens(),),
          );
        }
    }
    catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
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
                                    'bienvenido a la comunidad',
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
                                  Text(
                                      'Iniciar Sesion',
                                      style: TextStyle(
                                        color: Color(0xFF2D8A8A),
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
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
                                hintText: 'Correo',
                                obscureText: false,
                                isEnabled: true,
                              ),
                              const SizedBox(height: 20),
                              MyTextField(
                                controller: passwordController,
                                hintText: 'Contraseña',
                                obscureText: true,
                                isEnabled: true,
                              ),
                              const SizedBox(height: 15),
                              Align(
                                alignment: Alignment.centerRight,
                                  child: GestureDetector(
                                    onTap:() {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) {
                                            return RecoverPasswordScreen();
                                          },
                                        ),
                                      );
                                    },
                                    child: Text(
                                      'Recuperar contraseña',
                                      style: TextStyle(
                                        color: Color(0xFF2D8A8A),
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),     
                                ),
                              const SizedBox(height: 40),
                              MyButton(
                                onTap: signUserIn,
                                text: "Iniciar Sesion",
                                color: Color(0xFF2D8A8A),
                              ),
                              const SizedBox(height: 80),
                              Center(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'No tienes cuenta? ',
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                    GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) {
                                              return RegisterScreen();
                                            },
                                          ),
                                        );
                                      },
                                      child: Text(
                                        'Registrate',
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
