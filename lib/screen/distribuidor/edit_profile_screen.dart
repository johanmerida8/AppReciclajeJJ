import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:reciclaje_app/auth/auth_service.dart';
import 'package:reciclaje_app/database/media_database.dart';
import 'package:reciclaje_app/database/users_database.dart';
import 'package:reciclaje_app/model/multimedia.dart';
import 'package:reciclaje_app/model/users.dart';
import 'package:reciclaje_app/utils/Fixed43Cropper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditProfileScreen extends StatefulWidget {
  final Users user;
  
  const EditProfileScreen({super.key, required this.user});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final authService = AuthService();
  final usersDatabase = UsersDatabase();
  final mediaDatabase = MediaDatabase();
  final ImagePicker _picker = ImagePicker();
  
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  
  String? _avatarUrl;
  Multimedia? _currentAvatar; // Current avatar from multimedia table
  bool _isUploading = false;
  bool _isSaving = false;

  // Store original values for comparison
  late String _originalName;
  late String? _originalAvatarUrl;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.names);
    _emailController = TextEditingController(text: widget.user.email);
    
    // Store original values
    _originalName = widget.user.names ?? '';
    
    // Load avatar from multimedia table
    _loadAvatar();
  }

  Future<void> _loadAvatar() async {
    if (widget.user.id == null) return;
    
    try {
      final userId = widget.user.id!;
      final userRole = widget.user.role?.toLowerCase() ?? 'user';
      
      // ✅ Try new path first (with role)
      String urlPattern = 'users/$userRole/$userId/avatars/';
      Multimedia? avatar = await mediaDatabase.getMainPhotoByPattern(urlPattern);
      
      // ✅ If not found, try old path (without role) for backward compatibility
      if (avatar == null) {
        urlPattern = 'users/$userId/avatars/';
        avatar = await mediaDatabase.getMainPhotoByPattern(urlPattern);
        print('⚠️ Avatar found using old path structure: $urlPattern');
      }
      
      if (mounted) {
        setState(() {
          _currentAvatar = avatar;
          _avatarUrl = avatar?.url;
          _originalAvatarUrl = avatar?.url;
        });
        
        print('✅ Avatar loaded: ${avatar?.url}');
      }
    } catch (e) {
      print('❌ Error loading avatar: $e');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _pickAndCropImage(ImageSource source) async {
    try {
      // Step 1: Pick image
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 85,
      );

      if (pickedFile == null || !mounted) return;

      // Step 2: Show crop dialog
      final shouldCrop = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Recortar imagen'),
          content: const Text('¿Deseas recortar la imagen o usar el original?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Usar original'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Recortar'),
            ),
          ],
        ),
      );

      if (shouldCrop == null || !mounted) return;

      XFile finalImage;

      if (shouldCrop) {
        // Step 3: Crop with Fixed43Cropper (1:1 ratio for profile pictures)
        final croppedFile = await Navigator.push<XFile>(
          context,
          MaterialPageRoute(
            builder: (context) => Fixed43Cropper(file: pickedFile),
          ),
        );

        if (croppedFile == null || !mounted) return;
        finalImage = croppedFile;
      } else {
        finalImage = pickedFile;
      }

      // Step 4: Upload to Supabase
      await _uploadAvatar(finalImage);

    } catch (e) {
      print('❌ Error picking/cropping image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al seleccionar imagen: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _uploadAvatar(XFile imageFile) async {
    if (_isUploading || widget.user.id == null) return;

    setState(() => _isUploading = true);

    try {
      final userId = widget.user.id!;
      final userRole = widget.user.role?.toLowerCase() ?? 'user';
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      print('📸 Processing avatar upload for user: $userId (role: $userRole)');
      print('   Path: ${imageFile.path}');
      print('   Name: ${imageFile.name}');

      // ✅ Verify file exists before processing
      final imageFileObj = File(imageFile.path);
      if (!await imageFileObj.exists()) {
        print('❌ File does not exist: ${imageFile.path}');
        throw Exception('El archivo de imagen no existe');
      }

      // ✅ Verify file is readable and not corrupted
      final fileStats = await imageFileObj.stat();
      print('   File stats:');
      print('     - Size: ${fileStats.size} bytes');
      print('     - Modified: ${fileStats.modified}');
      
      if (fileStats.size == 0) {
        throw Exception('El archivo está vacío (0 bytes)');
      }

      // ✅ Get extension from path (more reliable after cropping)
      final extension = imageFile.path.split('.').last.toLowerCase();

      // Validate file extension
      if (!['jpg', 'jpeg', 'png'].contains(extension)) {
        throw Exception('Formato de imagen no válido: $extension');
      }

      final fileName = 'avatar_${timestamp}.$extension';
      final filePath = 'users/$userRole/$userId/avatars/$fileName';

      print('📤 Uploading avatar to: $filePath');

      // ✅ Read the file as bytes with error handling
      final bytes = await imageFileObj.readAsBytes();
      print('   File size: ${bytes.length} bytes (${(bytes.length / 1024 / 1024).toStringAsFixed(2)} MB)');
      
      if (bytes.isEmpty) {
        throw Exception('El archivo está vacío');
      }

      // ✅ Detect correct content type based on extension
      String contentType = 'image/jpeg';
      if (extension == 'png') {
        contentType = 'image/png';
      } else if (extension == 'jpg' || extension == 'jpeg') {
        contentType = 'image/jpeg';
      }

      final storage = Supabase.instance.client.storage;

      // ✅ Verify bucket exists and is accessible
      try {
        print('🔍 Verificando bucket multimedia...');
        await storage.from('multimedia').list(
          path: '',
          searchOptions: const SearchOptions(limit: 1),
        );
        print('✅ Bucket multimedia accesible');
      } catch (e) {
        print('⚠️ Advertencia: No se pudo verificar el bucket: $e');
      }

      // Upload to Supabase Storage with timeout and retry logic
      try {
        print('⏳ Iniciando subida de avatar con timeout de 60s...');
        print('   Bucket destino: multimedia');
        print('   Ruta destino: $filePath');
        print('   Tamaño archivo: ${(bytes.length / 1024 / 1024).toStringAsFixed(2)} MB');
        
        await storage
            .from('multimedia')
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
              const Duration(seconds: 60),
              onTimeout: () {
                throw Exception('Timeout de subida - tardó más de 60 segundos');
              },
            );

        print('✅ Avatar subido exitosamente');
      } catch (uploadError) {
        print('❌ Upload error details:');
        print('   Error type: ${uploadError.runtimeType}');
        print('   Error message: $uploadError');
        
        final errorMessage = uploadError.toString().toLowerCase();
        
        if (errorMessage.contains('timeout')) {
          throw Exception('⏰ La imagen tardó demasiado en subir (>60s). Intenta con una imagen más pequeña.');
        } else if (errorMessage.contains('clientexception') || 
                   errorMessage.contains('socketexception') ||
                   errorMessage.contains('read failed')) {
          throw Exception('🌐 Error de conexión al subir imagen.\n'
                          'Verifica:\n'
                          '• Conexión a internet estable\n'
                          '• URL de Supabase correcta\n'
                          '• Bucket configurado correctamente');
        } else if (errorMessage.contains('413') || errorMessage.contains('too large')) {
          throw Exception('📏 Imagen demasiado grande: ${(bytes.length / 1024 / 1024).toStringAsFixed(2)} MB');
        } else if (errorMessage.contains('401') || errorMessage.contains('403') || 
                   errorMessage.contains('unauthorized') || errorMessage.contains('forbidden')) {
          throw Exception('🔒 Sin permisos para subir imagen. Verifica las políticas RLS del bucket.');
        } else if (errorMessage.contains('404') || errorMessage.contains('not found')) {
          throw Exception('🗂️ Bucket "multimedia" no encontrado. Verifica la configuración de Supabase Storage.');
        } else {
          throw Exception('❌ Error desconocido al subir imagen: $uploadError');
        }
      }

      // Get public URL
      final publicUrl = storage.from('multimedia').getPublicUrl(filePath);
      
      print('🔗 Public URL: $publicUrl');

      // ✅ Delete old avatar from multimedia table if exists
      if (_currentAvatar != null) {
        print('🗑️ Deleting old avatar from multimedia table...');
        await mediaDatabase.deletePhoto(_currentAvatar!);
      }

      // ✅ Create entry in multimedia table
      final fileSize = bytes.length;
      final mimeType = contentType;
      
      final newMultimedia = Multimedia(
        url: publicUrl,
        fileName: fileName,
        filePath: filePath,
        fileSize: fileSize,
        mimeType: mimeType,
        isMain: true,
        uploadOrder: 1,
        entityType: userRole, // ✅ Entity type is 'user' for user avatars
        entityId: userId,   // ✅ Entity ID is the user's ID
      );
      
      print('💾 Saving avatar to multimedia table...');
      await mediaDatabase.createPhoto(newMultimedia);
      print('✅ Avatar entry created in multimedia table');

      // Update local state
      setState(() {
        _avatarUrl = publicUrl;
        _currentAvatar = newMultimedia;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Imagen cargada exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
      }

      print('✅ Avatar subido exitosamente');
      print('   Archivo: $fileName');
      print('   Tamaño: ${(bytes.length / 1024 / 1024).toStringAsFixed(2)} MB');
      print('   URL pública: $publicUrl');

    } catch (e) {
      print('❌ Error uploading avatar: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar imagen: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate() || _isSaving) return;

    // Check for changes
    bool hasChanges = false;

    // Check if name changed
    if (_nameController.text.trim() != _originalName) hasChanges = true;

    // Check if avatar changed
    if (_avatarUrl != _originalAvatarUrl) hasChanges = true;

    // If no changes, show message and return
    if (!hasChanges) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay cambios para actualizar'),
          backgroundColor: Colors.amber,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Update user in database (only name and email)
      final updatedUser = Users(
        id: widget.user.id,
        names: _nameController.text.trim(),
        email: _emailController.text.trim(),
        role: widget.user.role,
        state: widget.user.state,
        lastUpdate: DateTime.now(),
      );

      print('💾 Saving profile update...');
      print('   User ID: ${widget.user.id}');
      print('   Name: ${updatedUser.names}');

      // Update in Supabase (only user fields, avatar is in multimedia table)
      await Supabase.instance.client
          .from('users')
          .update({
            'names': updatedUser.names,
            'email': updatedUser.email,
            'lastUpdate': updatedUser.lastUpdate?.toIso8601String(),
          })
          .eq('idUser', widget.user.id!);

      print('✅ Profile updated successfully in database');

      if (mounted) {
        // Update original values after successful save
        _originalName = _nameController.text.trim();
        _originalAvatarUrl = _avatarUrl;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Perfil actualizado exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // Return true to indicate success
      }
    } catch (e) {
      print('❌ Error saving profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar perfil: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFF2D8A8A)),
              title: const Text('Tomar foto'),
              onTap: () {
                Navigator.pop(context);
                _pickAndCropImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Color(0xFF2D8A8A)),
              title: const Text('Galería'),
              onTap: () {
                Navigator.pop(context);
                _pickAndCropImage(ImageSource.gallery);
              },
            ),
            if (_avatarUrl != null)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text(
                  'Eliminar foto',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _removeAvatar();
                },
              ),
          ],
        ),
      ),
    );
  }

  void _removeAvatar() async {
    try {
      if (_currentAvatar != null) {
        print('🗑️ Deleting avatar from multimedia table...');
        await mediaDatabase.deletePhoto(_currentAvatar!);
        print('✅ Avatar deleted successfully');
      }
      
      setState(() {
        _avatarUrl = null;
        _currentAvatar = null;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Foto de perfil eliminada'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      print('❌ Error deleting avatar: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al eliminar foto: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF2D8A8A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Editar Perfil',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_isSaving)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _saveProfile,
              child: const Text(
                'Guardar',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header section with avatar
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(25, 30, 25, 40),
              decoration: const BoxDecoration(
                color: Color(0xFF2D8A8A),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Column(
                children: [
                  // Avatar with edit button
                  Stack(
                    children: [
                      // Avatar circle
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                        ),
                        child: CircleAvatar(
                          radius: 70,
                          backgroundColor: Colors.white,
                          child: _avatarUrl != null
                              ? ClipOval(
                                  child: CachedNetworkImage(
                                    imageUrl: _avatarUrl!,
                                    width: 140,
                                    height: 140,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => const Center(
                                      child: CircularProgressIndicator(
                                        color: Color(0xFF2D8A8A),
                                        strokeWidth: 3,
                                      ),
                                    ),
                                    errorWidget: (context, url, error) => const Icon(
                                      Icons.person,
                                      size: 80,
                                      color: Color(0xFF2D8A8A),
                                    ),
                                  ),
                                )
                              : const Icon(
                                  Icons.person,
                                  size: 80,
                                  color: Color(0xFF2D8A8A),
                                ),
                        ),
                      ),
                      // Loading overlay
                      if (_isUploading)
                        Positioned.fill(
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.black45,
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: CircularProgressIndicator(
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      // Edit button
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _isUploading ? null : _showImageSourceDialog,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              color: Color(0xFF2D8A8A),
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // User role
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      widget.user.role?.toLowerCase() == 'distribuidor'
                          ? 'Distribuidor'
                          : widget.user.role?.toUpperCase() ?? 'USUARIO',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Form section
            Padding(
              padding: const EdgeInsets.all(25.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Información Personal',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D8A8A),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Name field
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Nombre completo',
                        prefixIcon: const Icon(Icons.person_outline, color: Color(0xFF2D8A8A)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF2D8A8A), width: 2),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Por favor ingresa tu nombre';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    // Email field (read-only)
                    TextFormField(
                      controller: _emailController,
                      enabled: false,
                      decoration: InputDecoration(
                        labelText: 'Correo electrónico',
                        prefixIcon: const Icon(Icons.email_outlined, color: Colors.grey),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey[100],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'El correo electrónico no se puede modificar',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 30),
                    // Info card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue[700]),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Los cambios se guardarán cuando presiones "Guardar"',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.blue[900],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


