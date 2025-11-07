import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:reciclaje_app/database/media_database.dart';
import 'package:reciclaje_app/model/company.dart';
import 'package:reciclaje_app/model/multimedia.dart';
import 'package:reciclaje_app/utils/Fixed43Cropper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditCompanyProfileScreen extends StatefulWidget {
  final Company company;
  
  const EditCompanyProfileScreen({super.key, required this.company});

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
    _companyNameController = TextEditingController(text: widget.company.nameCompany);
    
    // Store original values
    _originalName = widget.company.nameCompany ?? '';
    
    // Load logo from multimedia table
    _loadLogo();
  }

  Future<void> _loadLogo() async {
    if (widget.company.companyId == null) return;
    
    try {
      final logoPattern = 'empresa/${widget.company.companyId}/avatar/';
      final logo = await mediaDatabase.getMainPhotoByPattern(logoPattern);
      
      if (mounted) {
        setState(() {
          _currentLogo = logo;
          _logoUrl = logo?.url;
          _originalLogoUrl = logo?.url;
        });
        
        print('✅ Company logo loaded: ${logo?.url}');
      }
    } catch (e) {
      print('❌ Error loading company logo: $e');
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
    if (_isUploading || widget.company.companyId == null) return;

    setState(() => _isUploading = true);

    try {
      final companyId = widget.company.companyId!;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      print('🏢 Processing company logo upload for company: $companyId');

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

      final fileName = 'logo_${timestamp}.$extension';
      final filePath = 'empresa/$companyId/avatar/$fileName';

      print('📤 Uploading company logo to: $filePath');

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

      // Delete old logo from multimedia table if exists
      if (_currentLogo != null) {
        print('🗑️ Deleting old company logo from multimedia table...');
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
      );
      
      print('💾 Saving company logo to multimedia table...');
      await mediaDatabase.createPhoto(newMultimedia);
      print('✅ Company logo entry created in multimedia table');

      setState(() {
        _logoUrl = publicUrl;
        _currentLogo = newMultimedia;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Logo cargado exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
      }

    } catch (e) {
      print('❌ Error uploading company logo: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar logo: $e'),
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
      print('💾 Saving company profile update...');
      print('   Company ID: ${widget.company.companyId}');
      print('   Company Name: ${_companyNameController.text.trim()}');

      // Update in Supabase
      await Supabase.instance.client
          .from('company')
          .update({
            'nameCompany': _companyNameController.text.trim(),
          })
          .eq('idCompany', widget.company.companyId!);

      print('✅ Company profile updated successfully in database');

      if (mounted) {
        _originalName = _companyNameController.text.trim();
        _originalLogoUrl = _logoUrl;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Perfil de empresa actualizado exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      print('❌ Error saving company profile: $e');
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
                title: const Text(
                  'Eliminar logo',
                  style: TextStyle(color: Colors.red),
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
          const SnackBar(
            content: Text('Logo de empresa eliminado'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      print('❌ Error deleting company logo: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al eliminar logo: $e'),
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
          'Editar Perfil de Empresa',
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
                              ? const Icon(
                                  Icons.business,
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
                  // Company label
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'EMPRESA',
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
                      'Información de la Empresa',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D8A8A),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Company name field
                    TextFormField(
                      controller: _companyNameController,
                      decoration: InputDecoration(
                        labelText: 'Nombre de la empresa',
                        prefixIcon: const Icon(Icons.business, color: Color(0xFF2D8A8A)),
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
                          return 'Por favor ingresa el nombre de la empresa';
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
