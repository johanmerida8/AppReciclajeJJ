import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:flutter/material.dart';

class Navigation extends StatefulWidget {
  Navigation({super.key});

  @override
  State<Navigation> createState() => _NavigationState();
}

class _NavigationState extends State<Navigation> {
  final List<Widget> _navigationItem = [
    const Icon(Icons.home),
    const Icon(Icons.add_box),
    const Icon(Icons.person),
  ];

  Color bgColor = Colors.blue;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        color: bgColor,
      ),
      bottomNavigationBar: CurvedNavigationBar(
        backgroundColor: bgColor,
        items: _navigationItem,
        index: 1,
        buttonBackgroundColor: Colors.greenAccent,
        animationDuration: Duration(milliseconds: 300),
        onTap: (index) {
          if (index == 0) {
            bgColor = Colors.blue;
          } else if (index == 1) {
            bgColor = Colors.orange;
          } else if (index == 2) {
            bgColor = Colors.pink;
          }

          setState(() {});
        },
      ),
    );
  }
}