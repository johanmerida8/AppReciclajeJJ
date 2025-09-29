import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:reciclaje_app/components/add_photo_button.dart';
import 'package:reciclaje_app/components/fullscreen_photo_viewer.dart';
import 'package:reciclaje_app/model/photo.dart';

class PhotoGalleryWidget extends StatefulWidget {
  final List<Photo> photos;
  final Photo? mainPhoto;
  final bool isLoading;
  final bool isOwner;
  final VoidCallback? onAddPhoto;
  final Function(Photo)? onDeletePhoto;
  final List<Photo> photosToDelete;
  final List<XFile> pickedImages;
  final Function(List<Photo>)? onPhotosToDeleteChanged;
  final Function(List<XFile>)? onPickedImagesChanged;
  final int maxPhotos;
  final bool showValidation;

  const PhotoGalleryWidget({
    super.key,
    required this.photos,
    this.mainPhoto,
    this.isLoading = false,
    this.isOwner = false,
    this.onAddPhoto,
    this.onDeletePhoto,
    this.photosToDelete = const [], 
    this.onPhotosToDeleteChanged,
    this.onPickedImagesChanged,
    this.maxPhotos = 10,
    this.showValidation = true,
    this.pickedImages = const [],
  });

  @override
  State<PhotoGalleryWidget> createState() => _PhotoGalleryWidgetState();
}

