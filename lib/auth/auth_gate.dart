import 'package:flutter/material.dart';
import 'package:reciclaje_app/auth/auth_service.dart';
import 'package:reciclaje_app/screen/administrator/administrator_dashboard_screen.dart';
import 'package:reciclaje_app/screen/navigation_screens.dart';
import 'package:reciclaje_app/screen/login_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;
    final authService = AuthService();

    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        // ⏳ Loading auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final session = snapshot.data?.session;
        if (session == null) {
          // 🧱 No hay sesión -> mostrar login
          return const LoginScreen();
        }

        // 🧩 Hay sesión activa, buscar su rol en la tabla 'users'
        final email = session.user.email;
        if (email == null) {
          return const LoginScreen();
        }

        return FutureBuilder<String?>(
          future: authService.fetchUserRole(email),
          builder: (context, roleSnapshot) {
            if (roleSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (roleSnapshot.hasError) {
              return Scaffold(
                body: Center(child: Text('Error al obtener el rol: ${roleSnapshot.error}')),
              );
            }

            final role = roleSnapshot.data?.toLowerCase();

            // 🔎 Redirección según el rol
            if (role == 'administrador') {
              return const AdminDashboardScreen(); // 🔐 Admin general
            } else {
              // 👤 Distribuidor o cualquier otro rol por defecto
              return const NavigationScreens();
            }
          },
        );
      },
    );
  }
}
