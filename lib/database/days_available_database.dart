import 'package:reciclaje_app/model/daysAvailable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DaysAvailableDatabase {
  final database = Supabase.instance.client.from('daysAvailable');

  // create
  Future createDaysAvailable(daysAvailable newDaysAvailable) async {
    await database.insert(newDaysAvailable.toMap());
  }

  // read
  final stream = Supabase.instance.client.from('daysAvailable').stream(
    primaryKey: ['idDaysAvailable']
  ).map((data) => data.map((daysMap) => daysAvailable.fromMap(daysMap)).toList());

  // ✅ Get days available by article ID (single record)
  Future<daysAvailable?> getDaysAvailableByArticleId(int articleId) async {
    final response = await database
        .select()
        .eq('articleID', articleId)
        .maybeSingle();
    
    return response != null ? daysAvailable.fromMap(response) : null;
  }

  // ✅ Get all days available by article ID (multiple records)
  Future<List<daysAvailable>> getAllDaysAvailableByArticleId(int articleId) async {
    final response = await database
        .select()
        .eq('articleID', articleId);
    
    return response.map((record) => daysAvailable.fromMap(record)).toList();
  }

  // update
  Future updateDaysAvailable(daysAvailable oldDaysAvailable) async {
    await database.update(oldDaysAvailable.toMap()).eq('idDaysAvailable', oldDaysAvailable.id!);
  }

  // delete
  Future deleteDaysAvailable(daysAvailable daysAvailable) async {
    await database.delete().eq('idDaysAvailable', daysAvailable.id!);
  }
}