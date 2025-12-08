import 'package:supabase_flutter/supabase_flutter.dart';
import '/model/admin/cycle_model.dart';
import '/model/admin/cycle_star_model.dart';

class CycleListDB {
  final SupabaseClient client = Supabase.instance.client;

  /// Obtiene la lista de ciclos con info básica
  Future<List<CycleModel>> fetchCycles() async {
    try {
      final response = await client
          .from('cycle')
          .select(
            'idCycle, name, created_at, startDate, endDate, topQuantity, state',
          )
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => CycleModel.fromJson(json))
          .toList();
    } catch (e) {
      print('❌ Error al obtener ciclos: $e');
      return [];
    }
  }

  /// Trae los valores de estrellas para un ciclo específico
  Future<List<CycleStarModel>> fetchCycleStarValues(int cycleId) async {
    try {
      //print("👉 Ejecutando query con cycleId = $cycleId");

      final response = await client
          .from('starValue')
          .select('stars, points')
          .eq('cycleID', cycleId);

      //print("🟦 Respuesta valores estrellas Supabase: $response");

      return (response as List)
          .map((json) => CycleStarModel.fromJson(json))
          .toList();
    } catch (e) {
      print('❌ Error al obtener star values: $e');
      return [];
    }
  }

  /// Crea un nuevo ciclo con valores de estrellas por defecto
  Future<int?> createCycle({
    required String name,
    required DateTime startDate,
    required DateTime endDate,
    required int topQuantity,
  }) async {
    try {
      if (await hasOverlappingCycle(startDate, endDate)) {
        print("❌ Hay otro ciclo que se cruza en fechas");
        return null;
      }

      final response =
          await client
              .from('cycle')
              .insert({
                'name': name,
                'startDate': startDate.toIso8601String(),
                'endDate': endDate.toIso8601String(),
                'topQuantity': topQuantity,
                'state': 1,
              })
              .select('idCycle')
              .single();

      final int idCycle = response['idCycle'];

      // ❌ Aquí ya no insertamos nada por defecto
      return idCycle;
    } catch (e) {
      print("❌ Error creando ciclo: $e");
      return null;
    }
  }

  /// Verifica si hay ciclos activos que se solapen con las fechas dadas
  Future<bool> hasOverlappingCycle(DateTime start, DateTime end) async {
    final resp =
        await client
            .from('cycle')
            .select('idCycle')
            .eq('state', 1)
            .filter('startDate', 'lte', end.toIso8601String())
            .filter('endDate', 'gte', start.toIso8601String())
            .limit(1)
            .maybeSingle();

    return resp != null;
  }

  // Guarda los valores de estrellas para un ciclo
  Future<void> saveStarValues(int cycleId, List<CycleStarModel> stars) async {
    final data =
        stars
            .map(
              (s) => {'cycleID': cycleId, 'stars': s.stars, 'points': s.points},
            )
            .toList();

    await client.from('starValue').insert(data);
  }
  
  // Desactiva un ciclo (cambia su estado a 0)
  Future<bool> deactivateCycle(int cycleId) async {
    try {
      await client.from('cycle').update({'state': 0}).eq('idCycle', cycleId);

      return true;
    } catch (e) {
      print('❌ Error desactivando ciclo: $e');
      return false;
    }
  }
  
}
