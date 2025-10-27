// lib/screen/admin_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:reciclaje_app/database/company_database.dart';
import 'package:reciclaje_app/model/company.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final CompanyDatabase _companyDb = CompanyDatabase();
  final SupabaseClient _supabase = Supabase.instance.client;

  // abrir diálogo para crear empresa
  void _showCreateCompanyDialog() {
    final nameCompanyController = TextEditingController();
    final nameOwnerController = TextEditingController();
    final emailOwnerController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          title: Row(
            children: const [
              Icon(Icons.business, color: Color(0xFF2D8A8A)),
              SizedBox(width: 10),
              Text(
                'Registrar nueva empresa',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _InputField(
                  controller: nameCompanyController,
                  hint: 'Nombre de la empresa',
                ),
                const SizedBox(height: 10),
                _InputField(
                  controller: nameOwnerController,
                  hint: 'Nombre del administrador de empresa',
                ),
                const SizedBox(height: 10),
                _InputField(
                  controller: emailOwnerController,
                  hint: 'Correo del administrador',
                  keyboardType: TextInputType.emailAddress,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                backgroundColor: Colors.grey[300],
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Cancelar', style: TextStyle(color: Colors.black)),
            ),
            ElevatedButton(
              onPressed: () async {
                final nameCompany = nameCompanyController.text.trim();
                final nameOwner = nameOwnerController.text.trim();
                final emailOwner = emailOwnerController.text.trim();

                if (nameCompany.isEmpty || nameOwner.isEmpty || emailOwner.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Por favor completa todos los campos')),
                  );
                  return;
                }

                try {
                  // 🔹 1. Crear usuario admin-empresa
                  final userResponse = await _supabase
                      .from('users')
                      .insert({
                        'names': nameOwner,
                        'email': emailOwner,
                        'role': 'admin-empresa',
                        'state': 1,
                        'created_at': DateTime.now().toIso8601String(),
                      })
                      .select('idUser')
                      .maybeSingle();

                  if (userResponse == null || userResponse['idUser'] == null) {
                    throw Exception('Error al registrar el usuario');
                  }

                  final int adminId = userResponse['idUser'];

                  // 🔹 2. Crear la empresa vinculada al usuario
                  final company = Company(
                    nameCompany: nameCompany,
                    adminUserId: adminId,
                    state: 1,
                  );
                  await _companyDb.createCompany(company);

                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Empresa y usuario creados exitosamente'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error al crear empresa o usuario: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2D8A8A),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Registrar'),
            ),
          ],
        );
      },
    );
  }

  // borrar empresa
  Future<void> _deleteCompany(Company c) async {
    try {
      await _companyDb.deleteCompany(c);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Empresa eliminada')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F8),
      appBar: AppBar(
        title: const Text('Panel Administrador'),
        backgroundColor: const Color(0xFF2D8A8A),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showCreateCompanyDialog,
          ),
        ],
      ),
      body: StreamBuilder<List<Company>>(
        stream: _companyDb.stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final companies = snapshot.data ?? [];
          if (companies.isEmpty) {
            return const Center(child: Text('No hay empresas registradas'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: companies.length,
            itemBuilder: (context, index) {
              final c = companies[index];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
                child: ListTile(
                  leading: const Icon(Icons.apartment, color: Color(0xFF2D8A8A)),
                  title: Text(c.nameCompany ?? 'Sin nombre'),
                  subtitle: Text('ID admin: ${c.adminUserId ?? '-'}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    onPressed: () => _deleteCompany(c),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateCompanyDialog,
        backgroundColor: const Color(0xFF2D8A8A),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType keyboardType;

  const _InputField({
    required this.controller,
    required this.hint,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: const Color(0xFFF2F4F7),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
