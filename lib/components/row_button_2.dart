import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
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
    // ✅ Usar Fixed43Cropper con cambio automático de ratio por rotación
    // 0° y 180° (vertical) → Crop box 3:4 (vertical)
    // 90° y 270° (horizontal) → Crop box 4:3 (horizontal)
    try {
      final res = await Navigator.of(context).push<XFile>(
        MaterialPageRoute(
          builder: (_) => Fixed43Cropper(file: file),
        ),
      );  
      return res ?? file;
    } catch (e) {
      debugPrint('Error cropping image: $e');
      return file;
    }
  }

  void _addImages(bool fromGallery, BuildContext context) async {
    if (images.length >= maxImages) return;

    final picker = ImagePicker();

    if (fromGallery) {
      // Check and request photo permission first
      final permission = await _requestPhotoPermission(context);
      if (!permission) return;

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
      // Check and request camera permission first
      final permission = await _requestCameraPermission(context);
      if (!permission) return;

      // Single from camera
      final XFile? shot = await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
      if (shot == null) return;
      final cropped = await _openCropper(context, shot);
      onImagesChanged([...images, cropped]);
    }

  }

  /// Request photo/storage permission
  Future<bool> _requestPhotoPermission(BuildContext context) async {
    // ✅ Para Android 12, intentar múltiples permisos
    PermissionStatus status;
    
    if (Platform.isAndroid) {
      // Primero intentar storage (funciona mejor en Android 10-12)
      status = await Permission.storage.request();
      
      // Si storage falla, intentar photos
      if (!status.isGranted) {
        status = await Permission.photos.request();
      }
      
      // Si ambos fallan, intentar manageExternalStorage para Android 11+
      if (!status.isGranted) {
        final manageStatus = await Permission.manageExternalStorage.request();
        if (manageStatus.isGranted) {
          status = manageStatus;
        }
      }
    } else {
      // iOS
      status = await Permission.photos.request();
    }

    if (status.isGranted) {
      return true;
    } else if (status.isPermanentlyDenied) {
      if (context.mounted) {
        _showPermissionDeniedDialog(context, 'Galería');
      }
      return false;
    } else if (status.isDenied) {
      if (context.mounted) {
        _showPermissionExplanationDialog(context);
      }
      return false;
    }

    return false;
  }

  /// Request camera permission
  Future<bool> _requestCameraPermission(BuildContext context) async {
    final status = await Permission.camera.request();

    if (status.isGranted) {
      return true;
    } else if (status.isPermanentlyDenied) {
      // Show dialog to open settings
      if (context.mounted) {
        _showPermissionDeniedDialog(context, 'Cámara');
      }
      return false;
    }
    
    return false;
  }

  /// Show dialog when permission is permanently denied
  void _showPermissionDeniedDialog(BuildContext context, String permissionName) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Permiso de $permissionName Bloqueado'),
          content: Text(
            'Has bloqueado el permiso de $permissionName.\n\n'
            'Para usar esta función, ve a Configuración y habilita el permiso manualmente.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                openAppSettings(); // Opens app settings
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF058896),
              ),
              child: const Text('Abrir Configuración'),
            ),
          ],
        );
      },
    );
  }

  /// Show explanation dialog when permission is denied
  void _showPermissionExplanationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Permiso Necesario'),
          content: const Text(
            'Para seleccionar fotos de la galería, necesitamos acceso a tus archivos.\n\n'
            'Por favor, concede el permiso cuando aparezca el siguiente diálogo.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Intentar solicitar permisos nuevamente
                _requestPhotoPermission(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF058896),
              ),
              child: const Text('Intentar de Nuevo'),
            ),
          ],
        );
      },
    );
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
                // Add button
                GestureDetector(
                  onTap: images.length < maxImages ? () => _showImageSourceOptions(context) : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: images.length < maxImages 
                          ? Colors.white
                          : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: images.length < maxImages
                            ? const Color(0xFF058896)
                            : Colors.grey.shade400,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_photo_alternate_outlined,
                          color: images.length < maxImages
                              ? const Color(0xFF058896)
                              : Colors.grey.shade600,
                          size: 40,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          images.isEmpty ? 'Agregar Fotos' :
                          images.length >= maxImages ? 'Límite\nAlcanzado' : 'Agregar Más',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: images.length < maxImages 
                                ? const Color(0xFF058896)
                                : Colors.grey.shade600,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Images
                ...images.asMap().entries.map((entry) {
                  final index = entry.key;
                  final image = entry.value;
                  return Container(
                    width: 120,
                    height: 120,
                    margin: const EdgeInsets.only(right: 12),
                    child: Stack(
                      children: [
                        GestureDetector(
                          onTap: () => _viewImage(context, image),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              File(image.path),
                              width: 120,
                              height: 120,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        // Principal indicator
                        if (index == 0)
                          Positioned(
                            top: 4,
                            left: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF058896),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Principal',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        // Crop button
                        Positioned(
                          bottom: 4,
                          left: 4,
                          child: GestureDetector(
                            onTap: () => _cropExistingImage(index, context),
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: const Color(0xFF058896),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Icon(
                                Icons.crop,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                        // Delete button
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () => _removeImage(index),
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 16,
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
          padding: const EdgeInsets.only(top: 12.0),
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