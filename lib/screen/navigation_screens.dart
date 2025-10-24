import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:reciclaje_app/screen/RegisterRecycle_screen.dart';
import 'package:reciclaje_app/screen/home_screen.dart';
import 'package:reciclaje_app/screen/profile_screen.dart';

class NavigationScreens extends StatefulWidget {
  const NavigationScreens({super.key});

  @override
  State<NavigationScreens> createState() => _NavigationScreensState();
}

class _NavigationScreensState extends State<NavigationScreens> {
  int _currentIndex = 0;
  
  // List of screens to navigate between
  final List<Widget> _screens = [
    const HomeScreen(),
    const RegisterRecycleScreen(), // For registering recycling items
    const ProfileScreen(),
  ];

  final List<Widget> _navigationItems = [
    const Icon(Icons.home, size: 30, color: Colors.white),
    const Icon(Icons.add_box, size: 30, color: Colors.white),
    const Icon(Icons.person, size: 30, color: Colors.white),
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