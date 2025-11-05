import 'package:flutter/material.dart';
import 'package:reciclaje_app/auth/auth_service.dart';
import 'package:reciclaje_app/database/users_database.dart';
import 'package:reciclaje_app/database/employee_database.dart';
import 'package:reciclaje_app/model/users.dart';
import 'package:reciclaje_app/components/my_textfield.dart';
import 'package:reciclaje_app/screen/distribuidor/login_screen.dart';

class EmployeeProfileScreen extends StatefulWidget {
  const EmployeeProfileScreen({super.key});

  @override
  State<EmployeeProfileScreen> createState() => _EmployeeProfileScreenState();
}

class _EmployeeProfileScreenState extends State<EmployeeProfileScreen> {
  final AuthService _authService = AuthService();
  final UsersDatabase _usersDb = UsersDatabase();
  final EmployeeDatabase _employeeDb = EmployeeDatabase();
  
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  
  Users? _currentUser;
  Map<String, dynamic>? _employeeData;
  String? _companyName;
  bool _isLoading = true;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final email = _authService.getCurrentUserEmail();
      if (email != null) {
        final user = await _usersDb.getUserByEmail(email);
        final empData = await _employeeDb.getEmployeeByEmail(email);
        
        if (mounted && user != null) {
          setState(() {
            _currentUser = user;
            _employeeData = empData;
            nameController.text = user.names ?? '';
            emailController.text = user.email ?? '';
            _isLoading = false;
          });
          
          // Load company name if employee data exists
          if (empData != null) {
            _loadCompanyName(empData['companyId'] as int);
          }
        }
      }
    } catch (e) {
      print('Error loading user data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadCompanyName(int companyId) async {
    try {
      // TODO: Load company name from CompanyDatabase
      if (mounted) {
        setState(() {
          _companyName = 'Empresa de Reciclaje'; // Placeholder
        });
      }
    } catch (e) {
      print('Error loading company: $e');
    }
  }

  Future<void> _updateProfile() async {
    final name = nameController.text.trim();
    final email = emailController.text.trim();

    if (name.isEmpty || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor completa todos los campos')),
      );
      return;
    }

    try {
      final updatedUser = Users(
        id: _currentUser?.id,
        names: name,
        email: email,
        role: _currentUser?.role,
        state: _currentUser?.state,
      );

      await _usersDb.updateUser(updatedUser);

      if (mounted) {
        setState(() => _isEditing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Perfil actualizado exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
        _loadUserData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al actualizar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar Sesión'),
        content: const Text('¿Estás seguro de que deseas cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Cerrar Sesión'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _authService.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F8),
      appBar: AppBar(
        title: const Text('Mi Perfil'),
        backgroundColor: const Color(0xFF2D8A8A),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => setState(() => _isEditing = true),
            ),
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _updateProfile,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Profile Avatar
            CircleAvatar(
              radius: 50,
              backgroundColor: const Color(0xFF2D8A8A),
              child: Text(
                _currentUser?.names?.substring(0, 1).toUpperCase() ?? 'E',
                style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // User role badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF2D8A8A).withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Empleado',
                style: TextStyle(
                  color: const Color(0xFF2D8A8A),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 30),

            // Profile Information Card
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Información Personal',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D8A8A),
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    MyTextField(
                      controller: nameController,
                      hintText: 'Nombre Completo',
                      obscureText: false,
                      isEnabled: _isEditing,
                    ),
                    const SizedBox(height: 16),
                    
                    MyTextField(
                      controller: emailController,
                      hintText: 'Correo Electrónico',
                      obscureText: false,
                      isEnabled: false, // Email cannot be changed
                    ),
                    
                    if (_companyName != null) ...[
                      const SizedBox(height: 20),
                      _buildInfoRow(
                        icon: Icons.business,
                        label: 'Empresa',
                        value: _companyName!,
                      ),
                    ],
                    
                    const SizedBox(height: 20),
                    _buildInfoRow(
                      icon: Icons.check_circle,
                      label: 'Estado',
                      value: _currentUser?.state == 1 ? 'Activo' : 'Inactivo',
                      valueColor: _currentUser?.state == 1 ? Colors.green : Colors.orange,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),

            // Logout Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _logout,
                icon: const Icon(Icons.logout),
                label: const Text('Cerrar Sesión'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: valueColor ?? Colors.black87,
          ),
        ),
      ],
    );
  }
}
