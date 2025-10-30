import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:reciclaje_app/screen/empresa/company_admin_dashboard_screen.dart';
import 'package:reciclaje_app/screen/empresa/employees_screen.dart';
import 'package:reciclaje_app/screen/profile_screen.dart';
import 'package:reciclaje_app/auth/auth_service.dart';
import 'package:reciclaje_app/database/company_database.dart';
import 'package:reciclaje_app/database/users_database.dart';

class CompanyNavigationScreens extends StatefulWidget {
  const CompanyNavigationScreens({super.key});

  @override
  State<CompanyNavigationScreens> createState() => _CompanyNavigationScreensState();
}

class _CompanyNavigationScreensState extends State<CompanyNavigationScreens> {
  final AuthService _authService = AuthService();
  final CompanyDatabase _companyDb = CompanyDatabase();
  final UsersDatabase _usersDb = UsersDatabase();
  
  int _currentIndex = 0;
  int? _companyId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCompanyId();
  }

  Future<void> _loadCompanyId() async {
    try {
      final email = _authService.getCurrentUserEmail();
      if (email != null) {
        final user = await _usersDb.getUserByEmail(email);
        if (user != null && user.id != null) {
          final companyData = await _companyDb.database
              .select()
              .eq('adminUserID', user.id!)
              .maybeSingle();
          
          if (companyData != null) {
            setState(() {
              _companyId = companyData['idCompany'] as int?;
              _isLoading = false;
            });
          } else {
            setState(() => _isLoading = false);
          }
        }
      }
    } catch (e) {
      print('Error loading company: $e');
      setState(() => _isLoading = false);
    }
  }

  List<Widget> _getScreens() {
    if (_companyId == null) {
      return [
        const Center(child: Text('Error: No se encontró la empresa')),
        const Center(child: Text('Error: No se encontró la empresa')),
        const ProfileScreen(),
      ];
    }
    
    return [
      const CompanyAdminDashboardScreen(),
      EmployeesScreen(companyId: _companyId!),
      const ProfileScreen(),
    ];
  }

  final List<Widget> _navigationItems = [
    const Icon(Icons.dashboard, size: 30, color: Colors.white),
    const Icon(Icons.people, size: 30, color: Colors.white),
    const Icon(Icons.person, size: 30, color: Colors.white),
  ];

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: _getScreens()[_currentIndex],
      bottomNavigationBar: CurvedNavigationBar(
        backgroundColor: Colors.transparent,
        color: const Color(0xFF2D8A8A),
        buttonBackgroundColor: const Color.fromARGB(255, 45, 138, 138),
        height: 75,
        items: _navigationItems,
        index: _currentIndex,
        animationDuration: const Duration(milliseconds: 300),
        animationCurve: Curves.easeInOut,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }
}
