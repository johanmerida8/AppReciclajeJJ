  import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
  import 'package:reciclaje_app/model/multimedia.dart';

  class PhotoValidation extends StatelessWidget {
    final List<Multimedia> allPhotos;
    final List<Multimedia> photosToDelete;
    final List<XFile>? pickedImages;
    final Multimedia? mainPhoto;
    final int maxPhotos;

    const PhotoValidation({
      super.key,
      required this.allPhotos,
      required this.photosToDelete,
      this.pickedImages,
      this.mainPhoto,
      this.maxPhotos = 10, // Changed from 5 to 10
    });

    @override
    Widget build(BuildContext context) {
      // Calculate unique photos properly
      final uniquePhotos = <int>{};
      
      // Add main Multimedia ID if exists and has valid ID
      if (mainPhoto != null && mainPhoto!.id != null) {
        uniquePhotos.add(mainPhoto!.id!);
      }
      
      // Add all other photos IDs
      for (final photo in allPhotos) {
        if (photo.id != null) {
          uniquePhotos.add(photo.id!);
        }
      }
      
      final totalPhotos = uniquePhotos.length;
      final photosToDeleteCount = photosToDelete.length;
      final remainingAfterDeletion = totalPhotos - photosToDeleteCount;

      // add picked images (local images not yet uploaded)
      final pickedImagesCount = pickedImages?.length ?? 0;

      // total photos = remaining database photos + new picked images
      final totalPhotosAfterChanges = remainingAfterDeletion + pickedImagesCount;

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 25.0, vertical: 5),
        child: Text(
          'Fotos: $totalPhotosAfterChanges/$maxPhotos • Elige primero la foto principal de la publicación',
          style: TextStyle(
            fontSize: 12,
            color: totalPhotosAfterChanges >= maxPhotos ? Colors.orange : Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      );

      
    }

    
  }
