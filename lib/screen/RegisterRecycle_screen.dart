import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:reciclaje_app/auth/auth_service.dart';
import 'package:reciclaje_app/components/my_button.dart';
import 'package:reciclaje_app/components/category_tags.dart';
import 'package:reciclaje_app/components/my_textformfield.dart';
import 'package:reciclaje_app/components/limit_character_two.dart';
import 'package:reciclaje_app/database/article_database.dart';
import 'package:reciclaje_app/database/category_database.dart';
import 'package:reciclaje_app/database/deliver_database.dart';
import 'package:reciclaje_app/database/users_database.dart';
import 'package:reciclaje_app/model/article.dart';
import 'package:reciclaje_app/model/category.dart';
import 'package:reciclaje_app/model/deliver.dart';
import 'package:reciclaje_app/screen/map_picker_screen.dart';

class RegisterRecycleScreen extends StatefulWidget {

  const RegisterRecycleScreen({
    super.key,
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
  
  final articleDatabase = ArticleDatabase();
  final categoryDatabase = CategoryDatabase();
  final deliverDatabase = DeliverDatabase();
  
  List<Category> _categories = [];
  Category? _selectedCategory;
  bool _isLoading = true;
  bool _isSubmitting = false;

  // Location variables
  LatLng? _selectedLocation;
  String? _selectedAddress;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await categoryDatabase.getAllCategories();
      setState(() {
        _categories = categories;
        _selectedCategory = categories.isNotEmpty ? categories.first : null;
        _isLoading = false;
      });
      
      // if (widget.isEdit && widget.existingArticle != null) {

      // }

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
        state: 1
      );

      final deliverID = await deliverDatabase.createDeliver(newDeliver);

      final newArticle = Article(
        name: _itemNameController.text.trim(),
        categoryID: _selectedCategory!.id,
        description: _descriptionController.text.trim().isEmpty 
            ? null 
            : _descriptionController.text.trim(),
        deliverID: deliverID,
        userId: currentUser.id,
        state: 1, // Active state
      );

      await articleDatabase.createArticle(newArticle);

      // Show success message with option to continue or go back
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('¡Artículo registrado exitosamente por ${currentUser.names}!'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
        ),
      );

      // clear form
      _clearForm();

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

  void _clearForm() {
    _itemNameController.clear();
    _descriptionController.clear();
    setState(() {
      _selectedCategory = _categories.isNotEmpty ? _categories.first : null;
      _selectedLocation = null;
      _selectedAddress = null;
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
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        '🌱 Registra un artículo para reciclar',
                        style: TextStyle(
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
                        labelText: 'Categoría',
                        validator: (value) {
                          if (value == null) {
                            return 'Por favor selecciona una categoría';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Description field using LimitCharacterTwo
                      LimitCharacterTwo(
                        controller: _descriptionController,
                        hintText: 'Describe tu artículo (opcional)',
                        text: 'Descripción',
                        obscureText: false,
                        isEnabled: true,
                        isVisible: true,
                      ),
                      const SizedBox(height: 16),

                      // Location picker section
                      const Text(
                        'Preferencia de entrega',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D8A8A),
                        ),
                      ),
                      const SizedBox(height: 8),
                      
                      // Location picker button
                      GestureDetector(
                        onTap: _pickLocation,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: _selectedLocation == null 
                                  ? Colors.grey 
                                  : const Color(0xFF2D8A8A),
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            color: _selectedLocation == null 
                                ? Colors.grey.shade50 
                                : const Color(0xFF2D8A8A).withOpacity(0.1),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.location_on,
                                color: _selectedLocation == null 
                                    ? Colors.grey 
                                    : const Color(0xFF2D8A8A),
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _selectedLocation == null 
                                          ? 'Seleccionar ubicación'
                                          : 'Ubicación seleccionada',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: _selectedLocation == null 
                                            ? Colors.grey.shade600 
                                            : const Color(0xFF2D8A8A),
                                      ),
                                    ),
                                    if (_selectedAddress != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        _selectedAddress!,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        softWrap: true,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Icon(
                                _selectedLocation == null 
                                    ? Icons.add_location_alt 
                                    : Icons.edit_location_alt,
                                color: _selectedLocation == null 
                                    ? Colors.grey 
                                    : const Color(0xFF2D8A8A),
                              ),
                            ],
                          ),
                        ),
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
                              child: const Row(
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
                                    'Registrando...',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
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

  @override
  void dispose() {
    _itemNameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}
