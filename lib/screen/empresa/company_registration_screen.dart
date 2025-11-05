// ignore_for_file: use_build_context_synchronously, avoid_print

import 'package:flutter/material.dart';
import 'package:reciclaje_app/auth/auth_service.dart';
import 'package:reciclaje_app/components/my_button.dart';
import 'package:reciclaje_app/components/my_textfield.dart';
import 'package:reciclaje_app/components/password_validator.dart';
import 'package:reciclaje_app/database/company_database.dart';
import 'package:reciclaje_app/database/users_database.dart';
import 'package:reciclaje_app/model/company.dart';
import 'package:reciclaje_app/screen/distribuidor/login_screen.dart';
import 'package:reciclaje_app/utils/password_utils.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CompanyRegistrationScreen extends StatefulWidget {
  const CompanyRegistrationScreen({super.key});

  @override
  State<CompanyRegistrationScreen> createState() => _CompanyRegistrationScreenState();
}

class _CompanyRegistrationScreenState extends State<CompanyRegistrationScreen> {
  final authService = AuthService();
  final userDatabase = UsersDatabase();
  final companyDatabase = CompanyDatabase();

  // Controllers for Step 1 (Owner Info)
  final ownerNameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  // Controllers for Step 2 (Company Info)
  final companyNameController = TextEditingController();

