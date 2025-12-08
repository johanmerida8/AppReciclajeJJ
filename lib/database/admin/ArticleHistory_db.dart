import 'package:supabase_flutter/supabase_flutter.dart';
import '/model/admin/article_history_model.dart';

class ArticleHistoryDB {
  final SupabaseClient client = Supabase.instance.client;

  /// Trae el historial de un artículo
  Future<List<ArticleHistoryModel>> getArticleHistory(int articleID) async {
    try {
      final response = await client
          .from('articleHistory')
          .select()
          .eq('ArticleID', articleID)
          .order('created_at', ascending: false);

      final data = response as List<dynamic>;
      return data.map((json) => ArticleHistoryModel.fromJson(json)).toList();
    } catch (e) {
      print('❌ Error en getArticleHistory: $e');
      return [];
    }
  }
  
  Future<String> _getUserName(int userId) async {
    try {
      final res =
          await Supabase.instance.client
              .from('users')
              .select('names')
              .eq('idUser', userId)
              .single();
      return res['names'] ?? 'Usuario';
    } catch (_) {
      return 'Usuario';
    }
  }

  Future<String> _getCompanyName(int companyId) async {
    try {
      final res =
          await Supabase.instance.client
              .from('company')
              .select('nameCompany')
              .eq('idCompany', companyId)
              .single();
      return res['nameCompany'] ?? 'Empresa';
    } catch (_) {
      return 'Empresa';
    }
  }
}
