// import 'package:flutter/material.dart';
// import 'package:image_picker/image_picker.dart';
// import 'dart:io';

// class ImagePickerComponent extends StatefulWidget {
//   final Function(List<File>) onImagesSelected;
//   final int minImages;
//   final int maxImages;

//   const ImagePickerComponent({
//     super.key,
//     required this.onImagesSelected,
//     this.minImages = 10,
//     this.maxImages = 20,
//   });

//   @override
//   State<ImagePickerComponent> createState() => _ImagePickerComponentState();
// }

// class _ImagePickerComponentState extends State<ImagePickerComponent> {
//   List<File> _selectedImages = [];
//   final ImagePicker _picker = ImagePicker();

//   // ✅ Updated method with better error handling
//   Future<void> _pickImages() async {
//     try {
//       // Show options dialog
//       final source = await _showImageSourceDialog();
//       if (source == null) return;

//       if (source == 'multiple') {
//         await _pickMultipleImages();
//       } else if (source == 'camera') {
//         await _pickSingleImageFromCamera();
//       } else if (source == 'gallery') {
//         await _pickSingleImageFromGallery();
//       }
//     } catch (e) {
//       print('Error picking images: $e');
//       _showMessage('Error al seleccionar imágenes. Inténtalo de nuevo.');
//     }
//   }

//   // ✅ Show dialog to choose source
//   Future<String?> _showImageSourceDialog() async {
//     return showDialog<String>(
//       context: context,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           title: const Text('Seleccionar fotos'),
//           content: const Text('¿Cómo quieres agregar las fotos?'),
//           actions: [
//             TextButton(
//               onPressed: () => Navigator.pop(context, 'camera'),
//               child: const Text('📷 Cámara'),
//             ),
//             TextButton(
//               onPressed: () => Navigator.pop(context, 'gallery'),
//               child: const Text('🖼️ Galería (una)'),
//             ),
//             TextButton(
//               onPressed: () => Navigator.pop(context, 'multiple'),
//               child: const Text('📁 Múltiples'),
//             ),
//           ],
//         );
//       },
//     );
//   }

//   // ✅ Pick multiple images
//   Future<void> _pickMultipleImages() async {
//     try {
//       final List<XFile> pickedFiles = await _picker.pickMultipleMedia(
//         maxWidth: 1920,
//         maxHeight: 1920,
//         imageQuality: 80,
//       );

//       if (pickedFiles.isNotEmpty) {
//         await _processPickedFiles(pickedFiles);
//       }
//     } catch (e) {
//       print('Error picking multiple images: $e');
//       _showMessage('Error al seleccionar múltiples imágenes');
//     }
//   }

//   // ✅ Pick single image from camera
//   Future<void> _pickSingleImageFromCamera() async {
//     try {
//       final XFile? pickedFile = await _picker.pickImage(
//         source: ImageSource.camera,
//         maxWidth: 1920,
//         maxHeight: 1920,
//         imageQuality: 80,
//       );

//       if (pickedFile != null) {
//         await _processPickedFiles([pickedFile]);
//       }
//     } catch (e) {
//       print('Error picking image from camera: $e');
//       _showMessage('Error al tomar foto con la cámara');
//     }
//   }

//   // ✅ Pick single image from gallery
//   Future<void> _pickSingleImageFromGallery() async {
//     try {
//       final XFile? pickedFile = await _picker.pickImage(
//         source: ImageSource.gallery,
//         maxWidth: 1920,
//         maxHeight: 1920,
//         imageQuality: 80,
//       );

//       if (pickedFile != null) {
//         await _processPickedFiles([pickedFile]);
//       }
//     } catch (e) {
//       print('Error picking image from gallery: $e');
//       _showMessage('Error al seleccionar imagen de la galería');
//     }
//   }

//   // ✅ Process picked files
//   Future<void> _processPickedFiles(List<XFile> pickedFiles) async {
//     if (pickedFiles.isEmpty) return;

//     // Check if total images exceed max limit
//     if (_selectedImages.length + pickedFiles.length > widget.maxImages) {
//       _showMessage('Máximo ${widget.maxImages} fotos permitidas');
//       return;
//     }

//     setState(() {
//       _selectedImages.addAll(
//         pickedFiles.map((file) => File(file.path)).toList(),
//       );
//     });

//     widget.onImagesSelected(_selectedImages);

