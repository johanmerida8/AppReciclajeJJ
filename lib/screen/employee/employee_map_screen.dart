import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:reciclaje_app/auth/auth_service.dart';
import 'package:reciclaje_app/model/recycling_items.dart';
import 'package:reciclaje_app/database/users_database.dart';
import 'package:reciclaje_app/services/location_service.dart';
import 'package:reciclaje_app/services/map_service.dart';
import 'package:reciclaje_app/database/media_database.dart';
import 'package:reciclaje_app/model/multimedia.dart';
import 'package:reciclaje_app/services/marker_cluster.dart';
import 'package:reciclaje_app/utils/category_utils.dart';
import 'package:reciclaje_app/screen/distribuidor/detail_recycle_screen.dart';
import 'package:reciclaje_app/widgets/map_marker.dart';
import 'package:reciclaje_app/widgets/status_indicator.dart';
import 'package:reciclaje_app/screen/employee/employee_notifications_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';

class EmployeeMapScreen extends StatefulWidget {
  const EmployeeMapScreen({super.key});

  @override
  State<EmployeeMapScreen> createState() => _EmployeeMapScreenState();
}

class _EmployeeMapScreenState extends State<EmployeeMapScreen> with WidgetsBindingObserver {
  // Services
  final _authService = AuthService();
  final _usersDatabase = UsersDatabase();
  final _locationService = LocationService();
  final _mapService = MapService();
  final _clusterService = MarkerClusterService();
  final _mediaDatabase = MediaDatabase();

  // Controllers
  final _mapController = MapController();

  // State variables
  List<RecyclingItem> _assignedArticles = [];
  int? _employeeId;
  
  int _currentArticleIndex = 0;
  bool _showArticleNavigation = false;
  double _currentZoom = 13.0;

  // Location state
  LatLng? _userLocation;
  bool _hasUserLocation = false;
  bool _showUserMarker = true;

  // Loading & error state
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';