  int _currentStep = 0;
  bool _showPasswordValidator = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    passwordController.addListener(() {
      setState(() {
        _showPasswordValidator = passwordController.text.isNotEmpty;
      });
    });
  }

  @override
  void dispose() {
    ownerNameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    companyNameController.dispose();
    super.dispose();
  }

  // Validate Step 1
  bool _validateStep1() {
    final ownerName = ownerNameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text;
    final confirmPassword = confirmPasswordController.text;

    if (ownerName.isEmpty || email.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      _showSnackBar('Por favor llena todos los campos', Colors.red);
      return false;
    }

    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(email)) {
      _showSnackBar('Ingrese un correo válido', Colors.red);
      return false;
    }

    if (password != confirmPassword) {
      _showSnackBar('Las contraseñas no coinciden', Colors.red);
      return false;
    }

    if (!PasswordUtils.isPasswordValid(password)) {
      _showSnackBar('La contraseña no cumple con los requisitos', Colors.red);
      return false;
    }

    return true;
  }

  // Validate Step 2
  bool _validateStep2() {
    final companyName = companyNameController.text.trim();

    if (companyName.isEmpty) {
      _showSnackBar('Por favor ingresa el nombre de la empresa', Colors.red);
      return false;
    }

    return true;
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  // Go to next step
  void _nextStep() {
    if (_currentStep == 0) {
      if (_validateStep1()) {
        setState(() => _currentStep = 1);
      }
    } else if (_currentStep == 1) {
      _submitRegistration();
    }
  }

  // Go to previous step
  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  // Submit the complete registration
  Future<void> _submitRegistration() async {
    if (!_validateStep2()) return;

    if (_isLoading) return;
    setState(() => _isLoading = true);

    _showSnackBar('Registrando empresa...', Colors.blue);

    try {
      final ownerName = ownerNameController.text.trim();
      final email = emailController.text.trim();
      final password = passwordController.text;
      final companyName = companyNameController.text.trim();

      // Check if email already exists
      final existingUser = await Supabase.instance.client
          .from('users')
          .select('idUser')
          .eq('email', email)
          .maybeSingle();

      if (existingUser != null) {
        _showSnackBar('Ya existe una cuenta con ese correo', Colors.red);
        setState(() => _isLoading = false);
        return;
      }

      // Create auth account and user with state = 0 (pending approval)
      final res = await authService.signUpWithEmailPassword(
        email,
        password,
        ownerName,
        role: 'admin-empresa',
      );

      if (res.user == null) {
        throw Exception('No se creó la cuenta');
      }

      // Get the created user
      final createdUser = await userDatabase.getUserByEmail(email);
      if (createdUser == null || createdUser.id == null) {
        throw Exception('Error al obtener usuario creado');
      }

      // Set user state to 0 (pending approval)
      await Supabase.instance.client
          .from('users')
          .update({'state': 0})
          .eq('idUser', createdUser.id!);

      // Create company with state = 0 (pending approval)
      final company = Company(
        nameCompany: companyName,
        adminUserId: createdUser.id,
        state: 0, // Pending approval
        isApproved: 'Pending',
      );
      await companyDatabase.createCompany(company);

      // Sign out the user (they can't access until approved)
      await authService.signOut();

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        
        // Show success dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: const [
                Icon(Icons.check_circle, color: Colors.green, size: 30),
                SizedBox(width: 10),
                Text('Registro Exitoso'),
              ],
            ),
            content: const Text(
              'Tu solicitud de registro ha sido enviada.\n\n'
              'El administrador revisará tu solicitud y te notificaremos cuando sea aprobada.\n\n'
              'Podrás iniciar sesión una vez que tu cuenta sea aprobada.',
              style: TextStyle(fontSize: 14),
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close dialog
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2D8A8A),
                ),
                child: const Text('Entendido'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        _showSnackBar('Error al registrar: $e', Colors.red);
      }
      print('Error during company registration: $e');
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
          child: Column(
            children: [
              // Top section with back button and title
              Container(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Registrar Empresa',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Step indicator
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                child: Row(
                  children: [
                    _buildStepIndicator(0, 'Dueño'),
                    Expanded(
                      child: Container(
                        height: 2,
                        color: _currentStep > 0 ? Colors.white : Colors.white30,
                      ),
                    ),
                    _buildStepIndicator(1, 'Empresa'),
                  ],
                ),
              ),

              // Form card
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
                    child: _currentStep == 0 ? _buildStep1() : _buildStep2(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator(int step, String label) {
    final isActive = _currentStep >= step;
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? Colors.white : Colors.white30,
          ),
          child: Center(
            child: Text(
              '${step + 1}',
              style: TextStyle(
                color: isActive ? const Color(0xFF2D8A8A) : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Información del Dueño',
          style: TextStyle(
            color: Color(0xFF2D8A8A),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Ingresa los datos del dueño o administrador de la empresa',
          style: TextStyle(color: Colors.grey, fontSize: 14),
        ),
        const SizedBox(height: 30),
        MyTextField(
          controller: ownerNameController,
          hintText: 'Nombre completo del dueño',
          obscureText: false,
          isEnabled: true,
        ),
        const SizedBox(height: 20),
        MyTextField(
          controller: emailController,
          hintText: 'Correo electrónico',
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
        if (_showPasswordValidator) ...[
          const SizedBox(height: 8),
          PasswordValidator(password: passwordController.text),
        ],
        const SizedBox(height: 20),
        MyTextField(
          controller: confirmPasswordController,
          hintText: 'Confirmar contraseña',
          obscureText: true,
          isEnabled: true,
        ),
        const SizedBox(height: 40),
        MyButton(
          onTap: _nextStep,
          text: "Siguiente",
          color: const Color(0xFF2D8A8A),
        ),
        const SizedBox(height: 20),
        Center(
          child: TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Información de la Empresa',
          style: TextStyle(
            color: Color(0xFF2D8A8A),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Ingresa el nombre de tu empresa de reciclaje',
          style: TextStyle(color: Colors.grey, fontSize: 14),
        ),
        const SizedBox(height: 30),
        MyTextField(
          controller: companyNameController,
          hintText: 'Nombre de la empresa',
          obscureText: false,
          isEnabled: true,
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue.shade700),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Tu solicitud será revisada por el administrador antes de ser aprobada.',
                  style: TextStyle(
                    color: Colors.blue.shade700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 40),
        MyButton(
          onTap: _isLoading ? () {} : _nextStep,
          text: _isLoading ? "Registrando..." : "Registrar Empresa",
          color: const Color(0xFF2D8A8A),
        ),
        const SizedBox(height: 20),
        Center(
          child: TextButton(
            onPressed: _previousStep,
            child: const Text(
              'Volver',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ),
      ],
    );
  }
}
