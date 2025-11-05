import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:reciclaje_app/auth/auth_service.dart';
import 'package:reciclaje_app/components/availability_data.dart';
import 'package:reciclaje_app/components/condition_selector.dart';
import 'package:reciclaje_app/components/location_map_preview.dart';
import 'package:reciclaje_app/components/photo_gallery_widget.dart';
import 'package:reciclaje_app/components/photo_validation.dart';
import 'package:reciclaje_app/utils/Fixed43Cropper.dart';
// import 'package:reciclaje_app/components/row_button_2.dart';
import 'package:reciclaje_app/database/photo_database.dart';
import 'package:reciclaje_app/model/photo.dart';
import 'package:reciclaje_app/model/recycling_items.dart';
// import 'package:reciclaje_app/screen/home_screen.dart';
import 'package:reciclaje_app/components/my_button.dart';
import 'package:reciclaje_app/components/category_tags.dart';
import 'package:reciclaje_app/components/my_textformfield.dart';
import 'package:reciclaje_app/components/limit_character_two.dart';
import 'package:reciclaje_app/database/article_database.dart';
import 'package:reciclaje_app/database/category_database.dart';
import 'package:reciclaje_app/database/deliver_database.dart';
import 'package:reciclaje_app/model/article.dart';
import 'package:reciclaje_app/model/category.dart';
import 'package:reciclaje_app/model/deliver.dart';
import 'package:reciclaje_app/screen/distribuidor/navigation_screens.dart';
import 'package:reciclaje_app/services/workflow_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DetailRecycleScreen extends StatefulWidget {
  final RecyclingItem item;
  const DetailRecycleScreen({
    super.key,
    required this.item,
  });

  @override
  State<DetailRecycleScreen> createState() => _DetailRecycleScreenState();
}

class _DetailRecycleScreenState extends State<DetailRecycleScreen> {
  // final _formKey = GlobalKey<FormState>();
  final _itemNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  final articleDatabase = ArticleDatabase();
  final categoryDatabase = CategoryDatabase();
  final deliverDatabase = DeliverDatabase();
  final photoDatabase = PhotoDatabase();  
  final workflowService = WorkflowService();

  final _authService = AuthService();
  String? _currentUserEmail;
  
  List<Category> _categories = [];
  List<Photo> _photos = [];
  List<Photo> _photosToDelete = [];
  List<XFile> pickedImages = [];

  Photo? _mainPhoto;
  bool _isLoadingPhotos = true;

  final ImagePicker _imagePicker = ImagePicker();
  bool _isUploadingPhoto = false;
  int _uploadedPhotoCount = 0;
  

  Category? _selectedCategory;
  String? _selectedCondition;
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _isEditing = false;
  Set<int> _usedCategoryIds = {};
  Set<int> _disabledCategoryIds = {};
  
  // Location variables
  LatLng? _selectedLocation;
  String? _selectedAddress;

  // Availability
  AvailabilityData? _selectedAvailability;
  
  // Original data for comparison
  late String _originalTitle;
  late String _originalDescription;
  late String _originalCategoryName;
  late String _originalConditionName;
  late String _originalAddress;
  late LatLng _originalLocation;
  late AvailabilityData? _originalAvailability;

  @override
  void initState() {
    super.initState();
    _initializeData();
    _loadCategories();
    _loadPhotos();
    _loadDisabledCategories();
    _debugDatabaseStructure(); // ✅ Debug temporal

    _currentUserEmail = _authService.getCurrentUserEmail();
  }

  // ✅ Método para refrescar categorías bloqueadas cuando se necesite
  Future<void> _refreshDisabledCategories() async {
    if (_isOwner) {
      await _loadDisabledCategories();
      print('🔄 Categorías bloqueadas refrescadas');
    }
  }

