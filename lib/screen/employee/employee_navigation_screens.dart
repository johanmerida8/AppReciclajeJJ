import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:flutter/material.dart';
// import 'package:reciclaje_app/screen/distribuidor/edit_profile_screen.dart';
import 'package:reciclaje_app/screen/distribuidor/profile_screen.dart';
import 'package:reciclaje_app/screen/employee/employee_home_screen.dart';
// import 'package:reciclaje_app/screen/employee/employee_tasks_screen.dart';
import 'package:reciclaje_app/screen/employee/employee_map_screen.dart';
import 'package:reciclaje_app/screen/employee/employee_profile_screen.dart';
import 'package:reciclaje_app/theme/app_colors.dart';
// import 'package:reciclaje_app/screen/employee/employee_profile_screen.dart';

class EmployeeNavigationScreens extends StatefulWidget {
  const EmployeeNavigationScreens({super.key});

  @override
  State<EmployeeNavigationScreens> createState() => _EmployeeNavigationScreensState();
}

class _EmployeeNavigationScreensState extends State<EmployeeNavigationScreens> {
  int _currentIndex = 0;
  
  // ✅ Track which screens have been built
  final Map<int, Widget> _builtScreens = {};
  
  // ✅ Build screen only when first accessed
  Widget _buildScreen(int index) {
    if (_builtScreens.containsKey(index)) {
      return _builtScreens[index]!;
    }

    Widget screen;
    switch (index) {
      case 0:
        screen = const EmployeeMapScreen();
        break;
      case 1:
        screen = const EmployeeHomeScreen();
        break;
      case 2:
        screen = const EmployeeProfileScreen();
        break;
      default:
        screen = const Center(child: Text('Error'));
    }

    _builtScreens[index] = screen;
    return screen;
  }

  @override
  void dispose() {
    // ✅ Clear cached screens
    _builtScreens.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      // ✅ Build only the active screen
      body: _buildScreen(_currentIndex),
      bottomNavigationBar: CurvedNavigationBar(
        backgroundColor: Colors.transparent,
        color: AppColors.verdeOscuro,
        buttonBackgroundColor: AppColors.verdeOscuro,
        height: 60,
        items: const [
          Icon(Icons.map, size: 30, color: Colors.white),
          Icon(Icons.assignment, size: 30, color: Colors.white),
          Icon(Icons.person, size: 30, color: Colors.white),
        ],
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
