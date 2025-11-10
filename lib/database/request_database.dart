import 'package:reciclaje_app/model/request.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RequestDatabase {
  final database = Supabase.instance.client.from('request');

  // create
  Future createRequest(Request newRequest) async {
    await database.insert(newRequest.toMap());
  }

  // read
  final stream = Supabase.instance.client.from('request').stream(
    primaryKey: ['idRequest']
  ).map((data) => data.map((requestMap) => Request.fromMap(requestMap)).toList());

  // update
  Future updateRequest(Request oldRequest) async {
    await database.update(oldRequest.toMap()).eq('idRequest', oldRequest.id!);
  }

  // delete
  Future deleteRequest(Request request) async {
    await database.delete().eq('idRequest', request.id!);
  }
}