import 'package:reciclaje_app/model/userPointsLog.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserpointslogDatabase {
  final database = Supabase.instance.client.from('userPointsLog');

  // create
  Future createPointsLog(userPointsLog newLog) async {
    await database.insert(newLog.toMap());
  }

  // read
  final stream = Supabase.instance.client.from('userPointsLog').stream(
    primaryKey: ['idUserPointsLog']
  ).map((data) => data.map((logMap) => userPointsLog.fromMap(logMap)).toList());
}