import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:reciclaje_app/screen/administrator/companyList.dart';
import 'package:reciclaje_app/screen/administrator/userList.dart';

class   adminNavigationScreens extends StatefulWidget {
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
    
  ];

  final List<Widget> _navigationItems = [

    const Icon(Icons.people, size: 30, color: Colors.white),
    const Icon(Icons.business, size: 30, color: Colors.white),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _screens[_currentIndex],
      bottomNavigationBar: CurvedNavigationBar(
        backgroundColor: Colors.transparent,
        color: const Color(0xFF2D8A8A), // Your app's teal color
        // buttonBackgroundColor: const Color(0xFF2D8A8A), // Green accent
        buttonBackgroundColor: const Color.fromARGB(255, 45, 138, 138),
        height: 55,
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