  // Connection state
  bool _hasLocationPermission = false;
  bool _isLocationServiceEnabled = false;
  bool _isConnected = true;
  bool _hasCheckedLocation = false;
  int _pendingRequestCount = 0; // Notification count for new assigned tasks

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
    _monitorConnection();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _recheckLocationAfterResume();
    }
  }

  Future<void> _recheckLocationAfterResume() async {
    final previousServiceEnabled = _isLocationServiceEnabled;
    final previousPermission = _hasLocationPermission;
    
    await _checkLocationServices();
    
    final gpsJustEnabled = !previousServiceEnabled && _isLocationServiceEnabled;
    final permissionJustGranted = !previousPermission && _hasLocationPermission;
    
    if (gpsJustEnabled || permissionJustGranted) {
      await _loadUserLocation();
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> _initialize() async {
    await _loadEmployeeData();
    await _checkLocationServices();
    await _checkConnection();
    await _loadPendingTaskCount(); // Load notification count
    
    if (_isLocationServiceEnabled && _hasLocationPermission) {
      await _loadUserLocation();
    }
  }

  /// Monitor internet connection
  void _monitorConnection() {
    InternetConnectionChecker().onStatusChange.listen((status) {
      if (mounted) {
        setState(() {
          _isConnected = status == InternetConnectionStatus.connected;
        });
      }
    });
  }

  /// Load pending task count for notifications
  Future<void> _loadPendingTaskCount() async {
    if (_employeeId == null) return;

    try {
      final tasks = await Supabase.instance.client
          .from('tasks')
          .select('idTask')
          .eq('employeeID', _employeeId!)
          .eq('workflowStatus', 'asignado')
          .order('assignedDate', ascending: false);

      if (mounted) {
        setState(() {
          _pendingRequestCount = tasks.length;
        });
      }
    } catch (e) {
      print('❌ Error loading pending task count: $e');
    }
  }

  /// Navigate to notifications/tasks screen
  Future<void> _navigateToNotifications() async {
    // Navigate to employee notifications screen
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const EmployeeNotificationsScreen(),
      ),
    );
    
    // Refresh count when returning
    await _loadPendingTaskCount();
  }

  /// Check internet connection
  Future<void> _checkConnection() async {
    try {
      // Simple check - if we can load data, we're connected
      setState(() {
        _isConnected = true;
      });
    } catch (e) {
      setState(() {
        _isConnected = false;
      });
    }
  }

  Future<void> _loadEmployeeData() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final email = _authService.getCurrentUserEmail();
      if (email == null) throw Exception('No user email found');

      final user = await _usersDatabase.getUserByEmail(email);
      if (user == null) throw Exception('User not found');

      // Get employee ID
      final employeeData = await Supabase.instance.client
          .from('employees')
          .select('idEmployee')
          .eq('userID', user.id!)
          .maybeSingle();

      if (employeeData == null) throw Exception('Employee not found');

      _employeeId = employeeData['idEmployee'] as int;

      // Load assigned articles
      await _loadAssignedArticles();

    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
      print('❌ Error loading employee data: $e');
    }
  }

  Future<void> _loadAssignedArticles() async {
    if (_employeeId == null) return;

    try {
      // Get tasks for this employee with article details
      final tasks = await Supabase.instance.client
          .from('tasks')
          .select('''
            idTask,
            employeeID,
            articleID,
            workflowStatus,
            article:articleID(
              idArticle,
              name,
              description,
              address,
              lat,
              lng,
              categoryID,
              userID,
              availableDays,
              availableTimeStart,
              availableTimeEnd,
              condition,
              lastUpdate,
              category:categoryID(idCategory, name),
              user:userID(names, email)
            ),
            request:requestID(
              scheduledDay,
              scheduledTime
            )
          ''')
          .eq('employeeID', _employeeId!)
          .inFilter('workflowStatus', ['asignado', 'en_proceso'])
          .order('assignedDate', ascending: false);

      if (mounted) {
        final articles = <RecyclingItem>[];
        
        for (var task in tasks) {
          final article = task['article'] as Map<String, dynamic>?;
          if (article != null) {
            final category = article['category'] as Map<String, dynamic>?;
            final user = article['user'] as Map<String, dynamic>?;
            
            articles.add(RecyclingItem(
              id: article['idArticle'] as int,
              title: article['name'] as String,
              description: article['description'] as String?,
              address: article['address'] as String,
              latitude: (article['lat'] as num).toDouble(),
              longitude: (article['lng'] as num).toDouble(),
              categoryID: article['categoryID'] as int?,
              categoryName: category?['name'] as String? ?? 'Sin categoría',
              ownerUserId: article['userID'] as int?,
              userName: user?['names'] as String? ?? 'Usuario',
              userEmail: user?['email'] as String? ?? '',
              availableDays: article['availableDays'] as String? ?? 'No especificado',
              availableTimeStart: article['availableTimeStart'] as String? ?? '00:00',
              availableTimeEnd: article['availableTimeEnd'] as String? ?? '23:59',
              condition: article['condition'] as String?,
              // workflowStatus: article['workflowStatus'] as String?,
              createdAt: DateTime.now(), // Use current time as fallback
            ));
          }
        }

        setState(() {
          _assignedArticles = articles;
          _isLoading = false;
        });

        print('✅ Loaded ${_assignedArticles.length} assigned articles for employee $_employeeId');

        // Fit map to show all articles
        if (_assignedArticles.isNotEmpty) {
          _fitMapToShowAllArticles();
        }
      }
    } catch (e) {
      print('❌ Error loading assigned articles: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _loadUserLocation() async {
    try {
      await _checkLocationServices();
      
      if (!_isLocationServiceEnabled || !_hasLocationPermission) return;
      
      final location = await _locationService.getCurrentLocation();
      
      if (location != null) {
        setState(() {
          _userLocation = location;
          _hasUserLocation = true;
        });
        print('✅ User location loaded: $location');
      }
    } catch (e) {
      print('❌ Error getting user location: $e');
      setState(() {
        _hasUserLocation = false;
        _userLocation = null;
      });
    }
  }

  Future<void> _checkLocationServices() async {
    final status = await _locationService.checkLocationStatus();
    
    setState(() {
      _isLocationServiceEnabled = status['serviceEnabled'] ?? false;
      _hasLocationPermission = status['hasPermission'] ?? false;
    });
  }

  void _fitMapToShowAllArticles() {
    _mapService.fitMapToShowAllArticles(
      _mapController,
      _assignedArticles,
      _userLocation,
      _hasUserLocation,
    );
  }

  Future<void> _refreshData() async {
    await _loadAssignedArticles();
    await _loadUserLocation();
  }

  Widget _buildTopBar() {
    return Positioned(
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
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: StatusIndicators(
              isDeviceConnected: _isConnected,
              isLocationServiceEnabled: _isLocationServiceEnabled,
              hasLocationPermission: _hasLocationPermission,
              hasCheckedLocation: _hasCheckedLocation,
              onGpsTap: _checkLocationServices,
              onRefreshTap: _refreshData,
              notificationCount: _pendingRequestCount,
              onNotificationTap: _navigateToNotifications,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F8),
      body: Stack(
        children: [
          // Map
          _buildMap(),

          // Loading overlay
          if (_isLoading) _buildLoadingOverlay(),

          // Error overlay
          if (_hasError) _buildErrorOverlay(),

          // Top bar with status indicators
          _buildTopBar(),
        ],
      ),
      floatingActionButton: _buildLocationFAB(),
    );
  }

  Widget _buildMap() {
    if (_isLoading) return const SizedBox();

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _userLocation ?? const LatLng(-17.3895, -66.1568),
        initialZoom: _currentZoom,
        onPositionChanged: (position, hasGesture) {
          setState(() {
            _currentZoom = position.zoom;
          });
        },
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
          subdomains: const ['a', 'b', 'c'],
        ),
        // ✅ User location marker with same style as distributor
        if (_showUserMarker && _hasUserLocation && _userLocation != null)
          MarkerLayer(
            markers: [MapMarkers.userLocationMarker(_userLocation!)],
          ),
        if (_assignedArticles.isNotEmpty) _buildDynamicMarkers(),
      ],
    );
  }

  Widget _buildDynamicMarkers() {
    if (_assignedArticles.isEmpty) return const SizedBox.shrink();

    final clusters = _clusterService.clusterItems(_assignedArticles, _currentZoom);
    List<Marker> markers = [];

    for (var cluster in clusters) {
      if (cluster.items.length == 1) {
        // Single item - show regular marker
        markers.add(_buildSingleMarker(cluster.items.first));
      } else {
        // Multiple items - show cluster marker
        markers.add(_buildClusterMarker(cluster));
      }
    }

    return MarkerLayer(markers: markers);
  }

  Marker _buildSingleMarker(RecyclingItem item) {
    final isSelected = _showArticleNavigation && 
                      _assignedArticles[_currentArticleIndex].id == item.id;
    
    return Marker(
      point: LatLng(item.latitude, item.longitude),
      width: 40,
      height: 40,
      child: GestureDetector(
        onTap: () => _onMarkerTap(item),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          transform: Matrix4.identity()..scale(isSelected ? 1.3 : 1.0),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF2D8A8A),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white,
                width: isSelected ? 3 : 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              CategoryUtils.getCategoryIcon(item.categoryName),
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }

  Marker _buildClusterMarker(MarkerCluster cluster) {
    return Marker(
      point: cluster.center,
      width: 60,
      height: 60,
      child: GestureDetector(
        onTap: () {
          // Show navigation modal with all articles in cluster
          _showArticleNavigationModal(cluster.items, cluster.items.first);
        },
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF2D8A8A),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Text(
              '${cluster.items.length}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _onMarkerTap(RecyclingItem item) {
    final index = _assignedArticles.indexWhere((i) => i.id == item.id);
    
    setState(() {
      _currentArticleIndex = index;
      _showArticleNavigation = true;
    });
    
    if (_mapService.isMapReady(_mapController)) {
      _mapController.move(LatLng(item.latitude, item.longitude), 16);
    }
    
    // Find nearby articles within 100 meters
    final nearbyArticles = _findNearbyArticles(item, maxDistance: 100);
    
    if (nearbyArticles.length > 1) {
      // Show navigation modal if there are nearby articles
      _showArticleNavigationModal(nearbyArticles, item);
    } else {
      // Show single article modal if it's alone
      _showSingleArticleModal(item);
    }
  }

  /// Find articles near the given article
  List<RecyclingItem> _findNearbyArticles(RecyclingItem item, {required double maxDistance}) {
    List<RecyclingItem> nearby = [];
    
    for (var article in _assignedArticles) {
      final distance = _calculateDistance(
        item.latitude, item.longitude,
        article.latitude, article.longitude,
      );
      
      if (distance <= maxDistance) {
        nearby.add(article);
      }
    }
    
    return nearby;
  }

  /// Calculate distance between two points in meters (Haversine formula)
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000; // meters
    
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) *
        sin(dLon / 2) * sin(dLon / 2);
    
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degrees) {
    return degrees * pi / 180;
  }

  /// Show single article modal (no navigation)
  void _showSingleArticleModal(RecyclingItem item) async {
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _EmployeeSingleArticleModal(
        item: item,
        mediaDatabase: _mediaDatabase,
        onNavigateToDetails: (item) {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DetailRecycleScreen(item: item),
            ),
          );
        },
      ),
    ).then((_) {
      if (mounted) {
        setState(() {
          _showArticleNavigation = false;
        });
      }
    });
  }

  /// Show article navigation modal (with anterior/siguiente buttons)
  void _showArticleNavigationModal(List<RecyclingItem> articles, RecyclingItem currentItem) async {
    if (!mounted) return;

    final currentIndex = articles.indexWhere((a) => a.id == currentItem.id);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _EmployeeArticleNavigationModal(
        articles: articles,
        initialIndex: currentIndex >= 0 ? currentIndex : 0,
        mediaDatabase: _mediaDatabase,
        onNavigateToDetails: (item) {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DetailRecycleScreen(item: item),
            ),
          );
        },
        onArticleChange: (item) {
          // Move map to the new article location
          if (_mapService.isMapReady(_mapController)) {
            _mapController.move(LatLng(item.latitude, item.longitude), 16);
          }
        },
      ),
    ).then((_) {
      if (mounted) {
        setState(() {
          _showArticleNavigation = false;
        });
      }
    });
  }

  // Widget _buildTopBar() {
  //   return Positioned(
  //     top: 16,
  //     left: 16,
  //     right: 16,
  //     child: Container(
  //       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  //       decoration: BoxDecoration(
  //         color: Colors.white,
  //         borderRadius: BorderRadius.circular(30),
  //         boxShadow: [
  //           BoxShadow(
  //             color: Colors.black.withOpacity(0.1),
  //             blurRadius: 10,
  //             offset: const Offset(0, 2),
  //           ),
  //         ],
  //       ),
  //       child: Row(
  //         children: [
  //           const Icon(Icons.assignment, color: Color(0xFF2D8A8A)),
  //           const SizedBox(width: 12),
  //           Expanded(
  //             child: Text(
  //               'Mis Tareas Asignadas (${_assignedArticles.length})',
  //               style: const TextStyle(
  //                 fontSize: 16,
  //                 fontWeight: FontWeight.bold,
  //                 color: Color(0xFF2D8A8A),
  //               ),
  //             ),
  //           ),
  //         ],
  //       ),
  //     ),
  //   );
  // }

  /// ✅ Unified location FAB with menu
  Widget _buildLocationFAB() {
    return FloatingActionButton(
      onPressed: _showLocationMenu,
      backgroundColor: const Color(0xFF2D8A8A),
      child: const Icon(Icons.tune, color: Colors.white),
    );
  }

  /// ✅ Show location menu options
  void _showLocationMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 50,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Opciones de Ubicación',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            
            // Go to my location
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFF2D8A8A),
                child: Icon(Icons.my_location, color: Colors.white),
              ),
              title: const Text('Ir a mi ubicación'),
              subtitle: Text(
                _hasUserLocation ? 'Centrar mapa en tu ubicación actual' : 'GPS deshabilitado',
              ),
              onTap: () {
                Navigator.pop(context);
                _goToUserLocation();
              },
            ),
            
            // Toggle user marker
            ListTile(
              leading: CircleAvatar(
                backgroundColor: _showUserMarker ? Colors.blue : Colors.grey,
                child: Icon(
                  _showUserMarker ? Icons.person_pin_circle : Icons.person_pin_circle_outlined,
                  color: Colors.white,
                ),
              ),
              title: Text(_showUserMarker ? 'Ocultar mi marcador' : 'Mostrar mi marcador'),
              subtitle: const Text('Mostrar/ocultar tu ubicación en el mapa'),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _showUserMarker = !_showUserMarker;
                });
              },
            ),
            
            // Refresh data
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.green,
                child: Icon(Icons.refresh, color: Colors.white),
              ),
              title: const Text('Actualizar datos'),
              subtitle: const Text('Recargar tareas asignadas'),
              onTap: () {
                Navigator.pop(context);
                _refreshData();
              },
            ),
            
            // View all articles
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.orange,
                child: Icon(Icons.fit_screen, color: Colors.white),
              ),
              title: const Text('Ver todas las tareas'),
              subtitle: const Text('Ajustar mapa para ver todas las ubicaciones'),
              onTap: () {
                Navigator.pop(context);
                _fitMapToShowAllArticles();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.3),
      child: const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF2D8A8A),
        ),
      ),
    );
  }

  Widget _buildErrorOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.5),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 60, color: Colors.white),
            const SizedBox(height: 16),
            const Text(
              'Error al cargar el mapa',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage,
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _refreshData,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  /// ✅ Go to user location
  Future<void> _goToUserLocation() async {
    await _checkLocationServices();
    
    if (!_isLocationServiceEnabled || !_hasLocationPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Por favor habilita los servicios de ubicación'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }
    
    if (_hasUserLocation && _userLocation != null) {
      _mapController.move(_userLocation!, 15);
    } else {
      await _loadUserLocation();
    }
  }
}

// ============================================================================
// Single article modal widget (no navigation buttons)
// ============================================================================

class _EmployeeSingleArticleModal extends StatefulWidget {
  final RecyclingItem item;
  final MediaDatabase mediaDatabase;
  final Function(RecyclingItem) onNavigateToDetails;

  const _EmployeeSingleArticleModal({
    required this.item,
    required this.mediaDatabase,
    required this.onNavigateToDetails,
  });

  @override
  State<_EmployeeSingleArticleModal> createState() => _EmployeeSingleArticleModalState();
}

class _EmployeeSingleArticleModalState extends State<_EmployeeSingleArticleModal> {
  Multimedia? currentPhoto;
  bool isLoadingPhoto = false;

  @override
  void initState() {
    super.initState();
    _loadPhoto();
  }

  Future<void> _loadPhoto() async {
    setState(() => isLoadingPhoto = true);
    
    try {
      final urlPattern = 'articles/${widget.item.id}';
      final photo = await widget.mediaDatabase.getMainPhotoByPattern(urlPattern);
      
      if (mounted) {
        setState(() {
          currentPhoto = photo;
          isLoadingPhoto = false;
        });
      }
    } catch (e) {
      print('Error loading photo: $e');
      if (mounted) {
        setState(() => isLoadingPhoto = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            height: 6,
            width: 50,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Photo
                  if (isLoadingPhoto)
                    const Center(child: CircularProgressIndicator())
                  else if (currentPhoto?.url != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        currentPhoto!.url!,
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    )
                  else
                    _buildPlaceholder(),
                  const SizedBox(height: 16),
                  
                  // Title
                  Text(
                    widget.item.title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Category
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              CategoryUtils.getCategoryIcon(widget.item.categoryName),
                              size: 16,
                              color: Colors.blue,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              widget.item.categoryName,
                              style: const TextStyle(
                                color: Colors.blue,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Description
                  if (widget.item.description != null) ...[
                    const Text(
                      'Descripción:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.item.description!,
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                  ],
                  
                  // Address
                  const Text(
                    'Ubicación:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.item.address,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // View Details Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => widget.onNavigateToDetails(widget.item),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2D8A8A),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Ver Detalles Completos',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Icon(
          CategoryUtils.getCategoryIcon(widget.item.categoryName),
          size: 60,
          color: Colors.grey[600],
        ),
      ),
    );
  }
}

// ============================================================================
// Article navigation modal widget (with Anterior/Siguiente buttons)
// ============================================================================

class _EmployeeArticleNavigationModal extends StatefulWidget {
  final List<RecyclingItem> articles;
  final int initialIndex;
  final MediaDatabase mediaDatabase;
  final Function(RecyclingItem) onNavigateToDetails;
  final Function(RecyclingItem) onArticleChange;

  const _EmployeeArticleNavigationModal({
    required this.articles,
    required this.initialIndex,
    required this.mediaDatabase,
    required this.onNavigateToDetails,
    required this.onArticleChange,
  });

  @override
  State<_EmployeeArticleNavigationModal> createState() => _EmployeeArticleNavigationModalState();
}

class _EmployeeArticleNavigationModalState extends State<_EmployeeArticleNavigationModal> {
  late int currentIndex;
  Multimedia? currentPhoto;
  bool isLoadingPhoto = false;

  @override
  void initState() {
    super.initState();
    currentIndex = widget.initialIndex;
    _loadPhoto();
  }

  RecyclingItem get currentItem => widget.articles[currentIndex];

  Future<void> _loadPhoto() async {
    setState(() => isLoadingPhoto = true);
    
    try {
      final urlPattern = 'articles/${currentItem.id}';
      final photo = await widget.mediaDatabase.getMainPhotoByPattern(urlPattern);
      
      if (mounted) {
        setState(() {
          currentPhoto = photo;
          isLoadingPhoto = false;
        });
      }
    } catch (e) {
      print('Error loading photo: $e');
      if (mounted) {
        setState(() => isLoadingPhoto = false);
      }
    }
  }

  void _goToPrevious() {
    if (currentIndex > 0) {
      setState(() {
        currentIndex--;
        currentPhoto = null;
      });
      _loadPhoto();
      widget.onArticleChange(currentItem);
    }
  }

  void _goToNext() {
    if (currentIndex < widget.articles.length - 1) {
      setState(() {
        currentIndex++;
        currentPhoto = null;
      });
      _loadPhoto();
      widget.onArticleChange(currentItem);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            height: 6,
            width: 50,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          
          // Navigation header
          if (widget.articles.length > 1)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: currentIndex > 0 ? _goToPrevious : null,
                    icon: const Icon(Icons.arrow_back),
                    style: IconButton.styleFrom(
                      backgroundColor: currentIndex > 0 
                          ? const Color(0xFF2D8A8A).withOpacity(0.1)
                          : Colors.grey[200],
                    ),
                  ),
                  Text(
                    '${currentIndex + 1} de ${widget.articles.length} artículos',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2D8A8A),
                    ),
                  ),
                  IconButton(
                    onPressed: currentIndex < widget.articles.length - 1 ? _goToNext : null,
                    icon: const Icon(Icons.arrow_forward),
                    style: IconButton.styleFrom(
                      backgroundColor: currentIndex < widget.articles.length - 1
                          ? const Color(0xFF2D8A8A).withOpacity(0.1)
                          : Colors.grey[200],
                    ),
                  ),
                ],
              ),
            ),
          
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Photo
                  if (isLoadingPhoto)
                    const Center(child: CircularProgressIndicator())
                  else if (currentPhoto?.url != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        currentPhoto!.url!,
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    )
                  else
                    _buildPlaceholder(),
                  const SizedBox(height: 16),
                  
                  // Title
                  Text(
                    currentItem.title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Category
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              CategoryUtils.getCategoryIcon(currentItem.categoryName),
                              size: 16,
                              color: Colors.blue,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              currentItem.categoryName,
                              style: const TextStyle(
                                color: Colors.blue,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Description
                  if (currentItem.description != null) ...[
                    const Text(
                      'Descripción:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      currentItem.description!,
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                  ],
                  
                  // Address
                  const Text(
                    'Ubicación:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          currentItem.address,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // View Details Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => widget.onNavigateToDetails(currentItem),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2D8A8A),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Ver Detalles Completos',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Icon(
          CategoryUtils.getCategoryIcon(currentItem.categoryName),
          size: 60,
          color: Colors.grey[600],
        ),
      ),
    );
  }
}
