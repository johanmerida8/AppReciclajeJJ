import 'package:supabase_flutter/supabase_flutter.dart';
import '/model/admin/employee_model.dart';

class EmployeelistDb {
  final SupabaseClient client = Supabase.instance.client;

  /// ✅ Obtiene los usuarios distribuidores con su avatar e información básica
  Future<List<EmployeeModel>> fetchEmployee() async {
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
      return usersData.map((json) => EmployeeModel.fromJson(json)).toList();
    } catch (e) {
      print('❌ Error al obtener usuarios: $e');
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
