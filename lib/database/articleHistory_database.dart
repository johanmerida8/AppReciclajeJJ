import 'package:reciclaje_app/model/articleHistory.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ArticlehistoryDatabase {
  // Database reference
  final database = Supabase.instance.client.from('articleHistory');

  // Create
  Future createArticleHistory(articleHistory newLog) async {
    await database.insert(newLog.toMap());
  }

  // Read
  final stream = Supabase.instance.client.from('articleHistory').stream(
    primaryKey: ['id']
  ).map((data) => data.map((logMap) => articleHistory.fromMap(logMap)).toList());
}