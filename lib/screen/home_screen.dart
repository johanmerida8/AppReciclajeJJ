import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:reciclaje_app/auth/auth_service.dart';
// import 'package:reciclaje_app/components/location_input.dart';
import 'package:reciclaje_app/database/article_database.dart';
import 'package:reciclaje_app/database/category_database.dart';
import 'package:reciclaje_app/database/deliver_database.dart';
import 'package:reciclaje_app/database/users_database.dart';
import 'package:reciclaje_app/model/article.dart';
import 'package:reciclaje_app/model/category.dart';
import 'package:reciclaje_app/model/users.dart';
import 'package:reciclaje_app/screen/detail_recycle_screen.dart';

class RecyclingItem {
  final int id;
  final String title;
  final int? deliverID;
  final String? description;
  final int? categoryID;
  final String categoryName;
  final int? ownerUserId;
  final String userName;
  final String userEmail;
  final double latitude;
  final double longitude;
  final String address;
  final DateTime createdAt;

  RecyclingItem({
    required this.id,
    required this.title,
    this.deliverID,
    this.description,
    this.categoryID,
    required this.categoryName,
    required this.ownerUserId,
    required this.userName,
    required this.userEmail,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.createdAt,
  });
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final authService = AuthService();
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();

  final articleDatabase = ArticleDatabase();
  final categoryDatabase = CategoryDatabase();
  final deliverDatabase = DeliverDatabase();
  final userDatabase = UsersDatabase();
  
  final LatLng _centerLocation = const LatLng(-17.3895, -66.1568);

  LatLng? _pickedLocation;
  
  String _selectedCategory = 'Todos';
  String _searchQuery = '';
  
  List<RecyclingItem> _recyclingItems = [];
  List<String> _categories = ['Todos'];
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  

