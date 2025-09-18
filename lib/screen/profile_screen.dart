import 'package:flutter/material.dart';
import 'package:reciclaje_app/auth/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final authService = AuthService();

  void _logout() async {
    await authService.signOut();
  }

  void _changePassword() {
    // TODO: Navigate to change password screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Función de cambio de contraseña próximamente'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentEmail = authService.getCurrentUserEmail();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Mi Perfil',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF2D8A8A),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Profile header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF2D8A8A).withOpacity(0.1),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 50,
                    backgroundColor: Color(0xFF2D8A8A),
                    child: Icon(
                      Icons.person,
                      size: 60,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    currentEmail ?? 'Usuario',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D8A8A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '🌱 Contribuyendo al medio ambiente',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            
            // Profile options
            Expanded(
              child: ListView(
                children: [
                  _buildProfileOption(
                    icon: Icons.lock_outline,
                    title: 'Cambiar Contraseña',
                    subtitle: 'Actualiza tu contraseña',
                    onTap: _changePassword,
                  ),
                  _buildProfileOption(
                    icon: Icons.recycling,
                    title: 'Mis Reciclajes',
                    subtitle: 'Ver historial de reciclaje',
                    onTap: () {
                      // TODO: Navigate to recycling history
                    },
                  ),
                  _buildProfileOption(
                    icon: Icons.eco,
                    title: 'Impacto Ambiental',
                    subtitle: 'Tu contribución al planeta',
                    onTap: () {
                      // TODO: Show environmental impact
                    },
                  ),
                  _buildProfileOption(
                    icon: Icons.settings,
                    title: 'Configuración',
                    subtitle: 'Preferencias de la app',
                    onTap: () {
                      // TODO: Navigate to settings
                    },
                  ),
                  const SizedBox(height: 20),
                  _buildProfileOption(
                    icon: Icons.logout,
                    title: 'Cerrar Sesión',
                    subtitle: 'Salir de la aplicación',
                    onTap: _logout,
                    isDestructive: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          icon,
          color: isDestructive ? Colors.red : const Color(0xFF2D8A8A),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDestructive ? Colors.red : null,
          ),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}