//     if (_selectedImages.length >= widget.minImages) {
//       _showMessage('¡Perfecto! Has agregado ${_selectedImages.length} fotos', isSuccess: true);
//     } else {
//       _showMessage('Faltan ${widget.minImages - _selectedImages.length} fotos más');
//     }
//   }

//   void _removeImage(int index) {
//     setState(() {
//       _selectedImages.removeAt(index);
//     });
//     widget.onImagesSelected(_selectedImages);
//   }

//   void _showMessage(String message, {bool isSuccess = false}) {
//     if (!mounted) return;
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(message),
//         backgroundColor: isSuccess ? Colors.green : Colors.orange,
//         duration: const Duration(seconds: 2),
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         // Header with validation info
//         Padding(
//           padding: const EdgeInsets.symmetric(horizontal: 25.0),
//           child: Row(
//             children: [
//               const Text(
//                 'Fotos: ',
//                 style: TextStyle(
//                   fontSize: 16,
//                   fontWeight: FontWeight.bold,
//                   color: Color(0xFF2D8A8A),
//                 ),
//               ),
//               Text(
//                 '${_selectedImages.length}/${widget.minImages}',
//                 style: TextStyle(
//                   fontSize: 16,
//                   fontWeight: FontWeight.bold,
//                   color: _selectedImages.length >= widget.minImages 
//                       ? Colors.green 
//                       : Colors.red,
//                 ),
//               ),
//               const Spacer(),
//               if (_selectedImages.length < widget.minImages)
//                 Container(
//                   padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//                   decoration: BoxDecoration(
//                     color: Colors.red.withOpacity(0.1),
//                     borderRadius: BorderRadius.circular(12),
//                     border: Border.all(color: Colors.red.withOpacity(0.3)),
//                   ),
//                   child: Text(
//                     'Mínimo ${widget.minImages} fotos',
//                     style: const TextStyle(
//                       fontSize: 10,
//                       color: Colors.red,
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//                 ),
//             ],
//           ),
//         ),
//         const SizedBox(height: 12),

//         // Images grid or add button
//         Container(
//           margin: const EdgeInsets.symmetric(horizontal: 25.0),
//           decoration: BoxDecoration(
//             border: Border.all(
//               color: _selectedImages.length >= widget.minImages 
//                   ? Colors.green 
//                   : Colors.grey.withOpacity(0.3),
//               width: 2,
//             ),
//             borderRadius: BorderRadius.circular(12),
//           ),
//           child: _selectedImages.isEmpty
//               ? _buildAddPhotosButton()
//               : _buildImagesGrid(),
//         ),
        
//         // Validation message
//         if (_selectedImages.length < widget.minImages) ...[
//           const SizedBox(height: 8),
//           Padding(
//             padding: const EdgeInsets.symmetric(horizontal: 25.0),
//             child: Text(
//               '• Elige primero la foto principal de la publicación',
//               style: TextStyle(
//                 fontSize: 12,
//                 color: Colors.grey[600],
//                 fontStyle: FontStyle.italic,
//               ),
//             ),
//           ),
//         ],
//       ],
//     );
//   }

