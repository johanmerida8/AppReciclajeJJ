// ignore_for_file: use_build_context_synchronously, avoid_print

import 'package:flutter/material.dart';
import 'package:reciclaje_app/auth/auth_service.dart';
import 'package:reciclaje_app/components/my_button.dart';
import 'package:reciclaje_app/components/my_textfield.dart';
import 'package:reciclaje_app/components/password_validator.dart';
import 'package:reciclaje_app/database/users_database.dart';
// import 'package:reciclaje_app/model/users.dart';
import 'package:reciclaje_app/screen/administrator/administrator_dashboard_screen.dart';
// import 'package:reciclaje_app/screen/home_screen.dart';
import 'package:reciclaje_app/screen/login_screen.dart';
import 'package:reciclaje_app/screen/navigation_screens.dart';
import 'package:reciclaje_app/utils/password_utils.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  bool _isLoading = false;

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
    final names = namesController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text;
    final confirmPassword = confirmPasswordController.text;

    // Validaciones básicas
    if (names.isEmpty || email.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor llena todos los campos'), backgroundColor: Colors.red),
      );
      return;
    }

    // Email simple regex
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingrese un correo válido'), backgroundColor: Colors.red),
      );
      return;
    }

    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Las contraseñas no coinciden'), backgroundColor: Colors.red),
      );
      return;
    }

    if (!PasswordUtils.isPasswordValid(password)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La contraseña no cumple con los requisitos'), backgroundColor: Colors.red),
      );
      return;
    }

    // evitar múltiples envíos
    if (_isLoading) return;
    setState(() => _isLoading = true);

    // show loading snackbar (opcional)
    final loadingSnack = SnackBar(
      content: Row(children: const [
        CircularProgressIndicator(),
        SizedBox(width: 16),
        Text('Creando cuenta...'),
      ]),
      duration: const Duration(minutes: 1),
    );
    ScaffoldMessenger.of(context).showSnackBar(loadingSnack);

    try {
      // --- Lógica para rol ---
      String role = 'distribuidor';
      if (names.toLowerCase() == 'admin' || names.toLowerCase() == 'administrador') {
        // comprobar si ya existe un administrador
        final existingAdmin = await Supabase.instance.client
            .from('users')
            .select('idUser')
            .eq('role', 'administrador')
            .maybeSingle();

        if (existingAdmin != null) {
          // ya existe admin -> impedir crear otro
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ya existe un administrador registrado. No se puede crear otro.'), backgroundColor: Colors.red),
          );
          setState(() => _isLoading = false);
          return;
        }
        role = 'administrador';
      }

      // --- Comprobar email duplicado en tabla users (evita crear auth duplicado) ---
      final existingUser = await Supabase.instance.client
          .from('users')
          .select('idUser')
          .eq('email', email)
          .maybeSingle();

      if (existingUser != null) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ya existe una cuenta con ese correo'), backgroundColor: Colors.red),
        );
        setState(() => _isLoading = false);
        return;
      }

      // --- Crear cuenta usando AuthService (que ahora acepta role) ---
      final res = await authService.signUpWithEmailPassword(email, password, names, role: role);

      // Verificar resultado
      if (res.user == null) {
        throw Exception('No se creó la cuenta (respuesta vacía del servidor)');
      }


      // éxito
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cuenta creada exitosamente como $role'), backgroundColor: Colors.green),
        );

        // no necesitas navegar si usas AuthGate; pero si quieres dirigir admin inmediatamente:
        if (role == 'administrador') {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const AdminDashboardScreen())
          );
        } else {
          Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const NavigationScreens()));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al crear la cuenta: $e'), backgroundColor: Colors.red),
        );
      }
      print('Error during registration: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
                      SizedBox(
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

                                const SizedBox(height: 20),
                                MyTextField(
                                  controller: confirmPasswordController,
                                  hintText: 'Confirmar contraseña',
                                  obscureText: true, isEnabled: true,
                                ),
                        
                        
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
