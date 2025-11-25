import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:reciclaje_app/screen/distribuidor/RegisterRecycle_screen.dart';
import 'package:reciclaje_app/screen/distribuidor/home_screen.dart';
import 'package:reciclaje_app/screen/distribuidor/ranking_screen.dart';
import 'package:reciclaje_app/screen/distribuidor/profile_screen.dart';

class NavigationScreens extends StatefulWidget {
  const NavigationScreens({super.key});

  @override
  State<NavigationScreens> createState() => _NavigationScreensState();
}

class _NavigationScreensState extends State<NavigationScreens> {
  int _currentIndex = 0;
  
  // ✅ Create screens lazily to prevent memory leaks
  // Only the current screen is kept in memory
  late final List<Widget Function()> _screenBuilders;
  
  @override
  void initState() {
    super.initState();
    // Initialize screen builders
    _screenBuilders = [
      () => const HomeScreen(),
      () => const RegisterRecycleScreen(),
      () => const RankingScreen(),
      () => const ProfileScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      // ✅ Build only the current screen to prevent keeping all screens in memory
      body: IndexedStack(
        index: _currentIndex,
        children: _screenBuilders.map((builder) => builder()).toList(),
      ),
      bottomNavigationBar: CurvedNavigationBar(
        backgroundColor: Colors.transparent,
        color: const Color(0xFF2D8A8A), // Your app's teal color
        // buttonBackgroundColor: const Color(0xFF2D8A8A), // Green accent
        buttonBackgroundColor: const Color.fromARGB(255, 45, 138, 138),
        height: 75,
        items: const [
          Icon(Icons.home, size: 30, color: Colors.white),
          Icon(Icons.add_box, size: 30, color: Colors.white),
          Icon(Icons.leaderboard, size: 30, color: Colors.white),
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