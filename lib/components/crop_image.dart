import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';

class CroppedImage extends StatefulWidget {
  final CroppedFile croppedFile;

  const CroppedImage({super.key, required this.croppedFile});

  @override
  State<CroppedImage> createState() => _CroppedImageState();
}

class _CroppedImageState extends State<CroppedImage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(5),
          child: InteractiveViewer(
            child: Image(
              image: FileImage(
                File(widget.croppedFile.path),
              ),
            ),
          ),
        ),
      ),
    );
  }
}