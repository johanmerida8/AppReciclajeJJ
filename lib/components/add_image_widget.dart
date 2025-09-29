import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class AddImageWidget extends StatefulWidget {
  final List<XFile> newImages;
  final int currentPhotoCount;
  final int maxImages;
  final Function(List<XFile>) onImagesChanged;
  final bool isEnabled;

  const AddImageWidget({
    super.key,
    required this.newImages,
    required this.currentPhotoCount,
    required this.onImagesChanged,
    this.maxImages = 5,
    this.isEnabled = true,
  });

  @override
  State<AddImageWidget> createState() => _AddImageWidgetState();
}

class _AddImageWidgetState extends State<AddImageWidget> {
  final ImagePicker _picker = ImagePicker();

  int get _totalImages => widget.currentPhotoCount + widget.newImages.length;
  bool get _canAddMore => _totalImages < widget.maxImages && widget.isEnabled;

  Future<void> _addImages() async {
    if (!_canAddMore) {
      _showMaxImagesMessage();
      return;
    }

    try {
      final List<XFile>? selectedImages = await _picker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 80,
      );

      if (selectedImages != null && selectedImages.isNotEmpty) {
        final remainingSlots = widget.maxImages - _totalImages;
        final imagesToAdd = selectedImages.take(remainingSlots).toList();
        
        final updatedImages = List<XFile>.from(widget.newImages)..addAll(imagesToAdd);
        widget.onImagesChanged(updatedImages);

        _showSuccessMessage(imagesToAdd.length, 'imagen(es) agregada(s)');
      }
    } catch (e) {
      _showErrorMessage('Error al seleccionar imágenes: $e');
    }
  }

  Future<void> _takeSinglePhoto() async {
    if (!_canAddMore) {
      _showMaxImagesMessage();
      return;
    }

    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 80,
      );

      if (image != null) {
        final updatedImages = List<XFile>.from(widget.newImages)..add(image);
        widget.onImagesChanged(updatedImages);

        _showSuccessMessage(1, 'foto tomada');
      }
    } catch (e) {
      _showErrorMessage('Error al tomar foto: $e');
    }
  }

  void _removeImage(int index) {
    final updatedImages = List<XFile>.from(widget.newImages)..removeAt(index);
    widget.onImagesChanged(updatedImages);
  }

  void _showAddPhotoOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Agregar Fotos',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D8A8A),
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2D8A8A).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.photo_library,
                      color: Color(0xFF2D8A8A),
                    ),
                  ),
                  title: const Text('Seleccionar de galería'),
                  subtitle: const Text('Elige múltiples fotos'),
                  onTap: () {
                    Navigator.pop(context);
                    _addImages();
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2D8A8A).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      color: Color(0xFF2D8A8A),
                    ),
                  ),
                  title: const Text('Tomar foto'),
                  subtitle: const Text('Usar la cámara'),
                  onTap: () {
                    Navigator.pop(context);
                    _takeSinglePhoto();
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showMaxImagesMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Máximo ${widget.maxImages} fotos permitidas'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _showSuccessMessage(int count, String action) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$count $action. Se subirán al guardar cambios.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Add photos button
        if (widget.isEnabled)
          Center(
            child: ElevatedButton.icon(
              onPressed: _canAddMore ? _showAddPhotoOptions : null,
              icon: const Icon(Icons.add_a_photo),
              label: Text(_canAddMore ? 'Agregar Fotos' : 'Límite Alcanzado'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _canAddMore 
                    ? const Color(0xFF2D8A8A) 
                    : Colors.grey,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),

        // New images preview
        if (widget.newImages.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Nuevas fotos (${widget.newImages.length})',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D8A8A),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: widget.newImages.length,
              itemBuilder: (context, index) {
                final image = widget.newImages[index];
                return Container(
                  width: 100,
                  height: 100,
                  margin: const EdgeInsets.only(right: 12),
                  child: Stack(
                    children: [
                      // Image preview
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(image.path),
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                        ),
                      ),
                      // New indicator
                      Positioned(
                        top: 4,
                        left: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Nueva',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      // Remove button
                      if (widget.isEnabled)
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
              },
            ),
          ),
          const SizedBox(height: 8),
          // Status indicator
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Las fotos se subirán cuando guardes los cambios',
                    style: const TextStyle(
                      color: Colors.blue,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        // Photo count info
        if (widget.isEnabled)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Fotos: $_totalImages/${widget.maxImages}',
              style: TextStyle(
                fontSize: 12,
                color: _totalImages >= widget.maxImages ? Colors.orange : Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }
}
                      