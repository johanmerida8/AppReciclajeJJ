// ignore_for_file: avoid_print

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:reciclaje_app/auth/auth_service.dart';
import 'package:reciclaje_app/components/availability_data.dart';
import 'package:reciclaje_app/components/condition_selector.dart';
import 'package:reciclaje_app/components/location_selector.dart';
// import 'package:reciclaje_app/components/date_time_picker.dart';
// import 'package:reciclaje_app/components/image_modal.dart';
import 'package:reciclaje_app/components/my_button.dart';
import 'package:reciclaje_app/components/category_tags.dart';
import 'package:reciclaje_app/components/my_textformfield.dart';
import 'package:reciclaje_app/components/limit_character_two.dart';
// import 'package:reciclaje_app/components/row_button.dart';
import 'package:reciclaje_app/components/row_button_2.dart';
import 'package:reciclaje_app/database/article_database.dart';
import 'package:reciclaje_app/database/category_database.dart';
import 'package:reciclaje_app/database/deliver_database.dart';
import 'package:reciclaje_app/database/photo_database.dart';
import 'package:reciclaje_app/database/users_database.dart';
import 'package:reciclaje_app/model/article.dart';
import 'package:reciclaje_app/model/category.dart';
import 'package:reciclaje_app/model/deliver.dart';
import 'package:reciclaje_app/model/photo.dart';
import 'package:reciclaje_app/screen/map_picker_screen.dart';
import 'package:reciclaje_app/services/workflow_service.dart'; // ✅ Nuevo servicio
import 'package:supabase_flutter/supabase_flutter.dart';

class RegisterRecycleScreen extends StatefulWidget {
  // ✅ Parámetros opcionales para registro rápido desde mapa
  final LatLng? preselectedLocation;
  final String? preselectedAddress;

  const RegisterRecycleScreen({
    super.key,
    this.preselectedLocation,
    this.preselectedAddress,
  });

  @override
  State<RegisterRecycleScreen> createState() => _RegisterRecycleScreenState();
}

