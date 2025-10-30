import 'package:flutter/material.dart';
import 'package:reciclaje_app/auth/auth_service.dart';
import 'package:reciclaje_app/database/company_database.dart';
import 'package:reciclaje_app/database/users_database.dart';
import 'package:reciclaje_app/model/company.dart';
import 'package:reciclaje_app/screen/empresa/company_profile_screen.dart';
import 'package:reciclaje_app/screen/empresa/employees_screen.dart';
import 'package:reciclaje_app/screen/login_screen.dart';

class CompanyAdminDashboardScreen extends StatefulWidget {
  const CompanyAdminDashboardScreen({super.key});

  @override
  State<CompanyAdminDashboardScreen> createState() => _CompanyAdminDashboardScreenState();
}

class _CompanyAdminDashboardScreenState extends State<CompanyAdminDashboardScreen> {
  final AuthService _authService = AuthService();
  final CompanyDatabase _companyDb = CompanyDatabase();
  final UsersDatabase _usersDb = UsersDatabase();

  Company? _company;
  int? _companyId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCompanyData();
  }

  Future<void> _loadCompanyData() async {
    try {
      final email = _authService.getCurrentUserEmail();
      if (email == null) {
        _navigateToLogin();
        return;
      }

      // Get user to find their company
      final user = await _usersDb.getUserByEmail(email);
      if (user == null || user.id == null) {
        _navigateToLogin();
        return;
      }

      // Find company where this user is the admin
      final allCompanies = await _companyDb.database
          .select()
          .eq('adminUserID', user.id!)
          .maybeSingle();

      if (allCompanies != null) {
        setState(() {
          _company = Company.fromMap(allCompanies);
          _companyId = _company!.companyId;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error loading company data: $e');
      setState(() => _isLoading = false);
    }
  }

  void _navigateToLogin() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  Future<void> _signOut() async {
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
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
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

    if (_company == null || _companyId == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text('No se encontró información de la empresa'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _signOut,
                child: const Text('Cerrar Sesión'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F8),
      appBar: AppBar(
        title: Text(_company!.nameCompany ?? 'Panel Empresa'),
        backgroundColor: const Color(0xFF2D8A8A),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
            tooltip: 'Cerrar Sesión',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Section
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2D8A8A), Color(0xFF1A6B6B)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.business, size: 48, color: Colors.white),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Bienvenido',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          _company!.nameCompany ?? 'Empresa',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Menu Options
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  _buildMenuCard(
                    icon: Icons.people,
                    title: 'Empleados',
                    subtitle: 'Gestionar empleados',
                    color: Colors.blue,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EmployeesScreen(companyId: _companyId!),
                        ),
                      );
                    },
                  ),
                  _buildMenuCard(
                    icon: Icons.recycling,
                    title: 'Reciclajes',
                    subtitle: 'Ver reciclajes',
                    color: Colors.green,
                    onTap: () {
                      // TODO: Navigate to recycles screen
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Próximamente: Gestión de Reciclajes')),
                      );
                    },
                  ),
                  _buildMenuCard(
                    icon: Icons.assignment,
                    title: 'Asignaciones',
                    subtitle: 'Asignar empleados',
                    color: Colors.orange,
                    onTap: () {
                      // TODO: Navigate to assignments screen
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Próximamente: Asignaciones')),
                      );
                    },
                  ),
                  _buildMenuCard(
                    icon: Icons.person,
                    title: 'Mi Perfil',
                    subtitle: 'Editar perfil',
                    color: Colors.purple,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CompanyProfileScreen(company: _company!),
                        ),
                      ).then((_) => _loadCompanyData()); // Reload after edit
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 40, color: color),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
