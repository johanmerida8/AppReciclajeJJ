import 'package:reciclaje_app/model/task.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TaskDatabase {
  final database = Supabase.instance.client.from('tasks');

  // create
  Future createTask(Task newTask) async {
    await database.insert(newTask.toMap());
  }

  // read
  final stream = Supabase.instance.client.from('tasks').stream(
    primaryKey: ['idTask']
  ).map((data) => data.map((taskMap) => Task.fromMap(taskMap)).toList());

  // update
  Future updateTask(Task oldTask) async {
    await database.update(oldTask.toMap()).eq('idTask', oldTask.idTask!);
  }

  // delete
  Future deleteRequest(Task task) async {
    await database.delete().eq('idTask', task.idTask!);
  }
}