class _RegisterRecycleScreenState extends State<RegisterRecycleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _itemNameController = TextEditingController();
  final _descriptionController = TextEditingController();

  final authService = AuthService();
  final userDatabase = UsersDatabase();
  final workflowService = WorkflowService(); // ✅ Nuevo servicio
  
  final articleDatabase = ArticleDatabase();
  final categoryDatabase = CategoryDatabase();
  final deliverDatabase = DeliverDatabase();
  final photoDatabase = PhotoDatabase();
  
  List<Category> _categories = [];
  Category? _selectedCategory;
  String? _selectedCondition;
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _canPublish = true; // ✅ Estado para saber si puede publicar
  Set<int> _usedCategoryIds = {};

  // Location variables
  LatLng? _selectedLocation;
  String? _selectedAddress;

  // DateTime? _selectedDeliveryDateTime;
  AvailabilityData? _selectedAvailability;

  List<XFile> pickedImages = [];
  bool isImageReceived = false;

  bool _isUploadingImages = false;
  int _uploadedImagesCount = 0;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _checkUserPublishStatus(); // ✅ Verificar estado de publicación
    
    // ✅ Inicializar ubicación preseleccionada desde mapa
    if (widget.preselectedLocation != null) {
      _selectedLocation = widget.preselectedLocation;
      _selectedAddress = widget.preselectedAddress ?? 'Ubicación seleccionada';
    }
  }

  // ✅ Verificar si el usuario puede publicar al inicializar
  Future<void> _checkUserPublishStatus() async {
    final canPublish = await workflowService.canUserPublish();
    final usedCategories = await workflowService.getUsedPendingCategoryIds();
    setState(() {
      _canPublish = canPublish;
      _usedCategoryIds = usedCategories;
    });

    print('🔒 Categorías bloqueadas para nuevo registro: $_usedCategoryIds');
    print('✅ Usuario puede publicar: $_canPublish');
  }

  @override
  void dispose() {
    _itemNameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _onImagesChanged(List<XFile> images) {
    setState(() {
      pickedImages = images;
    });
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await categoryDatabase.getAllCategories();
      setState(() {
        _categories = categories;
        _isLoading = false;
        _selectedCategory = null;
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

  Future<void> _pickLocation() async {
    try {
      // default location (Cochabamba, Bolivia)
      final defaultLocation = _selectedLocation ??
          LatLng(-17.393178, -66.156838);
      
      final res = await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => MapPickerScreen(
            initialLocation: defaultLocation, 
          ),
        ),
      );

      if (res != null && res is Map<String, dynamic>) {
        final LatLng pickedLocation = res['location'];
        final String pickedAddress = res['address'];

        setState(() {
          _selectedLocation = pickedLocation;
          _selectedAddress = pickedAddress;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al seleccionar ubicación: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _registerItem() async {
    // ✅ Verificar si el usuario puede publicar
    if (!await workflowService.canUserPublish()) {
      _showCannotPublishDialog();
      return;
    }
    
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor selecciona una categoría'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedCondition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: SnackBar(
            content: Text('Por favor selecciona el estado del articulo'),
            backgroundColor: Colors.red,
          ),
        )
      );
      return;
    }

    if (_selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor selecciona una ubicación de entrega'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      //get current user id
      final currentUserEmail = authService.getCurrentUserEmail();
      if (currentUserEmail == null) {
        throw Exception('Usuario no autenticado');
      } 

      //get user id from the user table based on email
      final currentUser = await userDatabase.getUserByEmail(currentUserEmail);

      if (currentUser == null) {
        throw Exception('No se encontro el usuario en la base de datos');
      }

      // 1. create the deliver record
      final newDeliver = Deliver(
        address: _selectedAddress ?? 'Ubicación no especificada',
        lat: _selectedLocation!.latitude,
        lng: _selectedLocation!.longitude,
        // state: 1
      );

      final deliverID = await deliverDatabase.createDeliver(newDeliver);

      final newArticle = Article(
        name: _itemNameController.text.trim(),
        categoryID: _selectedCategory!.id,
        condition: _selectedCondition,
        description: _descriptionController.text.trim().isEmpty 
            ? null 
            : _descriptionController.text.trim(),
        deliverID: deliverID,
        userId: currentUser.id,
        state: 1, // Active state
        workflowStatus: 'pendiente', // ✅ Estado inicial del workflow

        // Availability fields
        availableDays: _selectedAvailability?.getDaysForDatabase(),
        availableTimeStart: _selectedAvailability?.getStartTimeForDatabase(),
        availableTimeEnd: _selectedAvailability?.getEndTimeForDatabase(),
      );

      final articleId = await articleDatabase.createArticle(newArticle);

      // upload and save photos if any exist
      if (pickedImages.isNotEmpty) {
        if (currentUser.id != null) {
          try {
            await _uploadAndSavePhotos(articleId, currentUser.id.toString());
            print('✅ Fotos subidas exitosamente');
          } catch (photoError) {
            print('⚠️ Error subiendo fotos: $photoError');
            // ✅ No fallar el registro por problemas de fotos
            // El artículo ya fue creado exitosamente
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  '⚠️ Artículo registrado, pero las fotos no se pudieron subir.\n'
                  'Puedes editar el artículo más tarde para agregar fotos.',
                ),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 4),
              ),
            );
          }
        } else {
          throw Exception('El ID del usuario es nulo');
        }
      }

      // ✅ Mostrar mensaje de éxito con información del workflow
      _showSuccessDialog();  

      // clear form
      _clearForm();

      // refresh status after registration
      _checkUserPublishStatus();

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al registrar artículo: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }



  // ✅ Mostrar diálogo cuando no puede publicar
  void _showCannotPublishDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.warning, color: Colors.orange, size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'No puedes publicar',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ya tienes un artículo pendiente de revisión.',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Espera hasta que:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '• Una empresa de reciclaje se comunique contigo\n'
                      '• Se complete la recogida del artículo\n'
                      '• El proceso cambie a estado "Completado"',
                      style: TextStyle(fontSize: 13, height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Esto evita el abuso del sistema y asegura un servicio de calidad para todos.',
                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Entendido'),
            ),
          ],
        );
      },
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) { // ✅ Usar dialogContext en lugar de context
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle, color: Colors.green, size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  '¡Artículo Registrado!',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tu artículo ha sido registrado exitosamente.',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info, color: Colors.orange.shade700, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Próximos pasos:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '• Tu artículo está en estado "Pendiente"\n'
                      '• Una empresa de reciclaje lo revisará\n'
                      '• Te contactarán para coordinar la recogida\n'
                      '• Puedes publicar hasta 3 artículos simultáneos',
                      style: TextStyle(fontSize: 13, height: 1.4),
                    ),
                  ],
                ),
              ),
              if (_selectedAvailability != null && _selectedAvailability!.isComplete) ...[
                const SizedBox(height: 12),
                Text(
                  'Disponible: ${_selectedAvailability!.getDisplayText()}',
                  style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic),
                ),
              ],
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                // ✅ Cerrar el diálogo primero usando dialogContext
                Navigator.of(dialogContext).pop();
                
                // ✅ Luego volver a HomeScreen usando el context original
                // Necesitamos un pequeño delay para evitar conflictos
                Future.microtask(() {
                  if (mounted) {
                    Navigator.of(context).pop(true); // ✅ Volver con resultado true
                  }
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2D8A8A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('Entendido'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _uploadAndSavePhotos(int articleId, String userId) async {
  if (pickedImages.isEmpty) return;

  setState(() {
    _isUploadingImages = true;
    _uploadedImagesCount = 0;
  });

  try {
    final storage = Supabase.instance.client.storage;
    
    // ✅ Verify bucket exists and is accessible
    try {
      print('🔍 Verificando bucket article-images...');
      final files = await storage.from('article-images').list(
        path: '',
        searchOptions: const SearchOptions(limit: 1),
      );
      print('✅ Bucket article-images accesible (${files.length} items encontrados)');
    } catch (e) {
      print('⚠️ Advertencia: No se pudo verificar el bucket: $e');
      // Continuar anyway, el bucket existe según tu captura
    }

    for (int i = 0; i < pickedImages.length; i++) {
      final image = pickedImages[i];
      
      print('📸 Processing image ${i + 1}/${pickedImages.length}');
      print('   Path: ${image.path}');
      print('   Name: ${image.name}');
      print('   MIME type: ${image.mimeType}');
      
      // ✅ Verify file exists before processing
      final imageFile = File(image.path);
      if (!await imageFile.exists()) {
        print('❌ File does not exist: ${image.path}');
        throw Exception('El archivo de imagen no existe: ${image.name}');
      }
      
      // ✅ Verify file is readable and not corrupted
      final fileStats = await imageFile.stat();
      print('   File stats:');
      print('     - Size: ${fileStats.size} bytes');
      print('     - Modified: ${fileStats.modified}');
      print('     - Accessible: ${fileStats.mode}');
      
      if (fileStats.size == 0) {
        throw Exception('El archivo está vacío (0 bytes): ${image.name}');
      }
      
      // Clean the image name and create a unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final cleanUserId = userId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), ''); // Remove special characters
      
      // ✅ Get extension from path instead of name (more reliable after cropping)
      final extension = image.path.split('.').last.toLowerCase();

      //validate file extension
      if (!['jpg', 'jpeg', 'png'].contains(extension)) {
        throw Exception('Formato de imagen no valido: $extension');
      }

      final fileName = '${timestamp}_${i}_article_${articleId}.$extension';
      final filePath = 'users/$cleanUserId/articles/$fileName';

      print('📤 Uploading to: $filePath');

      // ✅ Read the file as bytes with error handling
      final bytes = await imageFile.readAsBytes();
      print('   File size: ${bytes.length} bytes (${(bytes.length / 1024 / 1024).toStringAsFixed(2)} MB)');
      
      if (bytes.isEmpty) {
        throw Exception('El archivo está vacío: ${image.name}');
      }

      // Upload to supabase storage with timeout and retry logic
      try {
        print('⏳ Iniciando subida con timeout de 60s...');
        print('   Bucket destino: article-images');
        print('   Ruta destino: $filePath');
        print('   Tamaño archivo: ${(bytes.length / 1024 / 1024).toStringAsFixed(2)} MB');
        
        // ✅ Detectar el content type correcto basado en extensión
        String contentType = 'image/jpeg';
        if (extension == 'png') {
          contentType = 'image/png';
        } else if (extension == 'jpg' || extension == 'jpeg') {
          contentType = 'image/jpeg';
        }
        
        // Intentar subida con configuración optimizada
        final response = await storage
          .from('article-images')
          .uploadBinary(
            filePath, 
            bytes,
            fileOptions: FileOptions(
              cacheControl: '3600',
              upsert: true,
              contentType: contentType,
            ),
          )
          .timeout(
            const Duration(seconds: 60), // ✅ Aumentar timeout a 60s
            onTimeout: () {
              throw Exception('Timeout de subida - tardó más de 60 segundos');
            },
          );

        print('✅ Subida completada exitosamente');
        print('   Respuesta: $response');
      } catch (uploadError) {
        print('❌ Upload error details:');
        print('   Error type: ${uploadError.runtimeType}');
        print('   Error message: $uploadError');
        print('   Stack trace: ${StackTrace.current}');
        
        // ✅ Análisis mejorado de errores
        final errorMessage = uploadError.toString().toLowerCase();
        
        if (errorMessage.contains('timeout')) {
          throw Exception('⏰ La imagen ${i + 1} tardó demasiado en subir (>60s). Intenta con una imagen más pequeña.');
        } else if (errorMessage.contains('clientexception') || 
                   errorMessage.contains('socketexception') ||
                   errorMessage.contains('read failed')) {
          throw Exception('🌐 Error de conexión al subir imagen ${i + 1}.\n'
                          'Verifica:\n'
                          '• Conexión a internet estable\n'
                          '• URL de Supabase correcta\n'
                          '• Bucket configurado correctamente');
        } else if (errorMessage.contains('413') || errorMessage.contains('too large')) {
          throw Exception('📏 Imagen ${i + 1} demasiado grande: ${(bytes.length / 1024 / 1024).toStringAsFixed(2)} MB');
        } else if (errorMessage.contains('401') || errorMessage.contains('403') || 
                   errorMessage.contains('unauthorized') || errorMessage.contains('forbidden')) {
          throw Exception('🔒 Sin permisos para subir imagen ${i + 1}. Verifica las políticas RLS del bucket.');
        } else if (errorMessage.contains('404') || errorMessage.contains('not found')) {
          throw Exception('🗂️ Bucket "article-images" no encontrado. Verifica la configuración de Supabase Storage.');
        } else {
          throw Exception('❌ Error desconocido al subir imagen ${i + 1}: $uploadError');
        }
      }

      // Get the public url (this doesn't make a network call, just constructs the URL)
      final publicUrl = storage.from('article-images').getPublicUrl(filePath);
      
      print('🔗 Public URL: $publicUrl');

      // Create photo record in the database
      final newPhoto = Photo(
        articleID: articleId,
        url: publicUrl,
        fileName: fileName,
        filePath: filePath,
        fileSize: bytes.length,
        mimeType: 'image/$extension',
        isMain: i == 0, // First image as main
        uploadOrder: i,
        // lastUpdate: DateTime.now(),
      );

      await photoDatabase.createPhoto(newPhoto);

      setState(() {
        _uploadedImagesCount = i + 1;
      });

      print('✅ Foto ${i + 1}/${pickedImages.length} subida exitosamente');
      print('   Archivo: ${newPhoto.fileName}');
      print('   Tamaño: ${(bytes.length / 1024 / 1024).toStringAsFixed(2)} MB');
      print('   URL pública: $publicUrl');
      
      // Pequeño delay entre subidas para evitar saturar la conexión
      if (i < pickedImages.length - 1) {
        print('⏸️ Esperando 200ms antes de la siguiente subida...');
        await Future.delayed(const Duration(milliseconds: 200));
      }
    }

    print('🎉 All ${pickedImages.length} photos uploaded successfully for article $articleId');

  } catch(e) {
    print('❌ Error uploading photos: $e');
    print('   Failed at image ${_uploadedImagesCount + 1}/${pickedImages.length}');
    rethrow; // Re-throw to be handled by the calling method
  } finally {
    setState(() {
      _isUploadingImages = false;
      _uploadedImagesCount = 0;
    });
  }
}

  void _clearForm() {
    _itemNameController.clear();
    _descriptionController.clear();
    setState(() {
      _selectedCategory = _categories.isNotEmpty ? _categories.first : null;
      _selectedLocation = null;
      _selectedAddress = null;
      _selectedAvailability = null;
      _selectedCondition = null;
      pickedImages = []; // Clear the images
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF2D8A8A),
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(25.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [

                      const Text(
                        'Publica tu artículo para reciclar',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D8A8A),
                        ),
                        textAlign: TextAlign.left,
                      ),
                      const SizedBox(height: 20),
                      
                      // Image picker section
                      ImageRow(
                        images: pickedImages, 
                        onImagesChanged: _onImagesChanged,
                        maxImages: 10,
                      ),

                      const SizedBox(height: 20),

                      // Item name field
                      MyTextFormField(
                        controller: _itemNameController,
                        hintText: 'Nombre del artículo',
                        text: 'Nombre del artículo',
                        obscureText: false,
                        isEnabled: true,
                        prefixIcon: const Icon(Icons.recycling),
                        validator: (value) {
                          if (value?.isEmpty ?? true) {
                            return 'Por favor ingrese el nombre del artículo';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Category tags
                      CategoryTags(
                        categories: _categories,
                        selectedCategory: _selectedCategory,
                        onCategorySelected: (category) {
                          setState(() {
                            _selectedCategory = category;
                          });
                        },
                        disabledCategoryIds: _usedCategoryIds,
                        labelText: 'Categoría',
                        validator: (value) {
                          if (value == null) {
                            return 'Por favor selecciona una categoría';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      ConditionSelector(
                        selectedCondition: _selectedCondition,
                        onConditionSelected: (condition) {
                          setState(() {
                            _selectedCondition = condition;
                          });
                        },
                        labelText: 'Estado',
                        validator: (value) {
                          if (value == null) {
                            return 'Por favor selecciona el estado del artículo';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),
                      
                      // Description field using LimitCharacterTwo
                      LimitCharacterTwo(
                        controller: _descriptionController,
                        hintText: 'Describe tu artículo',
                        text: 'Descripción',
                        obscureText: false,
                        isEnabled: true,
                        isVisible: true,
                      ),
                      const SizedBox(height: 16),

                      LocationSelector(
                        selectedLocation: _selectedLocation,
                        selectedAddress: _selectedAddress,
                        onPickLocation: _pickLocation,
                        labelText: widget.preselectedLocation == null 
                            ? 'Preferencia de entrega' 
                            : 'Ubicación seleccionada (desde mapa)',
                        isRequired: true,
                      ),

                      const SizedBox(height: 16),

                      // weekly availability picker
                      AvailabilityPicker(
                        selectedAvailability: _selectedAvailability, 
                        onAvailabilitySelected: (AvailabilityData availability) {
                          setState(() {
                            _selectedAvailability = availability;
                          });
                        },
                        labelText: 'Disponibilidad semanal',
                        prefixIcon: Icons.calendar_month,
                        isRequired: false,
                      ),
                      
                      const SizedBox(height: 24),
                      // Register button
                      _isSubmitting
                          ? Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.grey,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    _isUploadingImages 
                                    ? 'Subiendo imagenes...'
                                    : 'Registrando...',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  if (_isUploadingImages && pickedImages.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      '$_uploadedImagesCount de ${pickedImages.length} fotos',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            )
                          : !_canPublish // ✅ Si no puede publicar, mostrar mensaje
                              ? Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.orange.shade300),
                                  ),
                                  child: Column(
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.schedule, color: Colors.orange.shade700),
                                          const SizedBox(width: 8),
                                          const Text(
                                            'Registro Bloqueado',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.orange,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      const Text(
                                        'Ya tienes un artículo pendiente.\nEspera hasta completar el proceso.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.orange,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : MyButton(
                                  onTap: _registerItem,
                                  text: 'Registrar Artículo',
                                  color: Color(0xFF2D8A8A),
                                ),
                    ],
                  ),
                ),
              ),
        ),
    );
  }
}
