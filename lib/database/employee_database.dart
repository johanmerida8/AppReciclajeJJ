import 'package:reciclaje_app/model/employee.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EmployeeDatabase {
  final database = Supabase.instance.client.from('employees');
  final usersDb = Supabase.instance.client.from('users');

  // Create employee (creates user first, then employee record)
  Future<void> createEmployee({
    required String names,
    required String email,
    required int companyId,
    required String temporaryPassword,
  }) async {
    // Create user record in database with state=0 (inactive)
    final userResponse = await usersDb.insert({
      'names': names,
      'email': email,
      'role': 'empleado',
      'state': 0, // Inactive until first login and password change
    }).select().single();

    final userId = userResponse['idUser'] as int;

    // Create employee record with temporary password
    await database.insert({
      'userID': userId,
      'companyID': companyId,
      'temporaryPassword': temporaryPassword,
    });

    // Note: Employee logs in with email + temporary password
    // No email sent - admin shares password manually via dialog
  }

  // Get all employees for a company with user data
  Stream<List<Map<String, dynamic>>> getEmployeesByCompany(int companyId) {
    return Supabase.instance.client
        .from('employees')
        .stream(primaryKey: ['idEmployee'])
        .eq('companyID', companyId)
        .map((employees) async {
          // For each employee, fetch their user data
          List<Map<String, dynamic>> employeesWithUsers = [];
          for (var emp in employees) {
            final userId = emp['userID'];
            final userResponse = await usersDb
                .select()
                .eq('idUser', userId)
                .single();
            
            employeesWithUsers.add({
              ...emp,
              'user': userResponse,
            });
          }
          return employeesWithUsers;
        })
        .asyncMap((future) => future);
  }

  // Get employee by email (checks both tables)
  Future<Map<String, dynamic>?> getEmployeeByEmail(String email) async {
    // Find user first
    final userResponse = await usersDb
        .select()
        .eq('email', email)
        .eq('role', 'empleado')
        .maybeSingle();
    
    if (userResponse == null) return null;

    final userId = userResponse['idUser'];
    
    // Find employee record
    final empResponse = await database
        .select()
        .eq('userID', userId)
        .maybeSingle();
    
    if (empResponse == null) return null;

    return {
      ...empResponse,
      'user': userResponse,
    };
  }

  // Update employee
  Future<void> updateEmployee(int idEmployee, Employee employee) async {
    await database
        .update(employee.toMap())
        .eq('idEmployee', idEmployee);
  }

  // Delete employee (soft delete user)
  Future<void> deleteEmployee(int userId) async {
    await usersDb
        .update({'state': 0})
        .eq('idUser', userId);
  }

  // Activate employee after password creation
  Future<void> activateEmployee(int userId) async {
    // Update user state
    await usersDb
        .update({'state': 1})
        .eq('idUser', userId);
    
    // Clear temporary password
    await database
        .update({'temporaryPassword': null})
        .eq('userID', userId);
  }

  // Check if employee has temporary password
  Future<bool> hasTemporaryPassword(String email) async {
    try {
      final employeeData = await getEmployeeByEmail(email);
      return employeeData != null && employeeData['temporaryPassword'] != null;
    } catch (e) {
      return false;
    }
  }
}
