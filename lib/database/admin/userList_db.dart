import 'package:supabase_flutter/supabase_flutter.dart';
import '/model/admin/user_model.dart';

class UserListDB {
  final SupabaseClient client = Supabase.instance.client;

  /// ✅ Obtiene los usuarios distribuidores con su avatar e información básica
  Future<List<UserModel>> fetchUsers() async {
    try {
      // 1️⃣ Traemos todos los distribuidores
      final response = await client
          .from('users')
          .select('idUser, names, email, state, created_at, role')
          .eq('role', 'distribuidor');

      final List usersData = response as List;

      // 2️⃣ Recorremos los usuarios para traer su imagen principal (avatar)
      for (var user in usersData) {
        // Avatar del usuario desde la tabla multimedia
        final avatarResponse =
            await client
                .from('multimedia')
                .select('url')
                .eq('entityType', 'distribuidor')
                .eq('entityID', user['idUser'])
                .eq('isMain', true)
                .maybeSingle();

        user['avatarUrl'] =
            avatarResponse != null ? avatarResponse['url'] : null;

        // 3️⃣ Contar artículos relacionados (ajusta el nombre del campo según tu BD)
        final articlesResponse = await client
            .from('article')
            .select('idArticle')
            .eq('userID', user['idUser']);

        user['articles'] = (articlesResponse as List).length;
      }

      // 4️⃣ Convertimos a lista de modelos
      return usersData.map((json) => UserModel.fromJson(json)).toList();
    } catch (e) {
      print('❌ Error al obtener usuarios: $e');
      return [];
    }
  }

  Future<List<UserModel>> fetchEmployees({required int companyId}) async {
    try {
      // Traer solo empleados de esa empresa
      final response = await client
          .from('employees')
          .select('''
      idEmployee,
      companyID,
      users (
        idUser,
        names,
        email,
        state,
        created_at
      )
    ''')
          .eq('companyID', companyId);

      final List employees = response as List;

      final List<UserModel> result = [];

      for (var emp in employees) {
        final user = emp["users"];
        final int employeeId = emp["idEmployee"];

        final avatar =
            await client
                .from('multimedia')
                .select('url')
                .eq('entityType', 'empleado')
                .eq('entityID', employeeId)
                .eq('isMain', true)
                .maybeSingle();

        final tasks = await client
            .from('tasks')
            .select('idTask')
            .eq('employeeID', employeeId);

        final articlesCount = (tasks as List).length;

        final json = {
          "idUser": user["idUser"],
          "names": user["names"],
          "email": user["email"],
          "state": user["state"],
          "created_at": user["created_at"],
          "avatarUrl": avatar?["url"],
          "articles": articlesCount,
          "role": "employee",
        };

        result.add(UserModel.fromJson(json));
      }

      return result;
    } catch (e) {
      print("❌ Error fetchEmployees: $e");
      return [];
    }
  }

  // Cambiar estado de usuario (0 = archivado, 1 = activo)
  Future<bool> setUserState(int userId, int newState) async {
    try {
      await client
          .from('users')
          .update({'state': newState})
          .eq('idUser', userId);

      return true;
    } catch (e) {
      print("❌ Error cambiando estado del usuario: $e");
      return false;
    }
  }
}
