import 'package:flutter/material.dart';
import 'package:reciclaje_app/components/my_textfield.dart';
import 'package:reciclaje_app/database/company_database.dart';
import 'package:reciclaje_app/database/users_database.dart';
import 'package:reciclaje_app/model/company.dart';
import 'package:reciclaje_app/model/users.dart';

class CompanyProfileScreen extends StatefulWidget {
  final Company company;

  const CompanyProfileScreen({super.key, required this.company});

  @override
  State<CompanyProfileScreen> createState() => _CompanyProfileScreenState();
}

class _CompanyProfileScreenState extends State<CompanyProfileScreen> {
  final CompanyDatabase _companyDb = CompanyDatabase();
  final UsersDatabase _usersDb = UsersDatabase();

  final companyNameController = TextEditingController();
  final ownerNameController = TextEditingController();
  final ownerEmailController = TextEditingController();

  Users? _adminUser;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final adminUser = await _usersDb.getUserById(widget.company.adminUserId);
      
      setState(() {
        _adminUser = adminUser;
        companyNameController.text = widget.company.nameCompany ?? '';
        ownerNameController.text = adminUser?.names ?? '';
        ownerEmailController.text = adminUser?.email ?? '';
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading data: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateProfile() async {
    final newCompanyName = companyNameController.text.trim();
    final newOwnerName = ownerNameController.text.trim();
    final newOwnerEmail = ownerEmailController.text.trim();

    if (newCompanyName.isEmpty || newOwnerName.isEmpty || newOwnerEmail.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor completa todos los campos')),
      );
      return;
    }

    // Validate email
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(newOwnerEmail)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingrese un correo válido')),
      );
      return;
    }

    try {
      // Update company
      final updatedCompany = Company(
        companyId: widget.company.companyId,
        nameCompany: newCompanyName,
        adminUserId: widget.company.adminUserId,
        state: widget.company.state,
        isApproved: widget.company.isApproved,
      );
      await _companyDb.updateCompany(updatedCompany);

      // Update admin user
      if (_adminUser != null) {
        final updatedUser = Users(
          id: _adminUser!.id,
          names: newOwnerName,
          email: newOwnerEmail,
          role: _adminUser!.role,
          state: _adminUser!.state,
        );
        await _usersDb.updateUser(updatedUser);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Perfil actualizado exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al actualizar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    companyNameController.dispose();
    ownerNameController.dispose();
    ownerEmailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F8),
      appBar: AppBar(
        title: const Text('Mi Perfil'),
        backgroundColor: const Color(0xFF2D8A8A),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Header
            Center(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2D8A8A),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.business,
                      size: 60,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.company.nameCompany ?? 'Empresa',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      widget.company.isApproved == 'Approved' ? 'Aprobada' : 'Pendiente',
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),

            // Company Information Section
            const Text(
              'Información de la Empresa',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D8A8A),
              ),
            ),
            const SizedBox(height: 16),
            MyTextField(
              controller: companyNameController,
              hintText: 'Nombre de la empresa',
              obscureText: false,
              isEnabled: true,
            ),
            const SizedBox(height: 32),

            // Owner Information Section
            const Text(
              'Información del Administrador',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D8A8A),
              ),
            ),
            const SizedBox(height: 16),
            MyTextField(
              controller: ownerNameController,
              hintText: 'Nombre del administrador',
              obscureText: false,
              isEnabled: true,
            ),
            const SizedBox(height: 16),
            MyTextField(
              controller: ownerEmailController,
              hintText: 'Correo electrónico',
              obscureText: false,
              isEnabled: true,
            ),
            const SizedBox(height: 40),

            // Update Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _updateProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2D8A8A),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Actualizar Perfil',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
