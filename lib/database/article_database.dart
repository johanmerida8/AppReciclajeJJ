import 'package:reciclaje_app/model/article.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ArticleDatabase {
  final database = Supabase.instance.client.from('article');

  // create
  Future createArticle(Article newArticle) async {
    try {
      await database.insert(newArticle.toMap());
      print('Articulo creado correctamente: ${newArticle.name}');
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

      await database.update(oldArticle.toMap()).eq('idArticle', oldArticle.id!);

      print('Articulo actualizado correctamente: ${oldArticle.name}');
    } catch (e) {
      print('Error al actualizar el articulo: $e');
      rethrow;
    }
  }

  // delete (soft delete)
  Future deleteArticle(Article article) async {
    try {
      if (article.id == null) {
        throw Exception('El ID del articulo no puede ser nulo');
      }

      final res = await database
          .update({'state': 0}).eq('idArticle', article.id!); // Cambiar estado a 0
      
      print('Articulo eliminado correctamente: $res');
      return res;
    } catch (e) {
      print('Error al eliminar el articulo: $e');
      rethrow;
    }
  }
}