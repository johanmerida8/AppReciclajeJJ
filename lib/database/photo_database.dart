import 'package:reciclaje_app/model/photo.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PhotoDatabase {
  final database = Supabase.instance.client.from('photo');

  // create
  Future createPhoto(Photo newPhoto) async {
    try {
      await database.insert(newPhoto.toMap());
      print('Foto creada correctamente: ${newPhoto.url}');
      print('📂 FilePath guardado: ${newPhoto.filePath}');
    } catch (e) {
      print('Error al crear la foto: $e');
      rethrow;
    }
  }

  // read
  Stream<List<Photo>> get stream {
    return Supabase.instance.client
        .from('photo')
        .stream(primaryKey: ['idPhoto'])
        .map((maps) => maps.map((map) => Photo.fromMap(map)).toList());
  }

  //getters
  Future<Photo?> getMainPhotoByArticleId(int articleId) async {
    try {
      print('🔍 Buscando foto principal para artículo ID: $articleId');
      
      final response = await database
          .select('*')
          .eq('article_id', articleId)
          .eq('isMain', true)
          .maybeSingle();
      
      if (response != null) {
        print('✅ Foto principal encontrada: ${response['fileName']}');
      } else {
        print('⚠️ No se encontró foto principal para artículo $articleId');
      }
      
      return response != null ? Photo.fromMap(response) : null;
    } catch (e) {
      print('❌ Error al obtener la foto principal: $e');
      rethrow;
    }
  }

  // get all photos for an article ordered by uploadOrder
  Future<List<Photo>> getPhotosByArticleId(int articleId) async {
    try {
      print('🔍 Buscando fotos para artículo ID: $articleId');
      
      final response = await database
          .select('*')
          .eq('article_id', articleId)
          .order('uploadOrder', ascending: true);
      
      print('📊 Respuesta de base de datos: ${response.length} fotos encontradas');
      for (var photo in response) {
        print('   - Foto: ${photo['fileName']} (ID: ${photo['idPhoto']})');
      }
      
      return response.map<Photo>((map) => Photo.fromMap(map)).toList();
    } catch (e) {
      print('❌ Error al obtener las fotos del artículo: $e');
      rethrow;
    }
  }

  // get photos count for upload order calculation
  Future<int> getPhotosCountByArticleId(int articleId) async {
    try {
      final response = await database
          .select('idPhoto')
          .eq('article_id', articleId);
      
      return response.length;
    } catch (e) {
      print('Error getting photos count: $e');
      return 0;
    }
  }

  // Check if article has main photo
  Future<bool> hasMainPhoto(int articleId) async {
    try {
      final response = await database
          .select('idPhoto')
          .eq('article_id', articleId)
          .eq('isMain', true)
          .limit(1);
      
      return response.isNotEmpty;
    } catch (e) {
      print('Error checking main photo: $e');
      return false;
    }
  }

  // update
  Future updatePhoto(Photo oldPhoto) async {
    try {
      if (oldPhoto.id == null) {
        throw Exception('El ID de la foto no puede ser nulo');
      }

      await database.update(oldPhoto.toMap()).eq('idPhoto', oldPhoto.id!);

      print('Foto actualizada correctamente: ${oldPhoto.url}');
      print('📂 FilePath actualizado: ${oldPhoto.filePath}');
    } catch (e) {
      print('Error al actualizar la foto: $e');
      rethrow;
    }
  }

  // Soft delete - mark as deleted (state = 0)
  Future deletePhoto(Photo photo) async {
    try {
      if (photo.id == null) {
        throw Exception('El ID de la foto no puede ser nulo');
      }

      // 1. delete from storage first
      if (photo.fileName != null) {
        await _deleteFromStorage(photo.fileName!);
      } else {
        print('⚠️ Foto sin filePath, no se puede eliminar del almacenamiento');
      }

      // 2. delete from database
      await database.delete().eq('idPhoto', photo.id!);

      print('Foto eliminada permanentemente: ${photo.url}');
    } catch (e) {
      print('Error al eliminar la foto: $e');
      rethrow;
    }
  } 

  // Soft delete multiple photos
  Future deleteMultiplePhotos(List<Photo> photos) async {
    try {
      if (photos.isEmpty) return;

      int deletedCount = 0;

      for (Photo photo in photos) {
        if (photo.id != null) {
          // delete from storage first
          if (photo.filePath != null) {
            await _deleteFromStorage(photo.filePath!);
          } else {
            print('⚠️ Foto ID ${photo.id} sin filePath');
          }

          // delete from database
          await database.delete().eq('idPhoto', photo.id!);
          deletedCount++;
        }
      }

      print('$deletedCount fotos eliminadas permanentemente');

    } catch (e) {
      print('Error al eliminar multiples fotos: $e');
      rethrow;
    }
  }

  Future deleteAllPhotosForArticle(int articleId) async {
    try {
      print('🔍 Obteniendo fotos del artículo $articleId...');
      
      // First get all photos to delete from storage
      final photos = await getPhotosByArticleId(articleId);
      
      print('📸 Encontradas ${photos.length} fotos para eliminar');

      // debug: print all photo details
      for (int i = 0; i < photos.length; i++) {
        final photo = photos[i];
        print('Foto ${i + 1}: ID=${photo.id}, URL=${photo.url}, FileName=${photo.fileName}');
      }

      // Delete from storage first
      for (Photo photo in photos) {
        if (photo.filePath != null) {
          print('🗑️ Eliminando archivo: ${photo.filePath}');
          await _deleteFromStorage(photo.filePath!);
        } else {
          print('⚠️ La foto con ID ${photo.id} no tiene fileName, no se puede eliminar del almacenamiento');
        }
      }

      print('🗑️ Eliminando ${photos.length} registros de la base de datos...');
      // Delete from database
      final deleteResult = await database.delete().eq('article_id', articleId);
      

      print('✅ ${photos.length} fotos del artículo $articleId eliminadas permanentemente');

      print('📊 Resultado de eliminación: $deleteResult');
      return deleteResult;

    } catch (e) {
      print('❌ Error al eliminar todas las fotos del artículo: $e');
      rethrow;
    }
  }

  // helper to delete from Supabase Storage
  Future<void> _deleteFromStorage(String filePath) async {
    try {
      final storage = Supabase.instance.client.storage;

      print('🔧 Intentando eliminar: $filePath del bucket "article-images"');
      
      final res = await storage.from('article-images').remove([filePath]);
      
      print('✅ Archivo eliminado del almacenamiento: $filePath');
      print('📊 Resultado de eliminación del storage: $res');
    } catch (e) {
      print('❌ Error detallado al eliminar del almacenamiento: $e');
      print('📂 Ruta que falló: $filePath');
    }
  }

  Future setNewMainPhoto(int articleId) async {
    try {
      // First, unset current main photo
      await database
          .update({'isMain': false})
          .eq('article_id', articleId)
          .eq('isMain', true);

      // Get the first available active photo for this article
      final photos = await getPhotosByArticleId(articleId);

      if (photos.isNotEmpty) {
        // Set the first photo as main
        await database
            .update({'isMain': true})
            .eq('idPhoto', photos.first.id!);

        print('Nueva foto principal establecida para el articulo $articleId');
      }
    } catch (e) {
      print('Error al establecer nueva foto principal: $e');
      rethrow;
    }
  }

  // check if a photo is the main photo before deleting
  Future<bool> isMainPhoto(Photo photo) async {
    try {
      if (photo.articleID == null) return false;
      
      final mainPhoto = await getMainPhotoByArticleId(photo.articleID!);
      return mainPhoto?.id == photo.id;
    } catch (e) {
      print('Error al verificar si es foto principal: $e');
      return false;
    }
  }
}