//   Widget _buildAddPhotosButton() {
//     return GestureDetector(
//       onTap: _pickImages,
//       child: Container(
//         height: 200,
//         width: double.infinity,
//         decoration: BoxDecoration(
//           color: Colors.grey[50],
//           borderRadius: BorderRadius.circular(10),
//         ),
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Container(
//               width: 80,
//               height: 80,
//               decoration: BoxDecoration(
//                 color: const Color(0xFF2D8A8A).withOpacity(0.1),
//                 borderRadius: BorderRadius.circular(40),
//                 border: Border.all(
//                   color: const Color(0xFF2D8A8A).withOpacity(0.3),
//                   width: 2,
//                   style: BorderStyle.solid,
//                 ),
//               ),
//               child: const Icon(
//                 Icons.add_photo_alternate_outlined,
//                 size: 40,
//                 color: Color(0xFF2D8A8A),
//               ),
//             ),
//             const SizedBox(height: 16),
//             const Text(
//               'Agregar Fotos',
//               style: TextStyle(
//                 fontSize: 18,
//                 fontWeight: FontWeight.bold,
//                 color: Color(0xFF2D8A8A),
//               ),
//             ),
//             const SizedBox(height: 8),
//             Text(
//               'Mínimo ${widget.minImages} fotos requeridas',
//               style: TextStyle(
//                 fontSize: 14,
//                 color: Colors.grey[600],
//               ),
//             ),
//             const SizedBox(height: 4),
//             const Text(
//               'Toca para seleccionar fotos',
//               style: TextStyle(
//                 fontSize: 12,
//                 color: Colors.grey,
//                 fontStyle: FontStyle.italic,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildImagesGrid() {
//     return Container(
//       padding: const EdgeInsets.all(12),
//       child: Column(
//         children: [
//           // First image (main image) - larger
//           if (_selectedImages.isNotEmpty) ...[
//             Stack(
//               children: [
//                 Container(
//                   width: double.infinity,
//                   height: 200,
//                   decoration: BoxDecoration(
//                     borderRadius: BorderRadius.circular(8),
//                     border: Border.all(color: Colors.green, width: 3),
//                   ),
//                   child: ClipRRect(
//                     borderRadius: BorderRadius.circular(6),
//                     child: Image.file(
//                       _selectedImages[0],
//                       fit: BoxFit.cover,
//                     ),
//                   ),
//                 ),
//                 Positioned(
//                   top: 8,
//                   left: 8,
//                   child: Container(
//                     padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//                     decoration: BoxDecoration(
//                       color: Colors.green,
//                       borderRadius: BorderRadius.circular(12),
//                     ),
//                     child: const Text(
//                       'PRINCIPAL',
//                       style: TextStyle(
//                         color: Colors.white,
//                         fontWeight: FontWeight.bold,
//                         fontSize: 10,
//                       ),
//                     ),
//                   ),
//                 ),
//                 Positioned(
//                   top: 8,
//                   right: 8,
//                   child: GestureDetector(
//                     onTap: () => _removeImage(0),
//                     child: Container(
//                       decoration: const BoxDecoration(
//                         color: Colors.red,
//                         shape: BoxShape.circle,
//                       ),
//                       child: const Icon(
//                         Icons.close,
//                         color: Colors.white,
//                         size: 20,
//                       ),
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//             const SizedBox(height: 12),
//           ],

//           // Grid of other images
//           if (_selectedImages.length > 1) ...[
//             GridView.builder(
//               shrinkWrap: true,
//               physics: const NeverScrollableScrollPhysics(),
//               gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
//                 crossAxisCount: 4,
//                 crossAxisSpacing: 8,
//                 mainAxisSpacing: 8,
//                 childAspectRatio: 1,
//               ),
//               itemCount: _selectedImages.length - 1,
//               itemBuilder: (context, index) {
//                 final imageIndex = index + 1; // Skip first image
//                 return Stack(
//                   children: [
//                     Container(
//                       decoration: BoxDecoration(
//                         borderRadius: BorderRadius.circular(6),
//                         border: Border.all(color: Colors.grey[300]!),
//                       ),
//                       child: ClipRRect(
//                         borderRadius: BorderRadius.circular(4),
//                         child: Image.file(
//                           _selectedImages[imageIndex],
//                           fit: BoxFit.cover,
//                           width: double.infinity,
//                           height: double.infinity,
//                         ),
//                       ),
//                     ),
//                     Positioned(
//                       top: 2,
//                       right: 2,
//                       child: GestureDetector(
//                         onTap: () => _removeImage(imageIndex),
//                         child: Container(
//                           width: 18,
//                           height: 18,
//                           decoration: const BoxDecoration(
//                             color: Colors.red,
//                             shape: BoxShape.circle,
//                           ),
//                           child: const Icon(
//                             Icons.close,
//                             color: Colors.white,
//                             size: 12,
//                           ),
//                         ),
//                       ),
//                     ),
//                   ],
//                 );
//               },
//             ),
//             const SizedBox(height: 12),
//           ],

//           // Add more photos button
//           if (_selectedImages.length < widget.maxImages)
//             GestureDetector(
//               onTap: _pickImages,
//               child: Container(
//                 height: 50,
//                 decoration: BoxDecoration(
//                   color: const Color(0xFF2D8A8A).withOpacity(0.1),
//                   borderRadius: BorderRadius.circular(8),
//                   border: Border.all(
//                     color: const Color(0xFF2D8A8A).withOpacity(0.3),
//                     style: BorderStyle.solid,
//                   ),
//                 ),
//                 child: const Row(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     Icon(
//                       Icons.add_photo_alternate_outlined,
//                       color: Color(0xFF2D8A8A),
//                     ),
//                     SizedBox(width: 8),
//                     Text(
//                       'Agregar más fotos',
//                       style: TextStyle(
//                         color: Color(0xFF2D8A8A),
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//         ],
//       ),
//     );
//   }
// }