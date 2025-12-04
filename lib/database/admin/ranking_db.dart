import 'package:supabase_flutter/supabase_flutter.dart';
import '/model/admin/ranking_model.dart';

class RankingDB {
  final SupabaseClient client = Supabase.instance.client;

  Future<List<RankingModel>> fetchRanking() async {
    try {
      final response = await client
          .from('current_ranking2')
          .select('*')
          .order('position', ascending: true);

      return (response as List)
          .map((json) => RankingModel.fromJson(json))
          .toList();
    } catch (e) {
      print("❌ Error cargando ranking: $e");
      return [];
    }
  }
  
  Future<List<RankingModel>> fetchRankingByCycle(int cycleId) async {
  try {
    final response = await client
        .rpc('get_ranking_by_cycle', params: {'cycle_id': cycleId});

    if (response == null) return [];

    return (response as List)
        .map((json) => RankingModel.fromJson(json))
        .toList();
  } catch (e) {
    print("❌ Error cargando ranking por ciclo: $e");
    return [];
  }
}



}


