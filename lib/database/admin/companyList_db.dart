import 'package:supabase_flutter/supabase_flutter.dart';
import '/model/admin/company_model.dart';

class CompanyListDB {
  final SupabaseClient client = Supabase.instance.client;

  /// ✅ Obtiene todas las empresas con su administrador y logo principal
  Future<List<CompanyModel>> fetchCompanies() async {
    try {
      // 1️⃣ Traer las empresas con el nombre del administrador
      final response = await client
          .from('company')
          .select('idCompany, nameCompany, state, created_at, adminUserID, users(names, email)');

      final List companiesData = response as List;

      // 2️⃣ Para cada empresa, buscamos su logo principal en multimedia
      for (var company in companiesData) {
        final logoResponse = await client
            .from('multimedia')
            .select('url')
            .eq('entityType', 'empresa') // 👈 importante: tipo de entidad
            .eq('entityID', company['idCompany']) // 👈 id de la empresa
            .eq('isMain', true) // solo el logo principal
            .maybeSingle();

        company['avatarUrl'] = logoResponse != null ? logoResponse['url'] : null;

      }

      // 4️⃣ Convertir los datos al modelo
      final List<CompanyModel> companies =
          companiesData.map((json) => CompanyModel.fromJson(json)).toList();

      return companies;
    } catch (e) {
      print('❌ Error al obtener empresas: $e');
      return [];
    }
  }
}