  // ✅ Método debug temporal para verificar la estructura de la DB
  Future<void> _debugDatabaseStructure() async {
    try {
      print('🔍 DEBUG: Verificando estructura de la tabla photo...');
      
      // Intentar obtener todas las fotos para debug
      final allPhotos = await Supabase.instance.client
          .from('photo')
          .select('*')
          .limit(5);
      
      print('📊 Total fotos en DB (muestra): ${allPhotos.length}');
      for (var photo in allPhotos) {
        print('   - Foto: ${photo['fileName']} -> Artículo ID: ${photo['article_id']}');
      }
      
      // Verificar específicamente para este artículo
      final articlePhotos = await Supabase.instance.client
          .from('photo')
          .select('*')
          .eq('article_id', widget.item.id);
      
      print('📸 Fotos para artículo ${widget.item.id}: ${articlePhotos.length}');
      for (var photo in articlePhotos) {
        print('   - ${photo['fileName']} (isMain: ${photo['isMain']})');
      }
      
    } catch (e) {
      print('❌ Error en debug de estructura: $e');
    }
  }

  bool get _isOwner => widget.item.userEmail == _currentUserEmail;
  

  void _initializeData() {
    // Store original data
    _originalTitle = widget.item.title;
    _originalDescription = widget.item.description ?? '';
    _originalCategoryName = widget.item.categoryName;
    _originalConditionName = widget.item.condition ?? '';
    _originalAddress = widget.item.address;
    _originalLocation = LatLng(widget.item.latitude, widget.item.longitude);

    // prints row values from database
    print('🔍 Loading availability data:');
    print('   Days: ${widget.item.availableDays}');
    print('   Start Time: ${widget.item.availableTimeStart}');
    print('   End Time: ${widget.item.availableTimeEnd}');

    _originalAvailability = AvailabilityData.fromDatabase(
      days: widget.item.availableDays,
      startTime: widget.item.availableTimeStart,
      endTime: widget.item.availableTimeEnd,
    );

    // print parsed availability data
    if (_originalAvailability != null) {
    print('✅ Parsed availability:');
    print('   Days: ${_originalAvailability!.selectedDays}');
    print('   Start: ${_originalAvailability!.startTime}');
    print('   End: ${_originalAvailability!.endTime}');
    } else {
      print('❌ No availability data found');
    }

    // initialize selected availability with original data
    _selectedAvailability = _originalAvailability;
    
    // Initialize controllers with current data
    _itemNameController.text = widget.item.title;
    _descriptionController.text = widget.item.description ?? '';
    _selectedLocation = LatLng(widget.item.latitude, widget.item.longitude);
    _selectedAddress = widget.item.address;

    _selectedCondition = widget.item.condition;

    // initializar el categoria seleccionado con el articulo actual
    _selectedCategory = Category(
      id: widget.item.categoryID ?? 0,
      name: widget.item.categoryName,
    );
  }

  void _onImagesChanged(List<XFile> images) {
    setState(() {
      pickedImages = images;
    });
  }

  Future<void> _loadPhotos() async {
    try {
      setState(() {
        _isLoadingPhotos = true;
      });

      print('🔍 Intentando cargar fotos para artículo ID: ${widget.item.id}');

      // load all photos for this article
      final photos = await photoDatabase.getPhotosByArticleId(widget.item.id);
      final mainPhoto = await photoDatabase.getMainPhotoByArticleId(widget.item.id);

      setState(() {
        _photos = photos;
        _mainPhoto = mainPhoto;
        _isLoadingPhotos = false;
      });

      print('✅ Cargadas ${_photos.length} fotos para artículo ${widget.item.id}');
      if (_mainPhoto != null) {
        print('✅ Foto principal encontrada: ${_mainPhoto!.fileName}');
      } else {
        print('⚠️ No se encontró foto principal');
      }

      // Debug: Print photo details
      for (int i = 0; i < _photos.length; i++) {
        final photo = _photos[i];
        print('📸 Foto ${i + 1}: ${photo.fileName} - URL: ${photo.url}');
      }

    } catch (e) {
      setState(() {
        _isLoadingPhotos = false;
      });
      print('❌ Error loading photos: $e');
      print('   Stack trace: ${StackTrace.current}');
    }
  }

