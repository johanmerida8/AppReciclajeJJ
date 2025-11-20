import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:reciclaje_app/database/media_database.dart';
import 'package:reciclaje_app/model/company.dart';
import 'package:reciclaje_app/model/multimedia.dart';
import 'package:reciclaje_app/model/users.dart';
import 'package:reciclaje_app/utils/Fixed43Cropper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditCompanyProfileScreen extends StatefulWidget {
  final Company? company;
  final Users? adminUser;
  final bool isEditingCompany; // true = company logo, false = admin avatar
  
  const EditCompanyProfileScreen({
    super.key,
    this.company,
    this.adminUser,
    required this.isEditingCompany,
  });

  @override
  State<EditCompanyProfileScreen> createState() => _EditCompanyProfileScreenState();
}

class _EditCompanyProfileScreenState extends State<EditCompanyProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final mediaDatabase = MediaDatabase();
  final ImagePicker _picker = ImagePicker();
  
  late TextEditingController _companyNameController;
  
  String? _logoUrl;
  Multimedia? _currentLogo; // Current logo from multimedia table
  bool _isUploading = false;
  bool _isSaving = false;

  // Store original values for comparison
  late String _originalName;
  late String? _originalLogoUrl;

  @override
  void initState() {
    super.initState();
    
    // Initialize controller based on profile type
    if (widget.isEditingCompany) {
      _companyNameController = TextEditingController(text: widget.company?.nameCompany);
      _originalName = widget.company?.nameCompany ?? '';
    } else {
      _companyNameController = TextEditingController(text: widget.adminUser?.names);
      _originalName = widget.adminUser?.names ?? '';
    }
    
    // Load avatar/logo from multimedia table
    _loadLogo();
  }

  Future<void> _loadLogo() async {
    try {
      String? pattern;
      
      if (widget.isEditingCompany) {
        // Load company logo
        if (widget.company?.companyId == null) return;
        final companyId = widget.company!.companyId!;
        // Use only companyId pattern to avoid issues with special characters
        pattern = 'empresa/$companyId/avatar/';
        print('📂 Loading company logo with pattern: $pattern');
      } else {
        // Load admin user avatar
        if (widget.adminUser?.id == null) return;
        final userRole = widget.adminUser!.role?.toLowerCase() ?? 'user';
        final userId = widget.adminUser!.id!;
        pattern = 'users/$userRole/$userId/avatars/';
        print('📂 Loading admin avatar with pattern: $pattern');
      }
      
      final logo = await mediaDatabase.getMainPhotoByPattern(pattern);
      
      if (mounted) {
        setState(() {
          _currentLogo = logo;
          _logoUrl = logo?.url;
          _originalLogoUrl = logo?.url;
        });
        
        print('✅ ${widget.isEditingCompany ? "Company logo" : "Admin avatar"} loaded: ${logo?.url}');
      }
    } catch (e) {
      print('❌ Error loading ${widget.isEditingCompany ? "company logo" : "admin avatar"}: $e');
    }
  }

  @override
  void dispose() {
    _companyNameController.dispose();
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

      // Step 3: Upload to Supabase
      await _uploadLogo(finalImage);

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

  Future<void> _uploadLogo(XFile imageFile) async {
    if (_isUploading) return;
    
    // Validate entity exists
    if (widget.isEditingCompany && widget.company?.companyId == null) return;
    if (!widget.isEditingCompany && widget.adminUser?.id == null) return;

    setState(() => _isUploading = true);

    try {
      // Get file extension early
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

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      String filePath;
      String entityType;
      int entityId;
      String fileName;
      
      if (widget.isEditingCompany) {
        // Upload company logo
        final companyId = widget.company!.companyId!;
        // final companyName = widget.company!.nameCompany!;
        print('🏢 Processing company logo upload for company: $companyId');
        
        fileName = 'logo_${timestamp}.$extension';
        filePath = 'empresa/$companyId/avatar/$fileName';
        entityType = 'empresa';
        entityId = companyId;
      } else {
        // Upload admin user avatar
        final userId = widget.adminUser!.id!;
        final userRole = widget.adminUser!.role?.toLowerCase() ?? 'user';
        print('👤 Processing admin avatar upload for user: $userId (role: $userRole)');
        
        fileName = 'avatar_${timestamp}.$extension';
        filePath = 'users/$userRole/$userId/avatars/$fileName';
        entityType = userRole;
        entityId = userId;
      }

      print('📤 Uploading to: $filePath');

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

      // Delete old logo/avatar from multimedia table if exists
      if (_currentLogo != null) {
        print('🗑️ Deleting old ${widget.isEditingCompany ? "logo" : "avatar"} from multimedia table...');
        await mediaDatabase.deletePhoto(_currentLogo!);
      }

      // Create entry in multimedia table
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
        entityType: entityType,
        entityId: entityId,
      );
      
      print('💾 Saving ${widget.isEditingCompany ? "logo" : "avatar"} to multimedia table...');
      await mediaDatabase.createPhoto(newMultimedia);
      print('✅ ${widget.isEditingCompany ? "Logo" : "Avatar"} entry created in multimedia table');

      setState(() {
        _logoUrl = publicUrl;
        _currentLogo = newMultimedia;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.isEditingCompany ? 'Logo cargado exitosamente' : 'Foto cargada exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
      }

    } catch (e) {
      print('❌ Error uploading ${widget.isEditingCompany ? "logo" : "avatar"}: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar ${widget.isEditingCompany ? "logo" : "imagen"}: $e'),
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

    if (_companyNameController.text.trim() != _originalName) hasChanges = true;
    if (_logoUrl != _originalLogoUrl) hasChanges = true;

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
      if (widget.isEditingCompany) {
        // Update company
        final companyId = widget.company?.companyId;
        if (companyId == null) {
          throw Exception('Company ID is null');
        }
        
        print('💾 Saving company profile update...');
        print('   Company ID: $companyId');
        print('   Company Name: ${_companyNameController.text.trim()}');

        // Update in Supabase
        await Supabase.instance.client
            .from('company')
            .update({
              'nameCompany': _companyNameController.text.trim(),
            })
            .eq('idCompany', companyId);

        print('✅ Company profile updated successfully in database');
      } else {
        // Update admin user
        final userId = widget.adminUser?.id;
        if (userId == null) {
          throw Exception('User ID is null');
        }
        
        print('💾 Saving admin user profile update...');
        print('   User ID: $userId');
        print('   User Name: ${_companyNameController.text.trim()}');

        // Update in Supabase
        await Supabase.instance.client
            .from('users')
            .update({
              'names': _companyNameController.text.trim(),
            })
            .eq('id', userId);

        print('✅ Admin user profile updated successfully in database');
      }

      if (mounted) {
        _originalName = _companyNameController.text.trim();
        _originalLogoUrl = _logoUrl;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.isEditingCompany 
              ? 'Perfil de empresa actualizado exitosamente' 
              : 'Perfil actualizado exitosamente'),
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
            if (_logoUrl != null)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: Text(
                  widget.isEditingCompany ? 'Eliminar logo' : 'Eliminar foto',
                  style: const TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _removeLogo();
                },
              ),
          ],
        ),
      ),
    );
  }

  void _removeLogo() async {
    try {
      if (_currentLogo != null) {
        print('🗑️ Deleting company logo from multimedia table...');
        await mediaDatabase.deletePhoto(_currentLogo!);
        print('✅ Company logo deleted successfully');
      }
      
      setState(() {
        _logoUrl = null;
        _currentLogo = null;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.isEditingCompany 
              ? 'Logo de empresa eliminado' 
              : 'Foto de perfil eliminada'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      print('❌ Error deleting ${widget.isEditingCompany ? "logo" : "avatar"}: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al eliminar ${widget.isEditingCompany ? "logo" : "foto"}: $e'),
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
        title: Text(
          widget.isEditingCompany 
            ? 'Editar Perfil de Empresa' 
            : 'Editar Perfil',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
            // Header section with logo
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
                  // Logo with edit button
                  Stack(
                    children: [
                      // Logo circle
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                        ),
                        child: CircleAvatar(
                          radius: 70,
                          backgroundColor: Colors.white,
                          backgroundImage: _logoUrl != null
                              ? NetworkImage(_logoUrl!)
                              : null,
                          child: _logoUrl == null
                              ? Icon(
                                  widget.isEditingCompany ? Icons.business : Icons.person,
                                  size: 80,
                                  color: const Color(0xFF2D8A8A),
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
                  // Entity label (EMPRESA or ADMINISTRADOR)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      widget.isEditingCompany ? 'EMPRESA' : 'ADMINISTRADOR',
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
                    Text(
                      widget.isEditingCompany 
                        ? 'Información de la Empresa' 
                        : 'Información Personal',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D8A8A),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Name field (company or personal)
                    TextFormField(
                      controller: _companyNameController,
                      decoration: InputDecoration(
                        labelText: widget.isEditingCompany 
                          ? 'Nombre de la empresa' 
                          : 'Nombre completo',
                        prefixIcon: Icon(
                          widget.isEditingCompany ? Icons.business : Icons.person, 
                          color: const Color(0xFF2D8A8A)
                        ),
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
                          return widget.isEditingCompany 
                            ? 'Por favor ingresa el nombre de la empresa'
                            : 'Por favor ingresa tu nombre completo';
                        }
                        return null;
                      },
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