  Future<void> _loadData() async {
    print('Loading data...');
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      // load categories first
      final categories = await categoryDatabase.getAllCategories();
      final categoryNames = categories.map((c) => c.name!).toList();

      // load articles with their related data
      final articles = await articleDatabase.getAllArticles();

      List<RecyclingItem> items = [];

      for (Article article in articles) {
        if (article.state == 1 && article.id != null && article.name != null && article.deliverID != null) {
          try {
            Category? category;
            try {
              category = categories.firstWhere((c) => c.id == article.categoryID);
            } catch (e) {
              print('Category not found for article ${article.id}: $e');
              category = Category(id: 0, name: 'Sin categoria');
            }

            final deliver = await deliverDatabase.getDeliverById(article.deliverID!);
            if (deliver == null || deliver.lat == null || deliver.lng == null || deliver.address == null) {
              print('Skipping article ${article.id}: Invalid deliver data');
              continue;
            }

            Users? user;
            if (article.userId != null) {
              user = await userDatabase.getUserById(article.userId!);
            }

            String userName = user?.names ?? 'Usuario desconocido';
            String userEmail = user?.email ?? 'Email no disponible';

            items.add(RecyclingItem(
              id: article.id!, 
              title: article.name!, 
              deliverID: article.deliverID,
              description: article.description,
              categoryID: article.categoryID,
              categoryName: category.name ?? 'Sin categoria', 
              ownerUserId: article.userId,
              userName: userName, 
              userEmail: userEmail, 
              latitude: deliver.lat!, 
              longitude: deliver.lng!, 
              address: deliver.address!, 
              createdAt: DateTime.now(),
            ));
          } catch (e) {
            print('Error processing article ${article.id}: $e');
          }
        }
      }

      setState(() {
        _recyclingItems = items;
        _categories = ['Todos', ...categoryNames];
        _isLoading = false;
        _hasError = false;
      });

      print('Successfully loaded ${items.length} articles');
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = 'Error al cargar datos: $e';
        _isLoading = false;
      });
      print('Error loading data: $e');
    }
  }

  String _normalizeText(String text) {
    return text
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ñ', 'n')
        .trim();
  }

  List<RecyclingItem> get _filteredItems {
    List<RecyclingItem> items = _recyclingItems;
    
    // Filter by category
    if (_selectedCategory != 'Todos') {
      items = items.where((item) => item.categoryName == _selectedCategory).toList();
    }
    
    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      final normalizedQuery = _normalizeText(_searchQuery);
      
      items = items.where((item) {
        final normalizedTitle = _normalizeText(item.title);
        final normalizedDescription = _normalizeText(item.description ?? '');
        final normalizedCategory = _normalizeText(item.categoryName);
        final normalizedUserName = _normalizeText(item.userName);
        final normalizedAddress = _normalizeText(item.address);
        
        return normalizedTitle.contains(normalizedQuery) ||
              normalizedDescription.contains(normalizedQuery) ||
              normalizedCategory.contains(normalizedQuery) ||
              normalizedUserName.contains(normalizedQuery) ||
              normalizedAddress.contains(normalizedQuery);
      }).toList();
    }
    
    return items;
  }

  int _getCategoryCount(String category) {
    if (category == 'Todos') {
      if (_searchQuery.isEmpty) {
        return _recyclingItems.length;
      } else {
        final normalizedQuery = _normalizeText(_searchQuery);
        return _recyclingItems.where((item) {
          final normalizedTitle = _normalizeText(item.title);
          final normalizedDescription = _normalizeText(item.description ?? '');
          final normalizedCategory = _normalizeText(item.categoryName);
          final normalizedUserName = _normalizeText(item.userName);
          final normalizedAddress = _normalizeText(item.address);
          
          return normalizedTitle.contains(normalizedQuery) ||
                normalizedDescription.contains(normalizedQuery) ||
                normalizedCategory.contains(normalizedQuery) ||
                normalizedUserName.contains(normalizedQuery) ||
                normalizedAddress.contains(normalizedQuery);
        }).length;
      }
    } else {
      return _recyclingItems.where((item) {
        bool matchesCategory = item.categoryName == category;
        bool matchesSearch = _searchQuery.isEmpty;
        
        if (!matchesSearch) {
          final normalizedQuery = _normalizeText(_searchQuery);
          final normalizedTitle = _normalizeText(item.title);
          final normalizedDescription = _normalizeText(item.description ?? '');
          final normalizedCategory = _normalizeText(item.categoryName);
          final normalizedUserName = _normalizeText(item.userName);
          final normalizedAddress = _normalizeText(item.address);
          
          matchesSearch = normalizedTitle.contains(normalizedQuery) ||
                        normalizedDescription.contains(normalizedQuery) ||
                        normalizedCategory.contains(normalizedQuery) ||
                        normalizedUserName.contains(normalizedQuery) ||
                        normalizedAddress.contains(normalizedQuery);
        }
        
        return matchesCategory && matchesSearch;
      }).length;
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
  }

  void _clearSearch() {
    setState(() {
      _searchQuery = '';
      _searchController.clear();
    });
  }

  Future<void> _refreshData() async {
    await _loadData();
  }

  @override
  void initState() {
    super.initState();
    print('HomeScreen initState called!');
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'plástico':
        return Colors.blue;
      case 'papel':
        return Colors.brown;
      case 'vidrio':
        return Colors.green;
      case 'metal':
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
        return Icons.local_drink;
      case 'papel':
        return Icons.description;
      case 'vidrio':
        return Icons.wine_bar;
      case 'metal':
        return Icons.build;
      case 'electrónicos':
        return Icons.devices;
      case 'orgánicos':
        return Icons.eco;
      default:
        return Icons.recycling;
    }
  }

  void _showItemDetails(RecyclingItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      sheetAnimationStyle: AnimationStyle(
        duration: Duration(milliseconds: 800),
        reverseDuration: Duration(milliseconds: 500),
        curve: Curves.easeInOut,
        reverseCurve: Curves.easeOut,
      ),
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.30, // smaller height
        decoration: const BoxDecoration(
          color: Color(0xFF2D8A8A),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 50,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left icon / placeholder
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.image, color: Colors.grey),
                  ),
                  const SizedBox(width: 12),

                  // Column with title, address and button → Expanded so it doesn't overflow
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            // const Icon(Icons.location_on,
                            //     size: 14, color: Color(0xFF2D8A8A)),
                            // const SizedBox(width: 4),
                            Expanded( // ✅ add Expanded here too for long addresses
                              child: Text(
                                item.address.trim(),
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.white70,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                softWrap: true,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => DetailRecycleScreen(item: item),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF05AABC),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Ver detalles',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
             
            ],
          ),
        ),
      ),
    );
  }


  void _onLocationSelected(double lat, double lng, {bool fromMap = false}) {
    // handle the selected location here
    print('Location selected: Lat $lat, Lng $lng, From map: $fromMap');

    // update the user location
    setState(() {
      _pickedLocation = LatLng(lat, lng);
    });

    // you can update the map center or add a marker here
    _mapController.move(LatLng(lat, lng), 15.0);

    // show a confirmation snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(fromMap
            ? 'Ubicación seleccionada en el mapa: Lat $lat, Lng $lng'
            : 'Ubicación obtenida: Lat $lat, Lng $lng',
        ),
        backgroundColor: Colors.green, 
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Map as background
          if (!_isLoading)
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _centerLocation,
                initialZoom: 13.0,
                minZoom: 10.0,
                maxZoom: 18.0,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                  subdomains: const ['a', 'b', 'c'],
                  maxZoom: 19,
                  errorTileCallback: (tile, error, stackTrace) {
                    print('Error loading tile: $error');
                  },
                ),

                // User selected location marker
                if (_pickedLocation != null) 
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _pickedLocation!, 
                        width: 60,
                        height: 60,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.person_pin_circle,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                      ),
                    ],
                  ),
                
                // Real recycling items markers
                MarkerLayer(
                  markers: _filteredItems.map((item) {
                    return Marker(
                      point: LatLng(item.latitude, item.longitude),
                      width: 50,
                      height: 50,
                      child: GestureDetector(
                        onTap: () => _showItemDetails(item),
                        child: Container(
                          decoration: BoxDecoration(
                            color: _getCategoryColor(item.categoryName),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            _getCategoryIcon(item.categoryName),
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),

          // Loading overlay
          if (_isLoading)
            Container(
              color: Colors.white,
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      color: Color(0xFF2D8A8A),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Cargando artículos...',
                      style: TextStyle(
                        color: Color(0xFF2D8A8A),
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Error overlay
          if (_hasError && !_isLoading)
            Container(
              color: Colors.white,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 64,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage,
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _refreshData,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reintentar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2D8A8A),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          
          // Rest of your UI components (AppBar, SearchBar, Categories, etc.)
          // Transparent AppBar overlay
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: MediaQuery.of(context).padding.top + 60,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.4),
                    Colors.black.withOpacity(0.2),
                    Colors.transparent,
                  ],
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      const Text(
                        'Mapa de Reciclaje',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      // Refresh button
                      IconButton(
                        onPressed: _refreshData,
                        icon: const Icon(
                          Icons.refresh,
                          color: Colors.white,
                        ),
                        tooltip: 'Actualizar datos',
                      ),
                      IconButton(
                        onPressed: () {},
                        icon: CircleAvatar(
                          radius: 20,
                          backgroundColor: Colors.white,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFF2D8A8A),
                                width: 2,
                              ),
                            ),
                            child: const CircleAvatar(
                              radius: 18,
                              backgroundColor: Colors.white,
                              child: Icon(
                                Icons.notifications,
                                color: Color(0xFF2D8A8A),
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          // Search bar
          Positioned(
            top: MediaQuery.of(context).padding.top + 70,
            left: 16,
            right: 16,
            child: Container(
              height: 45,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
                border: _searchQuery.isNotEmpty 
                    ? Border.all(color: const Color(0xFF2D8A8A), width: 2)
                    : null,
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Buscar artículos, categorías, usuarios...',
                  prefixIcon: Icon(
                    Icons.search, 
                    color: _searchQuery.isNotEmpty 
                        ? const Color(0xFF2D8A8A) 
                        : Colors.grey,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          onPressed: _clearSearch,
                          icon: const Icon(
                            Icons.clear,
                            color: Color(0xFF2D8A8A),
                          ),
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  hintStyle: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
              ),
            ),
          ),
          
          // Category filter overlay
          if (!_isLoading)
            Positioned(
              top: MediaQuery.of(context).padding.top + 125,
              left: 0,
              right: 0,
              child: Container(
                height: 60,
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final category = _categories[index];
                    final isSelected = category == _selectedCategory;
                    final categoryCount = _getCategoryCount(category);
                    
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected 
                              ? const Color(0xFF2D8A8A)
                              : Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                          border: categoryCount == 0 
                              ? Border.all(color: Colors.red.withOpacity(0.3))
                              : null,
                        ),
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _selectedCategory = category;
                            });
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  category,
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : const Color(0xFF2D8A8A),
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                if (categoryCount > 0) ...[
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isSelected 
                                          ? Colors.white.withOpacity(0.3)
                                          : const Color(0xFF2D8A8A).withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '$categoryCount',
                                      style: TextStyle(
                                        color: isSelected ? Colors.white : const Color(0xFF2D8A8A),
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          
          // Search results info
          if (_searchQuery.isNotEmpty && !_isLoading)
            Positioned(
              top: MediaQuery.of(context).padding.top + 195,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2D8A8A).withOpacity(0.9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search, color: Colors.white, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Búsqueda: "$_searchQuery" - ${_filteredItems.length} resultado(s)',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _clearSearch,
                      icon: const Icon(Icons.close, color: Colors.white, size: 16),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
            ),
          
          // No results message
          if (_filteredItems.isEmpty && !_isLoading && !_hasError)
            Positioned(
              bottom: 100,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.search_off, color: Colors.white, size: 32),
                    const SizedBox(height: 8),
                    const Text(
                      'No se encontraron artículos',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _searchQuery.isNotEmpty 
                          ? 'Intenta con otros términos de búsqueda'
                          : 'No hay artículos registrados en esta categoría',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _refreshData,
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.2),
                      ),
                      child: const Text(
                        'Actualizar',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      // floatingActionButton: LocationInput(
      //   initialLocation: _centerLocation,
      //   onSelectLocation: _onLocationSelected,
      // ),
    );
  }
}