class _PhotoGalleryWidgetState extends State<PhotoGalleryWidget> {
  int _currentIndex = 0;
  PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // Add this method to handle widget updates
  @override
  void didUpdateWidget(PhotoGalleryWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Reset current index if the list changed and current index is out of bounds
    List<dynamic> allDisplayItems = [];
    
    if (widget.mainPhoto != null) {
      allDisplayItems.add(widget.mainPhoto!);
    }
    
    allDisplayItems.addAll(widget.photos.where((photo) => photo.id != widget.mainPhoto?.id));
    allDisplayItems.addAll(widget.pickedImages);
    
    // If current index is out of bounds, reset to 0
    if (_currentIndex >= allDisplayItems.length && allDisplayItems.isNotEmpty) {
      setState(() {
        _currentIndex = 0;
      });
      // Animate to first page
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pageController.hasClients) {
          _pageController.animateToPage(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      });
    }
    // If list is now empty, reset index
    else if (allDisplayItems.isEmpty) {
      setState(() {
        _currentIndex = 0;
      });
    }
  }

  void _showFullscreenImage(int initialIndex) {
    // Create the same combined list as in build method
    List<dynamic> allDisplayItems = [];
    
    if (widget.mainPhoto != null) {
      allDisplayItems.add(widget.mainPhoto!);
    }
    
    allDisplayItems.addAll(widget.photos.where((photo) => photo.id != widget.mainPhoto?.id));
    allDisplayItems.addAll(widget.pickedImages);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FullscreenPhotoViewer(
          photos: widget.photos,
          pickedImages: widget.pickedImages,
          initialIndex: initialIndex,
          mainPhoto: widget.mainPhoto,
        ),
      ),
    );
  }

  void _markPhotoForDeletion(Photo photo) {
    List<Photo> updatedList = List.from(widget.photosToDelete);
    
    if (updatedList.any((p) => p.id == photo.id)) {
      // Unmark for deletion
      updatedList.removeWhere((p) => p.id == photo.id);
    } else {
      // Mark for deletion
      updatedList.add(photo);
    }
    
    widget.onPhotosToDeleteChanged?.call(updatedList);
  }

  bool _isMarkedForDeletion(Photo photo) {
    return widget.photosToDelete.any((p) => p.id == photo.id);
  }

  void _removePickedImage(int imageIndex) {
    // Find the actual XFile in the picked images list
    List<dynamic> allDisplayItems = [];
    
    if (widget.mainPhoto != null) {
      allDisplayItems.add(widget.mainPhoto!);
    }
    
    allDisplayItems.addAll(widget.photos.where((photo) => photo.id != widget.mainPhoto?.id));
    allDisplayItems.addAll(widget.pickedImages);
    
    // Check if the item at imageIndex is actually an XFile
    if (imageIndex < allDisplayItems.length && allDisplayItems[imageIndex] is XFile) {
      XFile imageToRemove = allDisplayItems[imageIndex] as XFile;
      
      // Find this XFile in the pickedImages list
      List<XFile> updatedPickedImages = List.from(widget.pickedImages);
      updatedPickedImages.removeWhere((xFile) => xFile.path == imageToRemove.path);
      
      // Call the callback to update parent state
      widget.onPickedImagesChanged?.call(updatedPickedImages);
      
      // Adjust current index if needed
      if (_currentIndex >= imageIndex && _currentIndex > 0) {
        setState(() {
          _currentIndex = _currentIndex - 1;
        });
        _pageController.animateToPage(
          _currentIndex,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  @override
Widget build(BuildContext context) {
  // Create allDisplayItems list combining both Photo and XFile objects
  List<dynamic> allDisplayItems = [];
  
  // Add main photo first if exists
  if (widget.mainPhoto != null) {
    allDisplayItems.add(widget.mainPhoto!);
  }
  
  // Add other existing photos
  allDisplayItems.addAll(widget.photos.where((photo) => photo.id != widget.mainPhoto?.id));
  
  // Add picked images (XFile objects)
  allDisplayItems.addAll(widget.pickedImages);

  // Safety check: ensure currentIndex is within bounds
  if (_currentIndex >= allDisplayItems.length && allDisplayItems.isNotEmpty) {
    _currentIndex = 0;
  }

  if (widget.isLoading) {
    return Container(
      height: 180, // Reduced height
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF2D8A8A),
        ),
      ),
    );
  }

  // SIMPLIFIED EMPTY STATE - More compact
  if (allDisplayItems.isEmpty) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min, // Important: only take needed space
        children: [
          Icon(
            Icons.photo_library_outlined,
            size: 40, // Smaller icon
            color: Colors.grey[400],
          ),
          const SizedBox(height: 8),
          Text(
            'No hay fotos disponibles',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14, // Smaller text
            ),
          ),
          if (widget.isOwner && widget.onAddPhoto != null) ...[
            const SizedBox(height: 12),
            // More compact button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: widget.onAddPhoto,
                icon: const Icon(Icons.add_a_photo, size: 16),
                label: const Text('Agregar', style: TextStyle(fontSize: 13)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF2D8A8A),
                  side: const BorderSide(color: Color(0xFF2D8A8A)),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // MAIN WIDGET WITH PHOTOS - Wrap in intrinsic height
  return IntrinsicHeight(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Photo counter info - More compact
        Row(
          children: [
            Text(
              'Fotos: ${allDisplayItems.length}/${widget.maxPhotos}',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (allDisplayItems.isEmpty)
              const Text(
                ' • Elige primero la foto principal de la publicación',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.orange,
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        
        // Main photo display
        Container(
          height: 220, // Reduced height
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Stack(
            children: [
              PageView.builder(
                controller: _pageController,
                itemCount: allDisplayItems.length,
                onPageChanged: (index) {
                  if (index < allDisplayItems.length) {
                    setState(() {
                      _currentIndex = index;
                    });
                  }
                },
                itemBuilder: (context, index) {
                  if (index >= allDisplayItems.length) {
                    return Container();
                  }
                  
                  final item = allDisplayItems[index];
                  
                  if (item is Photo) {
                    return _buildPhotoWidget(item);
                  } else if (item is XFile) {
                    return _buildPickedImageWidget(item, index);
                  }
                  
                  return Container();
                },
              ),
              
              // Main photo indicator
              if (widget.mainPhoto != null && 
                  _currentIndex == 0 && 
                  allDisplayItems.isNotEmpty && 
                  _currentIndex < allDisplayItems.length &&
                  allDisplayItems[_currentIndex] is Photo)
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2D8A8A),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Principal',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                
              // Delete button for owners
              if (widget.isOwner && 
                  widget.onPhotosToDeleteChanged != null && 
                  allDisplayItems.isNotEmpty &&
                  _currentIndex < allDisplayItems.length &&
                  allDisplayItems[_currentIndex] is Photo)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: _isMarkedForDeletion(allDisplayItems[_currentIndex] as Photo) 
                          ? Colors.green 
                          : Colors.red,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: IconButton(
                      onPressed: () => _markPhotoForDeletion(allDisplayItems[_currentIndex] as Photo),
                      icon: Icon(
                        _isMarkedForDeletion(allDisplayItems[_currentIndex] as Photo) 
                            ? Icons.undo 
                            : Icons.delete,
                        color: Colors.white,
                      ),
                      iconSize: 16,
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ),
                
              // Page indicators
              if (allDisplayItems.length > 1)
                Positioned(
                  bottom: 8,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: allDisplayItems.asMap().entries.map((entry) {
                      return Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _currentIndex == entry.key
                              ? Colors.white
                              : Colors.white.withOpacity(0.5),
                        ),
                      );
                    }).toList(),
                  ),
                ),
            ],
          ),
        ),
        
        // Thumbnail strip
        if (allDisplayItems.length > 1) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 50, // Smaller thumbnails
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: allDisplayItems.length,
              itemBuilder: (context, index) {
                final item = allDisplayItems[index];
                final isSelected = index == _currentIndex;
                
                return GestureDetector(
                  onTap: () {
                    _pageController.animateToPage(
                      index,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                  child: Container(
                    width: 50,
                    height: 50,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: item is Photo && _isMarkedForDeletion(item)
                            ? Colors.red
                            : isSelected 
                                ? const Color(0xFF2D8A8A) 
                                : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: item is Photo 
                          ? _buildThumbnailPhoto(item)
                          : _buildThumbnailXFile(item as XFile),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
          
        // Delete summary - More compact
        if (widget.photosToDelete.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.red.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning, color: Colors.red, size: 16),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${widget.photosToDelete.length} foto(s) marcada(s) para eliminar',
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => widget.onPhotosToDeleteChanged?.call([]),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                  ),
                  child: const Text(
                    'Cancelar', 
                    style: TextStyle(color: Colors.red, fontSize: 11)
                  ),
                ),
              ],
            ),
          ),
        ],

        // Add photo button - More compact and only when there are photos
        if (widget.isOwner && widget.onAddPhoto != null && allDisplayItems.isNotEmpty) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: widget.onAddPhoto,
              icon: const Icon(Icons.add_a_photo, size: 16),
              label: const Text('Agregar foto', style: TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF2D8A8A),
                side: const BorderSide(color: Color(0xFF2D8A8A)),
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

  Widget _buildPhotoWidget(Photo photo) {
    final isMarkedForDeletion = _isMarkedForDeletion(photo);
    
    return GestureDetector(
      onTap: () => _showFullscreenImage(_currentIndex),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: ColorFiltered(
                colorFilter: isMarkedForDeletion
                    ? ColorFilter.mode(
                        Colors.red.withOpacity(0.3),
                        BlendMode.multiply,
                      )
                    : const ColorFilter.mode(
                        Colors.transparent,
                        BlendMode.multiply,
                      ),
                child: Image.network(
                  photo.url!,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey[300],
                      child: const Center(
                        child: Icon(
                          Icons.broken_image,
                          size: 48,
                          color: Colors.grey,
                        ),
                      ),
                    );
                  },
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      color: Colors.grey[200],
                      child: Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                          color: const Color(0xFF2D8A8A),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            // Deletion overlay
            if (isMarkedForDeletion)
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.red.withOpacity(0.3),
                ),
                child: const Center(
                  child: Icon(
                    Icons.delete_forever,
                    size: 64,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPickedImageWidget(XFile image, int index) {
  return GestureDetector(
    onTap: () => _showFullscreenImage(index),
    child: Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(
            File(image.path),
            width: double.infinity,
            height: 220, // Match the reduced container height
            fit: BoxFit.cover,
          ),
        ),
        // "Nueva" indicator
        Positioned(
          top: 8,
          left: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.green,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              'Nueva',
              style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
        ),
  
        // Delete button for new picked images
        if (widget.isOwner && widget.onPickedImagesChanged != null)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(16),
              ),
              child: IconButton(
                onPressed: () {
                  print('Delete button pressed for index: $index');
                  _removePickedImage(index);
                }, 
                icon: const Icon(
                  Icons.delete,
                  color: Colors.white,
                ),
                iconSize: 16,
                padding: EdgeInsets.zero,
              ),
            ),
          ),
      ],
    ),
  );
}

  Widget _buildThumbnailPhoto(Photo photo) {
    final isMarkedForDeletion = _isMarkedForDeletion(photo);
    
    return Stack(
      children: [
        ColorFiltered(
          colorFilter: isMarkedForDeletion
              ? ColorFilter.mode(
                  Colors.red.withOpacity(0.5),
                  BlendMode.multiply,
                )
              : const ColorFilter.mode(
                  Colors.transparent,
                  BlendMode.multiply,
                ),
          child: Image.network(
            photo.url!,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: Colors.grey[300],
                child: const Icon(Icons.broken_image, size: 24),
              );
            },
          ),
        ),
        if (isMarkedForDeletion)
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              color: Colors.red.withOpacity(0.3),
            ),
            child: const Center(
              child: Icon(
                Icons.close,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildThumbnailXFile(XFile image) {
    return Stack(
      children: [
        Image.file(
          File(image.path),
          fit: BoxFit.cover,
        ),
        // "New" indicator on thumbnail
        Positioned(
          top: 2,
          left: 2,
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: Colors.green,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Icon(
              Icons.add,
              color: Colors.white,
              size: 8,
            ),
          ),
        ),
      ],
    );
  }
}