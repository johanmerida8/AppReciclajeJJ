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
        screen = const HomeScreen();
        break;
      case 1:
        screen = const RegisterRecycleScreen();
        break;
      case 2:
        screen = const RankingScreen();
        break;
      case 3:
        screen = const ProfileScreen();
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