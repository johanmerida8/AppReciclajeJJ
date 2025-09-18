import 'package:reciclaje_app/model/deliver.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DeliverDatabase {
  final database = Supabase.instance.client.from('deliver');

  // create a new deliver
  Future<int> createDeliver(Deliver newDeliver) async {
    try {
      final res = await database
          .insert(newDeliver.toMap())
          .select('idDeliver')
          .single();
      final deliverId = res['idDeliver'] as int;
      print('Entrega creada correctamente: $deliverId');
      return deliverId;
    } catch (e) {
      print('Error al crear la entrega: $e');
      rethrow;
    }
  }

  // read
  Stream<List<Deliver>> get stream {
    return Supabase.instance.client
        .from('deliver')
        .stream(primaryKey: ['idDeliver'])
        .map((maps) => maps
            .where((map) => map['state'] == 1) // Filtrar por estado activo
            .map((map) => Deliver.fromMap(map))
            .toList());
  }

  //get by id
  Future<Deliver?> getDeliverById(int id) async {
    try {
      final response =
          await database.select().eq('idDeliver', id).eq('state', 1).single();
      return Deliver.fromMap(response);
    } catch (e) {
      print('Error al obtener la entrega por ID: $e');
      return null;
    }
  }

  // Future getDeliverById() async {
  //   try {
  //     final response = await database.select().eq('state', 1); // Solo entregas activas
  //     return response.map((map) => Deliver.fromMap(map)).toList();
  //   } catch (e) {
  //     print('Error al obtener entregas: $e');
  //     rethrow;
  //   }
  // }

  // update
  Future updateDeliver(Deliver oldDeliver) async {
    try {
      if (oldDeliver.id == null) {
        throw Exception('El ID de la entrega no puede ser nulo');
      }

      await database.update(oldDeliver.toMap()).eq('idDeliver', oldDeliver.id!);
      print('Entrega actualizada correctamente: ${oldDeliver.address}');
    } catch (e) {
      print('Error al actualizar la entrega: $e');
      rethrow;
    }
  }

  // delete
  Future deleteDeliver(Deliver deliver) async {
    try {
      if (deliver.id == null) {
        throw Exception('El ID de la entrega no puede ser nulo');
      }

      final res = await database
          .update({'state': 0}).eq('idDeliver', deliver.id!);
      print('Entrega eliminada correctamente: $res');
      return res;
    } catch (e) {
      print('Error al eliminar la entrega: $e');
      rethrow;
    }
  }
}