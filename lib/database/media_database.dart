import 'package:reciclaje_app/model/multimedia.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MediaDatabase {
  final database = Supabase.instance.client.from('multimedia');

  // create
  Future createPhoto(Multimedia newMedia) async {
    try {
      await database.insert(newMedia.toMap());
      print('Foto creada correctamente: ${newMedia.url}');
      print('📂 FilePath guardado: ${newMedia.filePath}');
    } catch (e) {
      print('Error al crear la foto: $e');
      rethrow;
    }
  }

  // read
  Stream<List<Multimedia>> get stream {
    return Supabase.instance.client
        .from('multimedia')
        .stream(primaryKey: ['idMultimedia'])
        .map((maps) => maps.map((map) => Multimedia.fromMap(map)).toList());
  }

  //getters
  // Get main Multimedia by URL pattern (e.g., articles/5/, users/10/, avatars/3/)
  Future<Multimedia?> getMainPhotoByPattern(String urlPattern) async {
    try {
      print('🔍 Buscando foto principal con patrón: $urlPattern');
      
      final response = await database
          .select('*')
          .like('filePath', '%$urlPattern%')
          .eq('isMain', true)
          .maybeSingle();
      
      if (response != null) {
        print('✅ Foto principal encontrada: ${response['fileName']}');
      } else {
        print('⚠️ No se encontró foto principal con patrón $urlPattern');
      }
      
      return response != null ? Multimedia.fromMap(response) : null;
    } catch (e) {
      print('❌ Error al obtener la foto principal: $e');
      rethrow;
    }
  }

  // get all Multimedias by URL pattern ordered by uploadOrder
  Future<List<Multimedia>> getPhotosByPattern(String urlPattern) async {
    try {
      print('🔍 Buscando fotos con patrón: $urlPattern');
      
      final response = await database
          .select('*')
          .like('filePath', '%$urlPattern%')
          .order('uploadOrder', ascending: true);
      
      print('📊 Respuesta de base de datos: ${response.length} fotos encontradas');
      for (var photo in response) {
        print('   - Foto: ${photo['fileName']} (ID: ${photo['idMultimedia']})');
      }
      
      return response.map<Multimedia>((map) => Multimedia.fromMap(map)).toList();
    } catch (e) {
      print('❌ Error al obtener las fotos: $e');
      rethrow;
    }
  }

  // get Multimedias count for upload order calculation
  Future<int> getPhotosCountByPattern(String urlPattern) async {
    try {
      final response = await database
          .select('idMultimedia')
          .like('filePath', '%$urlPattern%');
      
      return response.length;
    } catch (e) {
      print('Error getting Multimedias count: $e');
      return 0;
    }
  }

  // Check if entity has main Multimedia
  Future<bool> hasMainPhoto(String urlPattern) async {
    try {
      final response = await database
          .select('idMultimedia')
          .like('filePath', '%$urlPattern%')
          .eq('isMain', true)
          .limit(1);
      
      return response.isNotEmpty;
    } catch (e) {
      print('Error checking main Multimedia: $e');
      return false;
    }
  }

  // update
  Future updatePhoto(Multimedia oldMultimedia) async {
    try {
      if (oldMultimedia.id == null) {
        throw Exception('El ID de la foto no puede ser nulo');
      }

      await database.update(oldMultimedia.toMap()).eq('idMultimedia', oldMultimedia.id!);

      print('Foto actualizada correctamente: ${oldMultimedia.url}');
      print('📂 FilePath actualizado: ${oldMultimedia.filePath}');
    } catch (e) {
      print('Error al actualizar la foto: $e');
      rethrow;
    }
  }

  // Soft delete - mark as deleted (state = 0)
  Future deletePhoto(Multimedia Multimedia) async {
    try {
      if (Multimedia.id == null) {
        throw Exception('El ID de la foto no puede ser nulo');
      }

      // 1. delete from storage first
      if (Multimedia.fileName != null) {
        await _deleteFromStorage(Multimedia.fileName!);
      } else {
        print('⚠️ Foto sin filePath, no se puede eliminar del almacenamiento');
      }

      // 2. delete from database
      await database.delete().eq('idMultimedia', Multimedia.id!);

      print('Foto eliminada permanentemente: ${Multimedia.url}');
    } catch (e) {
      print('Error al eliminar la foto: $e');
      rethrow;
    }
  } 

  // Soft delete multiple Multimedias
  Future deleteMultiplePhotos(List<Multimedia> Multimedias) async {
    try {
      if (Multimedias.isEmpty) return;

      int deletedCount = 0;

      for (Multimedia photo in Multimedias) {
        if (photo.id != null) {
          // delete from storage first
          if (photo.filePath != null) {
            await _deleteFromStorage(photo.filePath!);
          } else {
            print('⚠️ Foto ID ${photo.id} sin filePath');
          }

          // delete from database
          await database.delete().eq('idMultimedia', photo.id!);
          deletedCount++;
        }
      }

      print('$deletedCount fotos eliminadas permanentemente');

    } catch (e) {
      print('Error al eliminar multiples fotos: $e');
      rethrow;
    }
  }

  Future deleteAllPhotosByPattern(String urlPattern) async {
    try {
      print('🔍 Obteniendo fotos con patrón: $urlPattern');
      
      // First get all Multimedias to delete from storage
      final Multimedias = await getPhotosByPattern(urlPattern);
      
      print('📸 Encontradas ${Multimedias.length} fotos para eliminar');

      // debug: print all Multimedia details
      for (int i = 0; i < Multimedias.length; i++) {
        final Multimedia = Multimedias[i];
        print('Foto ${i + 1}: ID=${Multimedia.id}, URL=${Multimedia.url}, FileName=${Multimedia.fileName}');
      }

      // Delete from storage first
      for (Multimedia photo in Multimedias) {
        if (photo.filePath != null) {
          print('🗑️ Eliminando archivo: ${photo.filePath}');
          await _deleteFromStorage(photo.filePath!);
        } else {
          print('⚠️ La foto con ID ${photo.id} no tiene fileName, no se puede eliminar del almacenamiento');
        }
      }

      print('🗑️ Eliminando ${Multimedias.length} registros de la base de datos...');
      // Delete from database - delete each Multimedia individually
      for (var photo in Multimedias) {
        if (photo.id != null) {
          await database.delete().eq('idMultimedia', photo.id!);
        }
      }
      print('✅ ${Multimedias.length} fotos eliminadas permanentemente');

    } catch (e) {
      print('❌ Error al eliminar todas las fotos: $e');
      rethrow;
    }
  }

  // helper to delete from Supabase Storage
  Future<void> _deleteFromStorage(String filePath) async {
    try {
      final storage = Supabase.instance.client.storage;

      print('🔧 Intentando eliminar: $filePath del bucket "multimedia"');
      
      final res = await storage.from('multimedia').remove([filePath]);
      
      print('✅ Archivo eliminado del almacenamiento: $filePath');
      print('📊 Resultado de eliminación del storage: $res');
    } catch (e) {
      print('❌ Error detallado al eliminar del almacenamiento: $e');
      print('📂 Ruta que falló: $filePath');
    }
  }

  Future setNewMainPhoto(String urlPattern) async {
    try {
      // First, unset current main Multimedia for this pattern
      final currentMultimedias = await getPhotosByPattern(urlPattern);
      for (var photo in currentMultimedias.where((p) => p.isMain)) {
        await database
            .update({'isMain': false})
            .eq('idMultimedia', photo.id!);
      }

      // Get the first available Multimedia for this pattern
      final Multimedias = await getPhotosByPattern(urlPattern);

      if (Multimedias.isNotEmpty) {
        // Set the first Multimedia as main
        await database
            .update({'isMain': true})
            .eq('idMultimedia', Multimedias.first.id!);

        print('Nueva foto principal establecida para patrón: $urlPattern');
      }
    } catch (e) {
      print('Error al establecer nueva foto principal: $e');
      rethrow;
    }
  }

  // check if a Multimedia is the main Multimedia before deleting
  Future<bool> isMainPhoto(Multimedia Multimedia) async {
    try {
      return Multimedia.isMain;
    } catch (e) {
      print('Error al verificar si es foto principal: $e');
      return false;
    }
  }
  
  // Helper to extract pattern from filePath (e.g., "articles/5" from "articles/5/Multimedia.jpg")
  String extractPattern(String filePath) {
    // Extract pattern like "articles/5", "users/10", "avatars/3"
    final parts = filePath.split('/');
    if (parts.length >= 2) {
      return '${parts[0]}/${parts[1]}';
    }
    return filePath;
  }
}
