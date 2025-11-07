import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:reciclaje_app/database/media_database.dart';
import 'package:reciclaje_app/model/multimedia.dart';
import 'package:reciclaje_app/model/users.dart';
import 'package:reciclaje_app/utils/Fixed43Cropper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditEmployeeProfileScreen extends StatefulWidget {
  final Users user;
  
  const EditEmployeeProfileScreen({super.key, required this.user});

  @override
  State<EditEmployeeProfileScreen> createState() => _EditEmployeeProfileScreenState();
}

class _EditEmployeeProfileScreenState extends State<EditEmployeeProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final mediaDatabase = MediaDatabase();
  final ImagePicker _picker = ImagePicker();
  
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  
  String? _avatarUrl;
  Multimedia? _currentAvatar;
  bool _isUploading = false;
  bool _isSaving = false;

  late String _originalName;
  late String? _originalAvatarUrl;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.names);
    _emailController = TextEditingController(text: widget.user.email);
    
    _originalName = widget.user.names ?? '';
    
    _loadAvatar();
  }

  Future<void> _loadAvatar() async {
    if (widget.user.id == null) return;
    
    try {
      final urlPattern = 'users/${widget.user.id}/avatars/';
      final avatar = await mediaDatabase.getMainPhotoByPattern(urlPattern);
      
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
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 85,
      );

      if (pickedFile == null || !mounted) return;

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
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      print('📸 Processing avatar upload for user: $userId');

      final imageFileObj = File(imageFile.path);
      if (!await imageFileObj.exists()) {
        throw Exception('El archivo de imagen no existe');
      }

      final fileStats = await imageFileObj.stat();
      
      if (fileStats.size == 0) {
        throw Exception('El archivo está vacío (0 bytes)');
      }

      final extension = imageFile.path.split('.').last.toLowerCase();

      if (!['jpg', 'jpeg', 'png'].contains(extension)) {
        throw Exception('Formato de imagen no válido: $extension');
      }

      final fileName = 'avatar_${timestamp}.$extension';
      final filePath = 'users/$userId/avatars/$fileName';

      print('📤 Uploading avatar to: $filePath');

      final bytes = await imageFileObj.readAsBytes();
      
      if (bytes.isEmpty) {
        throw Exception('El archivo está vacío');
      }

      String contentType = 'image/jpeg';
      if (extension == 'png') {
        contentType = 'image/png';
      }

      final storage = Supabase.instance.client.storage;

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

      final publicUrl = storage.from('multimedia').getPublicUrl(filePath);

      if (_currentAvatar != null) {
        print('🗑️ Deleting old avatar from multimedia table...');
        await mediaDatabase.deletePhoto(_currentAvatar!);
      }

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
      );
      
      print('💾 Saving avatar to multimedia table...');
      await mediaDatabase.createPhoto(newMultimedia);
      print('✅ Avatar entry created in multimedia table');

      setState(() {
        _avatarUrl = publicUrl;
        _currentAvatar = newMultimedia;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Foto cargada exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
      }

    } catch (e) {
      print('❌ Error uploading avatar: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar foto: $e'),
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

    bool hasChanges = false;

    if (_nameController.text.trim() != _originalName) hasChanges = true;
    if (_avatarUrl != _originalAvatarUrl) hasChanges = true;

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
      print('💾 Saving profile update...');
      print('   User ID: ${widget.user.id}');
      print('   Name: ${_nameController.text.trim()}');

      await Supabase.instance.client
          .from('users')
          .update({
            'names': _nameController.text.trim(),
            'lastUpdate': DateTime.now().toIso8601String(),
          })
          .eq('idUser', widget.user.id!);

      print('✅ Profile updated successfully in database');

      if (mounted) {
        _originalName = _nameController.text.trim();
        _originalAvatarUrl = _avatarUrl;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Perfil actualizado exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
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
            content: Text('Foto eliminada'),
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
                          backgroundImage: _avatarUrl != null
                              ? NetworkImage(_avatarUrl!)
                              : null,
                          child: _avatarUrl == null
                              ? const Icon(
                                  Icons.person,
                                  size: 80,
                                  color: Color(0xFF2D8A8A),
                                )
                              : null,
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
                  // Employee label
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'EMPLEADO',
                      style: TextStyle(
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
                        prefixIcon: const Icon(Icons.person, color: Color(0xFF2D8A8A)),
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
                      decoration: InputDecoration(
                        labelText: 'Correo electrónico',
                        prefixIcon: const Icon(Icons.email, color: Colors.grey),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey[100],
                      ),
                      enabled: false,
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
