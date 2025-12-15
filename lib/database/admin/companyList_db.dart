import 'package:supabase_flutter/supabase_flutter.dart';
import '/model/admin/company_model.dart';

class CompanyListDB {
  final SupabaseClient client = Supabase.instance.client;

  /// ✅ Obtiene todas las empresas con su administrador y logo principal
  Future<List<CompanyModel>> fetchCompanies() async {
    try {
      final response = await client.from('company').select('''
          idCompany,
          nameCompany,
          state,
          created_at,
          adminUserID,
          isApproved,
          users:adminUserID (names, email),
          employees(count),
          request(count)
        ''');

      final List companiesData = response as List;

      // Logo + conteos
      for (var company in companiesData) {
        final logoResponse = await client
            .from('multimedia')
            .select('url')
            .eq('entityType', 'empresa')
            .eq('entityID', company['idCompany'])
            .eq('isMain', true);

        company['avatarUrl'] =
            logoResponse.isNotEmpty ? logoResponse[0]['url'] : null;

        company['employeeCount'] =
            company['employees'] != null && company['employees'].isNotEmpty
                ? company['employees'][0]['count'] ?? 0
                : 0;

        company['totalArticlesApproved'] =
            company['request'] != null && company['request'].isNotEmpty
                ? company['request'][0]['count'] ?? 0
                : 0;
      }

      print('✅ Empresas obtenidas: $companiesData');

      return companiesData.map((json) => CompanyModel.fromJson(json)).toList();
    } catch (e) {
      print('❌ Error al obtener empresas: $e');
      return [];
    }
  }

  Future<bool> setCompanyState(int companyId, int newState) async {
    try {
      await client
          .from('company')
          .update({'state': newState})
          .eq('idCompany', companyId);
      return true;
    } catch (e) {
      print('❌ Error cambiando estado de compañía: $e');
      return false;
    }
  }

  Future<bool> updateCompanyApproval(int idCompany, String newStatus) async {
    try {
      final response = await client
          .from('company')
          .update({'isApproved': newStatus})
          .eq('idCompany', idCompany);

      return true;
    } catch (e) {
      print("❌ Error al cambiar aprobación: $e");
      return false;
    }
  }
}
