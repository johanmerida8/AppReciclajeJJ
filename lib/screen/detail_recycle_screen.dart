import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:reciclaje_app/auth/auth_service.dart';
import 'package:reciclaje_app/screen/home_screen.dart';
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
import 'package:reciclaje_app/screen/map_picker_screen.dart';
import 'package:reciclaje_app/screen/navigation_screens.dart';

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

  final _authService = AuthService();
  String? _currentUserEmail;
  
  List<Category> _categories = [];
  Category? _selectedCategory;
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _isEditing = false;
  
  // Location variables
  LatLng? _selectedLocation;
  String? _selectedAddress;
  
  // Original data for comparison
  late String _originalTitle;
  late String _originalDescription;
  late String _originalCategoryName;
  late String _originalAddress;
  late LatLng _originalLocation;

  @override
  void initState() {
    super.initState();
    _initializeData();
    _loadCategories();

    _currentUserEmail = _authService.getCurrentUserEmail();
  }

  bool get _isOwner => widget.item.userEmail == _currentUserEmail;
  

  void _initializeData() {
    // Store original data
    _originalTitle = widget.item.title;
    _originalDescription = widget.item.description ?? '';
    _originalCategoryName = widget.item.categoryName;
    _originalAddress = widget.item.address;
    _originalLocation = LatLng(widget.item.latitude, widget.item.longitude);
    
    // Initialize controllers with current data
    _itemNameController.text = widget.item.title;
    _descriptionController.text = widget.item.description ?? '';
    _selectedLocation = LatLng(widget.item.latitude, widget.item.longitude);
    _selectedAddress = widget.item.address;

    // initializar el categoria seleccionado con el articulo actual
    _selectedCategory = Category(
      id: widget.item.categoryID ?? 0,
      name: widget.item.categoryName,
    );
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

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'plástico':
      case 'plasticos':
        return Colors.blue;
      case 'papel':
      case 'papel y cartón':
        return Colors.brown;
      case 'vidrio':
        return Colors.green;
      case 'metal':
      case 'metales':
        return Colors.grey;
      case 'electrónicos':
        return Colors.purple;
      case 'orgánicos':
        return Colors.orange;
      default:
        return const Color(0xFF2D8A8A);
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'plástico':
      case 'plasticos':
        return Icons.local_drink;
      case 'papel':
      case 'papel y cartón':
        return Icons.description;
      case 'vidrio':
        return Icons.wine_bar;
      case 'metal':
      case 'metales':
        return Icons.build;
      case 'electrónicos':
        return Icons.devices;
      case 'orgánicos':
        return Icons.eco;
      default:
        return Icons.recycling;
    }
  }

  Future<void> _pickLocation() async {
    try {
      final res = await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => MapPickerScreen(
            initialLocation: _selectedLocation ?? _originalLocation,
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

  Deliver? updatedDeliver;

  Future<void> _saveChanges() async {
    // if (!_formKey.currentState!.validate()) {
    //   return;
    // }

    bool hasChanges = false;

    if (_itemNameController.text.trim() != _originalTitle) hasChanges = true;
    if (_descriptionController.text.trim() != _originalDescription) hasChanges = true;
    if (_selectedCategory?.name != _originalCategoryName) hasChanges = true;
    if (_selectedAddress != _originalAddress) hasChanges = true;
    if (_selectedLocation != _originalLocation) hasChanges = true;

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
      // Update deliver if location or address changed
      if (_selectedLocation != _originalLocation || 
          _selectedAddress != _originalAddress) {
        Deliver updatedDeliver = Deliver(
          id: widget.item.id, // Assuming same ID structure
          address: _selectedAddress ?? 'Ubicación no especificada',
          lat: _selectedLocation!.latitude,
          lng: _selectedLocation!.longitude,
          state: 1,
        );

        await deliverDatabase.updateDeliver(updatedDeliver);
      }

      // Update article
      Article updatedArticle = Article(
        id: widget.item.id,
        name: _itemNameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty 
            ? null 
            : _descriptionController.text.trim(),
        categoryID: _selectedCategory!.id,
        deliverID: updatedDeliver?.id ?? widget.item.deliverID,
        userId: widget.item.ownerUserId,
        state: 1,
      );

      await articleDatabase.updateArticle(updatedArticle);


      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Artículo actualizado correctamente'),
          backgroundColor: Colors.green,
        ),
      );

      setState(() {
        _isEditing = false;
        _isSubmitting = false;
      });

      // Update original values
      _originalTitle = _itemNameController.text.trim();
      _originalDescription = _descriptionController.text.trim();
      _originalCategoryName = _selectedCategory!.name!;
      _originalAddress = _selectedAddress!;
      _originalLocation = _selectedLocation!;

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
        actions: [
          if (_isOwner && !_isEditing && !_isSubmitting)
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'edit':
                    setState(() {
                      _isEditing = true;
                    });
                    break;
                  case 'delete':
                    _deleteArticle();
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, color: Colors.blue),
                      SizedBox(width: 8),
                      Text('Editar'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Eliminar'),
                    ],
                  ),
                ),
              ],
            ),
        ],
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
              // Header with category badge
              if (!_isEditing) ...[
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: _getCategoryColor(widget.item.categoryName),
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getCategoryIcon(widget.item.categoryName),
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          widget.item.categoryName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],

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
                obscureText: false,
                isEnabled: _isEditing,
                prefixIcon: const Icon(Icons.recycling),
              ),
              const SizedBox(height: 16),

              // Category tags - only show in edit mode
              if (_isEditing)
                CategoryTags(
                  categories: _categories,
                  selectedCategory: _selectedCategory,
                  onCategorySelected: (category) {
                    setState(() {
                      _selectedCategory = category;
                    });
                  },
                  labelText: 'Categoría',
                ),
              if (_isEditing) const SizedBox(height: 16),

              // Description field
              LimitCharacterTwo(
                controller: _descriptionController,
                hintText: 'Describe tu artículo (opcional)',
                text: 'Descripción',
                obscureText: false,
                isEnabled: _isEditing,
                isVisible: true,
              ),
              const SizedBox(height: 16),

              // Location section
              Text(
                _isEditing ? 'Preferencia de entrega' : 'Ubicación de entrega',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D8A8A),
                ),
              ),
              const SizedBox(height: 8),

              // Location display/picker
              GestureDetector(
                onTap: _isEditing ? _pickLocation : null,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: _isEditing 
                          ? const Color(0xFF2D8A8A)
                          : Colors.grey.shade300,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    color: _isEditing 
                        ? const Color(0xFF2D8A8A).withOpacity(0.1)
                        : Colors.white,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            color: _isEditing 
                                ? const Color(0xFF2D8A8A)
                                : Colors.grey.shade600,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _selectedAddress ?? widget.item.address,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: _isEditing 
                                    ? const Color(0xFF2D8A8A)
                                    : Colors.grey.shade800,
                              ),
                            ),
                          ),
                          if (_isEditing)
                            const Icon(
                              Icons.edit_location_alt,
                              color: Color(0xFF2D8A8A),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.my_location, size: 16, color: Colors.grey),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Lat: ${_selectedLocation?.latitude.toStringAsFixed(6) ?? widget.item.latitude.toStringAsFixed(6)}, '
                              'Lng: ${_selectedLocation?.longitude.toStringAsFixed(6) ?? widget.item.longitude.toStringAsFixed(6)}',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 11,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                          if (!_isEditing)
                            IconButton(
                              onPressed: () {
                                Clipboard.setData(
                                  ClipboardData(
                                    text: '${widget.item.latitude}, ${widget.item.longitude}',
                                  ),
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Coordenadas copiadas'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.copy, size: 16),
                              tooltip: 'Copiar coordenadas',
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
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
                      onTap: () {
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