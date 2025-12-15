import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:reciclaje_app/screen/administrator/companyList.dart';
import 'package:reciclaje_app/screen/administrator/userList.dart';
// import 'package:reciclaje_app/screen/distribuidor/profile_screen.dart';
import 'package:reciclaje_app/screen/administrator/ranking.dart';
import 'package:reciclaje_app/screen/administrator/cycleList.dart';
import 'package:reciclaje_app/theme/app_colors.dart';
// import 'package:reciclaje_app/screen/administrator/profileAdmin.dart';
import 'package:reciclaje_app/screen/administrator/profileAdministrator.dart';


class adminNavigationScreens extends StatefulWidget {
  const adminNavigationScreens({super.key});

  @override
  State<adminNavigationScreens> createState() => _adminNavigationScreensState();
}

class _adminNavigationScreensState extends State<adminNavigationScreens> {
  int _currentIndex = 0;
  
  // List of screens to navigate between
  final List<Widget> _screens = [

    const UserList(),
    const CompanyList(),
    const Ranking(),
    const CycleList(),
    // const ProfileAdmin(),
    const ProfileAdministratorScreen()
  ];

  final List<Widget> _navigationItems = [

    const Icon(Icons.people, size: 30, color: Colors.white),
    const Icon(Icons.business_rounded, size: 30, color: Colors.white),
    const Icon(Icons.leaderboard, size: 30, color: Colors.white),
    const Icon(Icons.timelapse, size: 30, color: Colors.white),
    const Icon(Icons.person, size: 30, color: Colors.white),

    // const Icon(Icons.person, size: 30, color: Colors.white),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _screens[_currentIndex],
      bottomNavigationBar: CurvedNavigationBar(
        backgroundColor: Colors.transparent,
        color: AppColors.verdeOscuro, // Your app's teal color
        // buttonBackgroundColor: const Color(0xFF2D8A8A), // Green accent
        buttonBackgroundColor: AppColors.verdeOscuro,
        height: 60,
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