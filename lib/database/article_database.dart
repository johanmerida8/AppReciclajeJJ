import 'package:reciclaje_app/database/photo_database.dart';
import 'package:reciclaje_app/model/article.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ArticleDatabase {
  final database = Supabase.instance.client.from('article');
  final photoDatabase = PhotoDatabase();

  // create
  Future<int> createArticle(Article newArticle) async {
    try {
      final res = await database
          .insert(newArticle.toMap())
          .select('idArticle')
          .single();
      print('Articulo creado correctamente: ${newArticle.name}');
      return res['idArticle'] as int;
    } catch (e) {
      print('Error al crear el articulo: $e');
      rethrow;
    }
  }

  // read
  Stream<List<Article>> get stream {
    return Supabase.instance.client
        .from('article')
        .stream(primaryKey: ['idArticle'])
        .map((maps) => maps
            .where((map) => map['state'] == 1) // Filtrar por estado activo
            .map((map) => Article.fromMap(map))
            .toList());
  }

  Future getAllArticles() async {
    try {
      final response = await database.select().eq('state', 1); // Solo artículos activos
      return response.map((map) => Article.fromMap(map)).toList();
    } catch (e) {
      print('Error al obtener artículos: $e');
      rethrow;
    }
  }

  // update
  Future updateArticle(Article oldArticle) async {
    try {
      if (oldArticle.id == null) {
        throw Exception('El ID del articulo no puede ser nulo');
      }

      // automatically update lastUpdate field
      oldArticle.lastUpdate = DateTime.now();

      await database.update(oldArticle.toMap()).eq('idArticle', oldArticle.id!);

      print('Articulo actualizado correctamente: ${oldArticle.name}');
    } catch (e) {
      print('Error al actualizar el articulo: $e');
      rethrow;
    }
  }

  Future updateArticleLastUpdate(int articleId) async {
    try {
      await database
          .update({'lastUpdate': DateTime.now().toIso8601String()})
          .eq('idArticle', articleId);
      print('Articulo lastUpdate actualizado correctamente: $articleId');
    } catch (e) {
      print('Error al actualizar lastUpdate del articulo: $e');
      rethrow;
    }
  }

  // delete (soft delete)
  Future deleteArticle(Article article) async {
    try {
      if (article.id == null) {
        throw Exception('El ID del articulo no puede ser nulo');
      }

      print('🚀 Iniciando eliminación del artículo ${article.id}: "${article.name}"');

      // 1. Hard delete all photos associated with this article
      print('🗑️ Paso 1: Eliminando fotos asociadas al artículo ${article.id}...');
      await photoDatabase.deleteAllPhotosForArticle(article.id!); 
      print('✅ Fotos eliminadas completamente');

      // 2. Soft delete the article
      print('📝 Paso 2: Marcando artículo como eliminado (state = 0)...');
      final res = await database
          .update({
            'state': 0,
            'lastUpdate': DateTime.now().toIso8601String(),
          }).eq('idArticle', article.id!);
      
      print('✅ Artículo ${article.id} eliminado correctamente');
      print('📊 Resultado: $res');
      
      return res;
    } catch (e) {
      print('❌ Error al eliminar el artículo: $e');
      rethrow;
    }
  }
}