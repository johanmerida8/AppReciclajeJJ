import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:reciclaje_app/model/photo.dart';

class FullscreenPhotoViewer extends StatefulWidget {
  final List<Photo> photos;
  final List<XFile> pickedImages;
  final int initialIndex;
  final Photo? mainPhoto;

  const FullscreenPhotoViewer({
    super.key,
    required this.photos,
    required this.initialIndex,
    this.mainPhoto,
    this.pickedImages = const [],
  });

  @override
  State<FullscreenPhotoViewer> createState() => _FullscreenPhotoViewerState();
}

class _FullscreenPhotoViewerState extends State<FullscreenPhotoViewer> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Create the same combined list structure
    List<dynamic> allDisplayItems = [];
    
    if (widget.mainPhoto != null) {
      allDisplayItems.add(widget.mainPhoto!);
    }
    
    allDisplayItems.addAll(widget.photos.where((photo) => photo.id != widget.mainPhoto?.id));
    allDisplayItems.addAll(widget.pickedImages);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          '${_currentIndex + 1} de ${allDisplayItems.length}',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: allDisplayItems.length,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        itemBuilder: (context, index) {
          final item = allDisplayItems[index];
          
          if (item is Photo) {
            // Display existing photo from database
            return Center(
              child: InteractiveViewer(
                child: Image.network(
                  item.url!,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(
                      child: Icon(
                        Icons.broken_image,
                        size: 64,
                        color: Colors.white,
                      ),
                    );
                  },
                ),
              ),
            );
          } else if (item is XFile) {
            // Display picked image (local file)
            return Center(
              child: Stack(
                children: [
                  InteractiveViewer(
                    child: Image.file(
                      File(item.path),
                      fit: BoxFit.contain,
                    ),
                  ),
                  // "Nueva" indicator in fullscreen
                  // Positioned(
                  //   top: 20,
                  //   left: 20,
                  //   child: Container(
                  //     padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  //     decoration: BoxDecoration(
                  //       color: Colors.green,
                  //       borderRadius: BorderRadius.circular(16),
                  //     ),
                  //     child: const Text(
                  //       'Nueva',
                  //       style: TextStyle(
                  //         color: Colors.white,
                  //         fontSize: 14,
                  //         fontWeight: FontWeight.bold,
                  //       ),
                  //     ),
                  //   ),
                  // ),
                ],
              ),
            );
          }
          
          return const Center(
            child: Icon(
              Icons.broken_image,
              size: 64,
              color: Colors.white,
            ),
          );
        },
      ),
    );
  }
}