  // ✅ Open cropper for image (same as RegisterRecycle)
  Future<XFile> _openCropper(BuildContext context, XFile file) async {
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

  Future<void> _addPhoto() async {
    try {
      // Check photo limit (including existing photos + picked images)
      final totalPhotos = _photos.length + (_mainPhoto != null ? 1 : 0) + pickedImages.length;
      if (totalPhotos >= 10) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Límite de 10 fotos alcanzado'), backgroundColor: Colors.orange),
        );
        return;
      }

      // ✅ Show dialog to choose between camera or gallery
      final ImageSource? source = await showDialog<ImageSource>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Seleccionar foto'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.camera_alt, color: Color(0xFF2D8A8A)),
                  title: const Text('Tomar foto'),
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library, color: Color(0xFF2D8A8A)),
                  title: const Text('Seleccionar de galería'),
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
              ],
            ),
          );
        },
      );

      if (source == null) return; // User cancelled

      setState(() => _isUploadingPhoto = true);

      List<XFile>? newImages;

      if (source == ImageSource.camera) {
        // ✅ Take a single photo with camera
        final XFile? photo = await _imagePicker.pickImage(
          source: ImageSource.camera,
          maxWidth: 1920,
          maxHeight: 1080,
          imageQuality: 80,
        );
        
        if (photo != null) {
          // ✅ Crop the camera photo
          final croppedPhoto = await _openCropper(context, photo);
          newImages = [croppedPhoto];
        }
      } else {
        // ✅ Pick multiple images from gallery
        final pickedImages = await _imagePicker.pickMultiImage(
          maxWidth: 1920,
          maxHeight: 1080,
          imageQuality: 80,
        );
        
        if (pickedImages.isNotEmpty) {
          // ✅ Crop each image sequentially
          final List<XFile> croppedImages = [];
          for (final image in pickedImages) {
            final cropped = await _openCropper(context, image);
            croppedImages.add(cropped);
          }
          newImages = croppedImages;
        }
      }

      if (newImages != null && newImages.isNotEmpty) {
        // Calculate remaining slots
        final remainingSlots = 10 - totalPhotos;
        final imagesToAdd = newImages.take(remainingSlots).toList();
        
        // Add to picked images list
        _onImagesChanged([...pickedImages, ...imagesToAdd]);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${imagesToAdd.length} foto(s) seleccionada(s)'), 
            backgroundColor: Colors.green
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isUploadingPhoto = false);
    }
  }

  // ✅ Helper method to upload a single photo with retry logic
  Future<String> _uploadSinglePhoto(
    XFile image, 
    String filePath, 
    int maxRetries,
  ) async {
    final storage = Supabase.instance.client.storage;
    int attempt = 0;
    
    while (attempt < maxRetries) {
      try {
        print('📤 Upload attempt ${attempt + 1}/$maxRetries for: $filePath');
        
        // Read the file as bytes
        final bytes = await image.readAsBytes();
        
        // Small delay between retries to allow connection recovery
        if (attempt > 0) {
          await Future.delayed(Duration(seconds: attempt));
        }
        
        // Upload to supabase storage with timeout
        await storage.from('article-images').uploadBinary(
          filePath, 
          bytes,
          fileOptions: const FileOptions(
            cacheControl: '3600',
            upsert: false,
          ),
        ).timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            throw TimeoutException('Upload timeout after 30 seconds');
          },
        );

        // Get the public url
        final publicUrl = storage.from('article-images').getPublicUrl(filePath);
        print('✅ Upload successful: $filePath');
        
        return publicUrl;
        
      } catch (e) {
        attempt++;
        print('⚠️ Upload attempt $attempt failed: $e');
        
        if (attempt >= maxRetries) {
          print('❌ All upload attempts failed for: $filePath');
          rethrow;
        }
        
        // Wait before retry (exponential backoff)
        await Future.delayed(Duration(seconds: attempt * 2));
      }
    }
    
    throw Exception('Failed to upload after $maxRetries attempts');
  }

  Future<void> _uploadAndSavePhotos(int articleId, String userId) async {
  if (pickedImages.isEmpty) return;

  setState(() {
    _isUploadingPhoto = true;
    _uploadedPhotoCount = 0;
  });

  // Track successfully uploaded photos for cleanup on failure
  List<String> uploadedPaths = [];

  try {
    // Get the current photos count to continue the upload order sequence
    final existingPhotosCount = await photoDatabase.getPhotosCountByArticleId(articleId);
    
    // Check if article already has a main photo
    final bool hasMainPhoto = await photoDatabase.hasMainPhoto(articleId);

    for (int i = 0; i < pickedImages.length; i++) {
      final image = pickedImages[i];
      
      // Calculate the proper upload order (continue from existing photos)
      final uploadOrder = existingPhotosCount + i;
      
      // Clean the image name and create a unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final cleanUserId = userId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), ''); // Remove special characters
      final extension = image.name.split('.').last.toLowerCase();

      //validate file extension
      if (!['jpg', 'jpeg', 'png'].contains(extension)) {
        throw Exception('Formato de imagen no valido: $extension');
      }

      // Use the calculated upload order in filename
      final fileName = '${timestamp}_${uploadOrder}_article_${articleId}.$extension';
      final filePath = 'users/$cleanUserId/articles/$fileName';

      print('📸 Processing photo ${i + 1}/${pickedImages.length}: $fileName');

      // ✅ Upload with retry logic (3 attempts)
      final publicUrl = await _uploadSinglePhoto(image, filePath, 3);
      uploadedPaths.add(filePath);

      // Read bytes for file size
      final bytes = await image.readAsBytes();

      // Create photo record in the database
      final newPhoto = Photo(
        articleID: articleId,
        url: publicUrl,
        fileName: fileName,
        filePath: filePath,
        fileSize: bytes.length,
        mimeType: 'image/$extension',
        isMain: !hasMainPhoto && i == 0, // First new image becomes main only if no main photo exists
        uploadOrder: uploadOrder, // Use calculated upload order
      );

      await photoDatabase.createPhoto(newPhoto);

      setState(() {
        _uploadedPhotoCount = i + 1;
      });

      print('✅ Photo ${i + 1}/${pickedImages.length} saved: $fileName (uploadOrder: $uploadOrder)');
    }

    // update article's lastUpdate after adding photos
    await articleDatabase.updateArticleLastUpdate(articleId);

    print('✅ Todas las fotos guardadas correctamente para el articulo $articleId');

  } catch(e) {
    print('❌ Error detallado en subir y guardar fotos: $e');
    
    // ✅ Cleanup: Delete successfully uploaded files if process failed
    if (uploadedPaths.isNotEmpty) {
      print('🧹 Cleaning up ${uploadedPaths.length} uploaded files due to error...');
      for (final path in uploadedPaths) {
        try {
          await Supabase.instance.client.storage
              .from('article-images')
              .remove([path]);
          print('🗑️ Deleted: $path');
        } catch (deleteError) {
          print('⚠️ Could not delete $path: $deleteError');
        }
      }
    }
    
    throw Exception('Error al subir imágenes: $e');
  } finally {
    setState(() {
      _isUploadingPhoto = false;
      _uploadedPhotoCount = 0;
    });
  }
}

  Future<void> _loadCategories() async {
    try {
      final categories = await categoryDatabase.getAllCategories();
      setState(() {
        _categories = categories;
        // Find and select the current category
        _selectedCategory = categories.firstWhere(
          (cat) => cat.name == widget.item.categoryName,
          orElse: () => categories.isNotEmpty ? categories.first : Category(),
        );
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cargar categorías: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _loadDisabledCategories() async {
    if (!_isOwner) return;

    try {
      print('🔄 Recargando categorías bloqueadas para artículo ${widget.item.id}...');
      
      // ✅ Excluir la categoría del artículo actual
      final disabledIds = await workflowService.getUsedPendingCategoryIds(
        excludeArticleId: widget.item.id,
      );
      
      if (mounted) {
        setState(() {
          _disabledCategoryIds = disabledIds;
        });
      }

      print('🔒 Categorías bloqueadas para edición del artículo ${widget.item.id}:');
      print('   IDs bloqueados: $_disabledCategoryIds');
      print('   Categoría actual (${widget.item.categoryID} - ${widget.item.categoryName}) está permitida ✅');
      
      // Debug: Mostrar nombres de categorías bloqueadas
      final blockedNames = _categories
          .where((cat) => _disabledCategoryIds.contains(cat.id))
          .map((cat) => cat.name)
          .join(', ');
      if (blockedNames.isNotEmpty) {
        print('   Categorías bloqueadas por nombre: $blockedNames');
      } else {
        print('   ✅ No hay categorías bloqueadas (usuario puede usar cualquier categoría)');
      }
    } catch (e) {
      print('❌ Error cargando categorías bloqueadas: $e');
    }
  }

  Deliver? updatedDeliver;

  Future<void> _saveChanges() async {
    // if (!_formKey.currentState!.validate()) {
    //   return;
    // }

    if (_selectedCategory != null && 
      _disabledCategoryIds.contains(_selectedCategory!.id)) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'No puedes cambiar a esta categoría porque ya tienes otro artículo pendiente con ella',
        ),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 4),
      ),
    );
    return;
  }

    bool hasChanges = false;

    if (_itemNameController.text.trim() != _originalTitle) hasChanges = true;
    if (_descriptionController.text.trim() != _originalDescription) hasChanges = true;
    if (_selectedCategory?.name != _originalCategoryName) hasChanges = true;
    if (_selectedCondition != _originalConditionName) hasChanges = true;
    if (_selectedAddress != _originalAddress) hasChanges = true;
    if (_selectedLocation != _originalLocation) hasChanges = true;

    // check availability changes
    if (_selectedAvailability?.getDaysForDatabase() != _originalAvailability?.getDaysForDatabase()) hasChanges = true;
    if (_selectedAvailability?.getStartTimeForDatabase() != _originalAvailability?.getStartTimeForDatabase()) hasChanges = true;
    if (_selectedAvailability?.getEndTimeForDatabase() != _originalAvailability?.getEndTimeForDatabase()) hasChanges = true;

    if (_photosToDelete.isNotEmpty) hasChanges = true;

    //check for picked images
    if (pickedImages.isNotEmpty) hasChanges = true;

    if (!hasChanges) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay cambios para actualizar'),
          backgroundColor: Colors.amber, 
        )
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // 1. delete marked photos (batch deletion for better performance)
      if (_photosToDelete.isNotEmpty) {
        // check if main photo is being deleted
        bool mainPhotoDeleted = false;
        for (Photo photo in _photosToDelete) {
          if (await photoDatabase.isMainPhoto(photo)) {
            mainPhotoDeleted = true;
            break;
          }
        }

        // delete all marked photos at once
        await photoDatabase.deleteMultiplePhotos(_photosToDelete);

        //set new main photo if needed
        if (mainPhotoDeleted) {
          await photoDatabase.setNewMainPhoto(widget.item.id);
        }

        // update article's lastUpdate after deleting photos
        await articleDatabase.updateArticleLastUpdate(widget.item.id);

        print('Deleted ${_photosToDelete.length} photos');  
      }

      // 2. upload and save new photos if any
      if (pickedImages.isNotEmpty) {
        final userId = widget.item.ownerUserId.toString();
        await _uploadAndSavePhotos(widget.item.id, userId);
        //clear picked images after upload
        setState(() {
          pickedImages.clear();
        });
      }

      // 3. Update deliver if location or address changed
      if (_selectedLocation != _originalLocation || 
          _selectedAddress != _originalAddress) {
        
        print('🔄 Detectados cambios en ubicación:');
        print('   Deliver ID: ${widget.item.deliverID}');
        print('   Original: ${_originalAddress} (${_originalLocation.latitude}, ${_originalLocation.longitude})');
        print('   Nueva: ${_selectedAddress} (${_selectedLocation!.latitude}, ${_selectedLocation!.longitude})');
        
        if (widget.item.deliverID == null) {
          throw Exception('El deliverID no puede ser nulo al actualizar la ubicación');
        }

        Deliver updatedDeliver = Deliver(
          id: widget.item.deliverID, // ✅ Usar el deliverID correcto
          address: _selectedAddress ?? 'Ubicación no especificada',
          lat: _selectedLocation!.latitude,
          lng: _selectedLocation!.longitude,
        );

        await deliverDatabase.updateDeliver(updatedDeliver);
        print('✅ Ubicación actualizada exitosamente en la base de datos');
      }

      // 4. Update article
      Article updatedArticle = Article(
        id: widget.item.id,
        name: _itemNameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty 
            ? null 
            : _descriptionController.text.trim(),
        categoryID: _selectedCategory!.id,
        condition: _selectedCondition,
        deliverID: widget.item.deliverID, // ✅ Mantener el deliverID original
        userId: widget.item.ownerUserId,
        availableDays: _selectedAvailability?.getDaysForDatabase(),
        availableTimeStart: _selectedAvailability?.getStartTimeForDatabase(),
        availableTimeEnd: _selectedAvailability?.getEndTimeForDatabase(),
        workflowStatus: 'pendiente',
        state: 1,
      );

      await articleDatabase.updateArticle(updatedArticle);

      // 5. reload photos to update UI
      await _loadPhotos();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Artículo actualizado correctamente'),
          backgroundColor: Colors.green,
        ),
      );

      setState(() {
        _isEditing = false;
        _isSubmitting = false;
        _photosToDelete.clear();
      });

      // Update original values
      _originalTitle = _itemNameController.text.trim();
      _originalDescription = _descriptionController.text.trim();
      _originalCategoryName = _selectedCategory!.name!;
      _originalConditionName = _selectedCondition ?? '';
      _originalAddress = _selectedAddress!;
      _originalLocation = _selectedLocation!;
      _originalAvailability = _selectedAvailability;

      // ✅ Recargar categorías bloqueadas después de guardar
      await _loadDisabledCategories();
      print('🔄 Categorías bloqueadas actualizadas después de guardar cambios');

    } catch (e) {
      setState(() {
        _isSubmitting = false;    
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al actualizar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteArticle() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: const Text('¿Estás seguro de que quieres eliminar este artículo? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _isSubmitting = true;
      });

      try {
        Article articleToDelete = Article(
          id: widget.item.id,
          name: widget.item.title,
          state: 0, // This will be set in the delete method
        );

        await articleDatabase.deleteArticle(articleToDelete);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Artículo eliminado correctamente'),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate back with result to refresh the home screen
        Navigator.pop(context, true);

        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => NavigationScreens()));

      } catch (e) {
        setState(() {
          _isSubmitting = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al eliminar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _itemNameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar Artículo' : 'Detalles del Artículo'),
        backgroundColor: const Color(0xFF2D8A8A),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
  child: _isLoading
      ? const Center(
          child: CircularProgressIndicator(
            color: Color(0xFF2D8A8A),
          ),
        )
      : SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              

              // photo gallery
              const Text(
                'Fotos del articulo',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D8A8A),
                ),
              ),
              const SizedBox(height: 8),
                PhotoGalleryWidget(
                  photos: _photos,
                  mainPhoto: _mainPhoto,
                  isLoading: _isLoadingPhotos || _isUploadingPhoto,
                  isOwner: _isOwner,
                  photosToDelete: _photosToDelete,
                  pickedImages: pickedImages,
                  onPhotosToDeleteChanged: _isOwner && _isEditing ? (photosToDelete) {
                    setState(() {
                      _photosToDelete = photosToDelete;
                    });
                  } : null,
                  onPickedImagesChanged: _isOwner && _isEditing ? (updatedImages) {
                    setState(() {
                      pickedImages = updatedImages;
                    });
                  } : null,
                  onAddPhoto: _isOwner && _isEditing ? (pickedImages.length + _photos.length + (_mainPhoto != null ? 1 : 0) < 10) 
                      ? _addPhoto 
                      : null 
                    : null,
                ),

                if (_isOwner && _isEditing) ... [
                  const SizedBox(height: 12),
                  PhotoValidation(
                    allPhotos: [..._photos, if (_mainPhoto != null) _mainPhoto!],
                    photosToDelete: _photosToDelete,
                    pickedImages: pickedImages,
                    mainPhoto: _mainPhoto,
                    maxPhotos: 10,
                  ),
                ],
                const SizedBox(height: 20),

              Text(
                _isEditing 
                    ? 'Edita los datos del artículo'
                    : 'Información del artículo',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D8A8A),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              // Item name field
              MyTextFormField(
                controller: _itemNameController,
                hintText: 'Nombre del artículo',
                text: 'Nombre del artículo',
                obscureText: false,
                isEnabled: _isEditing,
                prefixIcon: const Icon(Icons.recycling),
              ),
              const SizedBox(height: 16),

              CategoryTags(
                categories: _categories, 
                selectedCategory: _selectedCategory, 
                onCategorySelected: _isEditing ? (category) {
                  setState(() {
                    _selectedCategory = category;
                  });
                } : null,
                disabledCategoryIds: _disabledCategoryIds,
                labelText: 'Categoría',
                isEnabled: _isEditing,
                validator: _isEditing ? (value) {
                  if (value == null) {
                    return 'Por favor selecciona una categoría';
                  }
                  return null;
                } : null,
              ),

              const SizedBox(height: 16),

              ConditionSelector(
                selectedCondition: _selectedCondition,
                onConditionSelected: _isEditing ? (condition) {
                  setState(() {
                    _selectedCondition = condition;
                  });
                } : null,
                labelText: 'Estado',
                isEnabled: _isEditing,
                validator: _isEditing ? (value) {
                  if (value == null) {
                    return 'Por favor selecciona el estado del artículo';
                  }
                  return null;
                } : null,
              ),

              // Description field
              LimitCharacterTwo(
                controller: _descriptionController,
                hintText: 'Describe tu artículo',
                text: 'Descripción',
                obscureText: false,
                isEnabled: _isEditing,
                isVisible: true,
              ),
              const SizedBox(height: 16),

              // Location section
              // Text(
              //   _isEditing ? 'Preferencia de entrega' : 'Ubicación de entrega',
              //   style: const TextStyle(
              //     fontSize: 16,
              //     fontWeight: FontWeight.bold,
              //     color: Color(0xFF2D8A8A),
              //   ),
              // ),

              LocationMapPreview(
                location: _selectedLocation ?? _originalLocation,
                originalLocation: _isEditing ? _originalLocation : null,
                address: _selectedAddress ?? widget.item.address,
                isEditing: _isEditing,
                onLocationChanged: _isEditing
                    ? (location, address) {
                        setState(() {
                          _selectedLocation = location;
                          _selectedAddress = address;
                        });
                      }
                    : null,
              ),

              const SizedBox(height: 16),

              // availability
              AvailabilityPicker(
                selectedAvailability: _isEditing
                    ? _selectedAvailability 
                    : _originalAvailability, 
                onAvailabilitySelected: _isEditing
                    ? (AvailabilityData? availability) {
                        setState(() {
                          _selectedAvailability = availability;
                        });
                      } 
                    : null,
                labelText: 'Disponibilidad para entrega',
                prefixIcon: Icons.calendar_month,
                isRequired: false,
              ),

              // User info section (only in view mode)
              if (!_isEditing && !_isOwner) ...[
                const SizedBox(height: 20),
                const Text(
                  'Información del usuario',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D8A8A),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2D8A8A).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF2D8A8A).withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.person, color: Color(0xFF2D8A8A)),
                          const SizedBox(width: 8),
                          Text(
                            widget.item.userName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.email, color: Color(0xFF2D8A8A)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.item.userEmail,
                              style: const TextStyle(color: Color(0xFF2D8A8A)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Action buttons
              if (_isOwner) ... [
                if (_isEditing)
                Row(
                  children: [
                    Expanded(
                      child: _isSubmitting
                          ? Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2D8A8A),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Guardando...',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : MyButton(
                              onTap: _saveChanges,
                              text: 'Guardar Cambios',
                              color: Color(0xFF2D8A8A),
                            ),
                    ),
                  ],
                )
              else
                Column(
                  children: [
                    MyButton(
                      onTap: () async {
                        // ✅ Refrescar categorías bloqueadas antes de entrar en modo edición
                        await _refreshDisabledCategories();
                        setState(() {
                          _isEditing = true;
                        });
                      },
                      text: 'Editar Artículo',
                      color: Color(0xFF2D8A8A),
                    ),
                    const SizedBox(height: 12),
                    MyButton(
                      onTap: _isSubmitting ? null : _deleteArticle, 
                      text: 'Eliminar Artículo', 
                      color: Colors.grey
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
),

    );
  }
}