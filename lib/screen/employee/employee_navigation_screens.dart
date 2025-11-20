import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:flutter/material.dart';
// import 'package:reciclaje_app/screen/distribuidor/edit_profile_screen.dart';
import 'package:reciclaje_app/screen/distribuidor/profile_screen.dart';
import 'package:reciclaje_app/screen/employee/employee_home_screen.dart';
// import 'package:reciclaje_app/screen/employee/employee_tasks_screen.dart';
import 'package:reciclaje_app/screen/employee/employee_map_screen.dart';
// import 'package:reciclaje_app/screen/employee/employee_profile_screen.dart';

class EmployeeNavigationScreens extends StatefulWidget {
  const EmployeeNavigationScreens({super.key});

  @override
  State<EmployeeNavigationScreens> createState() => _EmployeeNavigationScreensState();
}

class _EmployeeNavigationScreensState extends State<EmployeeNavigationScreens> {
  int _currentIndex = 0;
  
  // List of screens to navigate between
  final List<Widget> _screens = [
    const EmployeeMapScreen(),
    const EmployeeHomeScreen(),
    // const EmployeeTasksScreen(),
    // const EmployeeProfileScreen(),
    const ProfileScreen(),
  ];

  final List<Widget> _navigationItems = [
    const Icon(Icons.map, size: 30, color: Colors.white),
    const Icon(Icons.assignment, size: 30, color: Colors.white),
    // const Icon(Icons.assignment, size: 30, color: Colors.white),
    const Icon(Icons.person, size: 30, color: Colors.white),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _screens[_currentIndex],
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
