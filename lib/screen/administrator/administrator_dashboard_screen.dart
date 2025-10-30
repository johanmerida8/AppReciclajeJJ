import 'package:flutter/material.dart';
import 'package:reciclaje_app/auth/auth_service.dart';
import 'package:reciclaje_app/database/company_database.dart';
import 'package:reciclaje_app/database/users_database.dart';
import 'package:reciclaje_app/model/company.dart';
import 'package:reciclaje_app/model/users.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final authService = AuthService();
  final CompanyDatabase _companyDb = CompanyDatabase();
  final UsersDatabase _usersDb = UsersDatabase();

  void _logout() async {
    await authService.signOut();
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
            onPressed: _logout, 
            icon: Icon(Icons.logout)
          )
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

          final allCompanies = snapshot.data ?? [];
          
          // Separate companies by approval status
          final pendingCompanies = allCompanies.where((c) => c.isApproved == 'Pending' || (c.isApproved == null && c.state == 0)).toList();
          final activeCompanies = allCompanies.where((c) => c.isApproved == 'Approved' && c.state == 1).toList();

          if (allCompanies.isEmpty) {
            return const Center(child: Text('No hay empresas registradas'));
          }

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              // Pending Approvals Section
              if (pendingCompanies.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.pending_actions, color: Colors.orange.shade700),
                      const SizedBox(width: 10),
                      Text(
                        'Solicitudes Pendientes (${pendingCompanies.length})',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                ...pendingCompanies.map((company) => _buildPendingCompanyCard(company)),
                const SizedBox(height: 20),
                const Divider(thickness: 2),
                const SizedBox(height: 20),
              ],

              // Active Companies Section
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.business, color: Colors.green.shade700),
                    const SizedBox(width: 10),
                    Text(
                      'Empresas Activas (${activeCompanies.length})',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              if (activeCompanies.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('No hay empresas activas'),
                  ),
                )
              else
                ...activeCompanies.map((company) => _buildActiveCompanyCard(company)),
            ],
          );
        },
      ),
    );
  }

  // Build card for pending companies
  Widget _buildPendingCompanyCard(Company company) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.orange.shade50,
      child: FutureBuilder<Users?>(
        future: _usersDb.getUserById(company.adminUserId),
        builder: (context, userSnapshot) {
          final adminUser = userSnapshot.data;
          
          return ExpansionTile(
            leading: const Icon(Icons.business_outlined, color: Colors.orange),
            title: Text(
              company.nameCompany ?? 'Sin nombre',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Admin: ${adminUser?.names ?? 'Cargando...'}'),
                Text('Email: ${adminUser?.email ?? ''}'),
              ],
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _approveCompany(company, adminUser),
                        icon: const Icon(Icons.check_circle),
                        label: const Text('Aprobar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _rejectCompany(company, adminUser),
                        icon: const Icon(Icons.cancel),
                        label: const Text('Rechazar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // Build card for active companies
  Widget _buildActiveCompanyCard(Company company) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: FutureBuilder<Users?>(
        future: _usersDb.getUserById(company.adminUserId),
        builder: (context, userSnapshot) {
          final adminUser = userSnapshot.data;
          
          return ListTile(
            leading: const Icon(Icons.apartment, color: Color(0xFF2D8A8A)),
            title: Text(company.nameCompany ?? 'Sin nombre'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Admin: ${adminUser?.names ?? 'Cargando...'}'),
                Text('Email: ${adminUser?.email ?? ''}'),
              ],
            ),
            trailing: Chip(
              label: const Text('Activa'),
              backgroundColor: Colors.green.shade100,
              labelStyle: TextStyle(color: Colors.green.shade700, fontSize: 12),
            ),
          );
        },
      ),
    );
  }

  // Approve company
  Future<void> _approveCompany(Company company, Users? adminUser) async {
    try {
      // Update company state to 1 (active) and isApproved to 'Approved'
      final updatedCompany = Company(
        companyId: company.companyId,
        nameCompany: company.nameCompany,
        adminUserId: company.adminUserId,
        state: 1,
        isApproved: 'Approved',
      );
      await _companyDb.updateCompany(updatedCompany);

      // Update user state to 1 (active)
      if (adminUser != null) {
        final updatedUser = Users(
          id: adminUser.id,
          names: adminUser.names,
          email: adminUser.email,
          role: adminUser.role,
          state: 1,
        );
        await _usersDb.updateUser(updatedUser);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Empresa aprobada exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al aprobar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Reject company
  Future<void> _rejectCompany(Company company, Users? adminUser) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar rechazo'),
        content: Text('¿Estás seguro de rechazar la empresa "${company.nameCompany}"?\n\nEsta acción marcará la empresa como rechazada.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Rechazar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Update company state and isApproved to 'Rejected'
      final updatedCompany = Company(
        companyId: company.companyId,
        nameCompany: company.nameCompany,
        adminUserId: company.adminUserId,
        state: 0,
        isApproved: 'Rejected',
      );
      await _companyDb.updateCompany(updatedCompany);

      // Update user state to 0 (inactive)
      if (adminUser != null) {
        final updatedUser = Users(
          id: adminUser.id,
          names: adminUser.names,
          email: adminUser.email,
          role: adminUser.role,
          state: 0,
        );
        await _usersDb.updateUser(updatedUser);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Solicitud rechazada'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al rechazar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
