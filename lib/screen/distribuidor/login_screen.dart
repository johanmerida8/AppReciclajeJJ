import 'package:flutter/material.dart';
import 'package:reciclaje_app/auth/auth_service.dart';
import 'package:reciclaje_app/components/my_button.dart';
import 'package:reciclaje_app/components/my_textfield.dart';
import 'package:reciclaje_app/database/employee_database.dart';
// import 'package:reciclaje_app/screen/home_screen.dart';
import 'package:reciclaje_app/screen/distribuidor/navigation_screens.dart';
import 'package:reciclaje_app/screen/distribuidor/recover_password.dart';
import 'package:reciclaje_app/screen/distribuidor/register_screen.dart';
import 'package:reciclaje_app/screen/empresa/company_registration_screen.dart';
import 'package:reciclaje_app/screen/administrator/administrator_dashboard_screen.dart';
import 'package:reciclaje_app/screen/empresa/company_navigation_screens.dart';
import 'package:reciclaje_app/screen/empresa/employee_change_password_screen.dart';
import 'package:reciclaje_app/screen/employee/employee_navigation_screens.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final authService = AuthService();
  final employeeDb = EmployeeDatabase();

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
      // First check if this is an employee trying to login with temporary password
      final employeeData = await employeeDb.getEmployeeByEmail(email);

      if (employeeData != null) {
        final tempPassword = employeeData['temporaryPassword'] as String?;
        final userState = employeeData['user']['state'] as int?;

        // ✅ Employee logging in with temporary password - force password change
        if (tempPassword != null && tempPassword == password) {
          if (mounted) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder:
                    (_) => EmployeeChangePasswordScreen(
                      employeeData: employeeData,
                    ),
              ),
            );
          }
          return;
        }

        // ✅ Check if employee account is deactivated (state=0 and no temp password)
        if (userState == 0 && tempPassword == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Tu cuenta ha sido desactivada por el administrador. Contacta a tu empresa para más información.',
                ),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 5),
              ),
            );
          }
          return;
        }
      }

      // Regular Supabase authentication
      await authService.signInWithEmailPassword(email, password);

      print("Login successful for user: $email");

      // ✅ Check if user account is active (state=1) before proceeding
      final userResponse =
          await Supabase.instance.client
              .from('users')
              .select('state')
              .eq('email', email)
              .single();

      final userState = userResponse['state'] as int?;
      if (userState != 1) {
        // Sign them out immediately
        await authService.signOut();

        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "Tu cuenta está inactiva. Contacta al administrador.",
              ),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 5),
            ),
          );
        }
        return;
      }

      // Check if user is approved before proceeding
      final isApproved = await authService.isUserApproved(email);

      if (!isApproved) {
        // Sign them out immediately
        await authService.signOut();

        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "Tu cuenta está pendiente de aprobación por el administrador",
              ),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 5),
            ),
          );
        }
        return;
      }

      // Check user role to navigate to correct screen
      final role = await authService.fetchUserRole(email);

      // Navigate to appropriate screen based on role
      if (mounted) {
        //hide the loading snackbar
        ScaffoldMessenger.of(context).hideCurrentSnackBar();

        // show success snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Inicio de sesion exitoso!"),
            backgroundColor: Colors.green,
          ),
        );

        // navigate based on role
        if (role?.toLowerCase() == 'administrador') {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const AdminDashboardScreen(),
            ),
          );
        } else if (role?.toLowerCase() == 'admin-empresa') {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const CompanyNavigationScreens(),
            ),
          );
        } else if (role?.toLowerCase() == 'empleado') {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const EmployeeNavigationScreens(),
            ),
          );
        } else {
          // distribuidor or any other role
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const NavigationScreens()),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error al iniciar sesion"),
            backgroundColor: Colors.red,
          ),
        );
      }
      print("Error during login: $e");
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
                                  onTap: () {
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
                              const SizedBox(height: 20),
                              // Company Registration Button
                              Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                  ),
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder:
                                              (context) =>
                                                  const CompanyRegistrationScreen(),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.business, size: 20),
                                    label: const Text(
                                      'Registrar Empresa de Reciclaje',
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFF2D8A8A),
                                      side: const BorderSide(
                                        color: Color(0xFF2D8A8A),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                        horizontal: 20,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
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
