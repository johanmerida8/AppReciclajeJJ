import 'package:supabase_flutter/supabase_flutter.dart';

class CycleDatabase {
  final database = Supabase.instance.client.from('cycle');

  // ✅ Get active cycle (state = 1)
  Future<Map<String, dynamic>?> getActiveCycle() async {
    final response = await database
        .select()
        .eq('state', 1)
        .maybeSingle();
    
    return response;
  }

  // ✅ Get cycle by ID
  Future<Map<String, dynamic>?> getCycleById(int cycleId) async {
    final response = await database
        .select()
        .eq('idCycle', cycleId)
        .maybeSingle();
    
    return response;
  }
}