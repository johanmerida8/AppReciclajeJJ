import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:reciclaje_app/utils/Fixed43Cropper.dart';

class ImageRow extends StatelessWidget {
  final List<XFile> images;
  final Function(List<XFile>) onImagesChanged;
  final int maxImages;

  const ImageRow({
    super.key,
    required this.images,
    required this.onImagesChanged,
    this.maxImages = 5,
  });

  Future<XFile> _openCropper(BuildContext context, XFile file) async {
    final res = await Navigator.of(context, rootNavigator: true).push<XFile>(
      MaterialPageRoute(fullscreenDialog: true, builder: (_) => Fixed43Cropper(file: file)),
    );
    return res ?? file;
  }

  void _addImages(bool fromGallery, BuildContext context) async {
    if (images.length >= maxImages) return;

    final picker = ImagePicker();

    if (fromGallery) {
      // Multi-select from gallery
      final List<XFile> picked = await picker.pickMultiImage(
        imageQuality: 85,
      );
      if (picked.isEmpty) return;

      final remaining = maxImages - images.length;
      final toProcess = picked.take(remaining).toList();

      // Process sequentially; one crop screen per image; no extra yes/no dialog
      final List<XFile> results = [];
      for (final file in toProcess) {
        final cropped = await _openCropper(context, file);
        results.add(cropped);
      }
      onImagesChanged([...images, ...results]);
    } else {
      // Single from camera
      final XFile? shot = await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
      if (shot == null) return;
      final cropped = await _openCropper(context, shot);
      onImagesChanged([...images, cropped]);
    }
  
  }

  void _showImageSourceOptions(BuildContext context) {
    final parent = context;
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      builder: (sheetCtx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Galería'),
              onTap: () {
                Navigator.pop(sheetCtx);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!parent.mounted) return;
                  _addImages(true, parent);
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Cámara'),
              onTap: () {
                Navigator.pop(sheetCtx);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!parent.mounted) return;
                  _addImages(false, parent);
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  // Future<XFile?> _cropImage(XFile imageFile, BuildContext context) async {

  //   try {
  //     final res = await Navigator.of(context).push<XFile>(
  //       MaterialPageRoute(
  //         builder: (_) => Fixed43Cropper(file: imageFile),
  //       ),
  //     );  
  //     return res ?? imageFile;
  //   } catch (e) {
  //     debugPrint('Error cropping image: $e');
  //     return imageFile;
  //   }
  // }

  // Future<ui.Image> _decodeImage(Uint8List bytes) {
  //   final c = Completer<ui.Image>();
  //   try {
  //     ui.decodeImageFromList(bytes, (ui.Image img) {
  //       if (!c.isCompleted) c.complete(img);
  //     });
  //   } catch (e, s) {
  //     if (!c.isCompleted) c.completeError(e, s);
  //   }
  //   return c.future;
  // }

  //show dialog to ask if user wants to crop the image
  // Future<bool?> _showCropDialog(BuildContext context) async {

  //   // check if the context is still valid before showing dialog
  //   if (!context.mounted) return false;

  //   return showDialog<bool>(
  //     context: context, 
  //     builder: (BuildContext context) {
  //       return AlertDialog(
  //         title: const Text('Recortar Imagen'),
  //         content: const Text('¿Deseas recortar la imagen antes de agregarla?'),
  //         actions: [
  //           TextButton(
  //             onPressed: () => Navigator.of(context).pop(false), 
  //             child: const Text('No, usar original'),
  //           ),
  //           TextButton(
  //             onPressed: () => Navigator.of(context).pop(true), 
  //             child: const Text('Sí, recortar'),
  //           ),
  //         ],
  //       );
  //     }
  //   );
  // }

  // add crop option to existing images
  void _cropExistingImage(int index, BuildContext context) async {
    try {
      final image = images[index];
      final cropped = await _openCropper(context, image);
      final newImages = List<XFile>.from(images)..[index] = cropped;
      onImagesChanged(newImages);
    } catch (e) {
      debugPrint('Error cropping existing image: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al recortar la imagen.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _removeImage(int index) {
    final newImages = List<XFile>.from(images);
    newImages.removeAt(index);
    onImagesChanged(newImages);
  }

  void _viewImage(BuildContext context, XFile image) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          contentPadding: EdgeInsets.zero,
          content: SizedBox(
            width: double.maxFinite,
            child: Image.file(
              File(image.path),
              fit: BoxFit.contain,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Horizontal scrollable row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
    
              GestureDetector(
                onTap: images.length < maxImages ? () => _showImageSourceOptions(context) : null,
                child: Container(
                  padding: const EdgeInsets.only(top: 10, bottom: 10),
                  width: 80,
                  margin: const EdgeInsets.symmetric(horizontal: 25.0),
                  decoration: BoxDecoration(
                    color: images.length < maxImages 
                        ? Colors.white54
                        : Colors.grey,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.add,
                        color: images.length < maxImages
                            ? const Color(0xFF058896)
                            : Colors.grey.shade600,
                        size: 30,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        images.isEmpty ? 'Agregar\nFotos' :
                        images.length >= maxImages ? 'Limite\nAlcanzado' : 'Agregar\nMás',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: images.length < maxImages 
                              ? const Color(0xFF058896)
                              : Colors.grey.shade600,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Images
              ...images.asMap().entries.map((entry) {
                final index = entry.key;
                final image = entry.value;
                return Container(
                  width: 80,
                  height: 80,
                  margin: const EdgeInsets.only(right: 25),
                  child: Stack(
                    children: [
                      GestureDetector(
                        onTap: () => _viewImage(context, image),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(5),
                          child: Image.file(
                            File(image.path),
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      // Principal indicator
                      if (index == 0)
                        Positioned(
                          top: 2,
                          left: 2,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF058896),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: const Text(
                              'Principal',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      // Crop button
                      Positioned(
                        bottom: 2,
                        left: 2,
                        child: GestureDetector(
                          onTap: () => _cropExistingImage(index, context),
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: const Color(0xFF058896),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: const Icon(
                              Icons.crop,
                              color: Colors.white,
                              size: 12,
                            ),
                          ),
                        ),
                      ),
                      // Delete button
                      Positioned(
                        top: 2,
                        right: 2,
                        child: GestureDetector(
                          onTap: () => _removeImage(index),
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
          ),
        ),
        
        // Limit text BELOW the buttons
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 25.0, vertical: 5),
          child: Text(
            'Fotos: ${images.length}/$maxImages • Elige primero la foto principal',
            style: TextStyle(
              fontSize: 12,
              color: images.length >= maxImages ? Colors.orange : Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}