/*

AUTH GATE - this will continuosly listen to auth state changes

unauthenticated -> show login screen
authenticated -> show home screen

*/

import 'package:flutter/material.dart';
// import 'package:reciclaje_app/screen/home_screen.dart';
import 'package:reciclaje_app/screen/login_screen.dart';
import 'package:reciclaje_app/screen/navigation_screens.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: Supabase.instance.client.auth.onAuthStateChange, 
      builder: (context, snapshot) {
        // loading...
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
        // check if there is a valid session currently
        final session = snapshot.hasData ? snapshot.data!.session : null;

        if (session != null) {
          return NavigationScreens();
        } else {
          return LoginScreen();
        }
      }
    );
  }
}