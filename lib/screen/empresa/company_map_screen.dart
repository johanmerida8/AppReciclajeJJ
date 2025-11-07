import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:reciclaje_app/auth/auth_service.dart';
import 'package:reciclaje_app/model/recycling_items.dart';
import 'package:reciclaje_app/services/cache_service.dart';
import 'package:reciclaje_app/services/location_service.dart';
import 'package:reciclaje_app/services/map_service.dart';
import 'package:reciclaje_app/database/media_database.dart';
import 'package:reciclaje_app/model/multimedia.dart';
import 'package:reciclaje_app/services/marker_cluster.dart';
import 'package:reciclaje_app/services/recycling_data.dart';
import 'package:reciclaje_app/utils/category_utils.dart';
import 'package:reciclaje_app/screen/distribuidor/detail_recycle_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CompanyMapScreen extends StatefulWidget {
  const CompanyMapScreen({super.key});

  @override
  State<CompanyMapScreen> createState() => _CompanyMapScreenState();
}

class _CompanyMapScreenState extends State<CompanyMapScreen> with WidgetsBindingObserver {
  // Services
  final _authService = AuthService();
  final _dataService = RecyclingDataService();
  final _locationService = LocationService();
  final _cacheService = CacheService();
  final _mapService = MapService();
  final _clusterService = MarkerClusterService();
  final _mediaDatabase = MediaDatabase();

  // Controllers
  final _mapController = MapController();

  // State variables
  List<RecyclingItem> _allItems = [];
  List<RecyclingItem> _filteredItems = [];
  List<Map<String, dynamic>> _employees = [];
  int? _currentUserId;
  int? _companyId;
  
  // Filter states
  Set<String> _selectedStatuses = {'publicados', 'en_espera', 'sin_asignar', 'en_proceso', 'recogidos', 'vencidos'};
  String _sortBy = 'recent'; // 'recent', 'oldest', 'status'
  
  int _currentArticleIndex = 0;
  bool _showArticleNavigation = false;
  double _currentZoom = 13.0;
  Map<LatLng, bool> _expandedClusters = {};

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Ubicación activada correctamente'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _initialize() async {
    await _loadUserData();
    await _loadEmployees();
    await _loadData();
    await _checkLocationServices();
    
    if (_isLocationServiceEnabled && _hasLocationPermission) {
      await _loadUserLocation();
    }
  }

  Future<void> _loadUserData() async {
    final email = _authService.getCurrentUserEmail();
    if (email != null) {
      final userData = await _dataService.userDatabase.getUserByEmail(email);
      setState(() {
        _currentUserId = userData?.id;
      });
      
      // Load company ID
      if (_currentUserId != null) {
        try {
          final companyData = await Supabase.instance.client
              .from('company')
              .select('idCompany')
              .eq('adminUserID', _currentUserId!)
              .single();
          setState(() {
            _companyId = companyData['idCompany'] as int?;
          });
        } catch (e) {
          print('❌ Error loading company: $e');
        }
      }
    }
  }

  Future<void> _loadEmployees() async {
    if (_companyId == null) return;
    
    try {
      final employees = await Supabase.instance.client
          .from('employees')
          .select('*, users:userID(*)')
          .eq('companyID', _companyId!);
      
      setState(() {
        _employees = List<Map<String, dynamic>>.from(employees);
      });
      print('✅ Loaded ${_employees.length} employees');
    } catch (e) {
      print('❌ Error loading employees: $e');
    }
  }

  Future<void> _loadData({bool forceRefresh = false}) async {
    if (!forceRefresh && await _loadFromCache()) {
      _loadFreshDataInBackground();
      return;
    }

    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    await _loadFreshData();
  }

  Future<bool> _loadFromCache() async {
    try {
      final cachedData = await _cacheService.loadCache(_currentUserId);
      if (cachedData != null && cachedData['items'] != null) {
        setState(() {
          _allItems = cachedData['items'];
          _applyFilters();
          _isLoading = false;
        });
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Error loading from cache: $e');
      return false;
    }
  }

  Future<void> _loadFreshData({bool showLoading = true}) async {
    try {
      final items = await _dataService.loadRecyclingItems();
      final categories = await _dataService.loadCategories();

      setState(() {
        _allItems = items;
        _applyFilters();
        _hasError = false;
        _isLoading = false;
      });

      await _cacheService.saveCache(items, categories, _currentUserId);
      print('✅ Loaded ${items.length} items fresh');

      if (_filteredItems.isNotEmpty) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) _fitMapToShowAllArticles();
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _hasError = true;
        _isLoading = false;
      });
      print('❌ Error loading fresh data: $e');
    }
  }

  Future<void> _loadFreshDataInBackground() async {
    try {
      await _loadFreshData(showLoading: false);
    } catch (e) {
      print('Error updating in background: $e');
    }
  }

  Future<void> _loadUserLocation() async {
    try {
      await _checkLocationServices();
      
      if (!_isLocationServiceEnabled || !_hasLocationPermission) {
        return;
      }
      
      final location = await _locationService.getCurrentLocation();
      
      if (location != null) {
        setState(() {
          _userLocation = LatLng(location.latitude, location.longitude);
          _hasUserLocation = true;
        });
        
        if (_mapService.isMapReady(_mapController)) {
          _mapController.move(_userLocation!, MapService.closeZoomLevel);
        }
        
        print('✅ Ubicación del usuario cargada: ${location.latitude}, ${location.longitude}');
      }
    } catch (e) {
      print('❌ Error obteniendo ubicación del usuario: $e');
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

  void _applyFilters() {
    List<RecyclingItem> filtered = List.from(_allItems);
    
    // ✅ DON'T filter by company - show ALL articles like distributor
    // Companies can see all published articles to assign to their employees
    
    // Filter by selected statuses
    filtered = filtered.where((item) {
      final status = _getItemStatus(item);
      return _selectedStatuses.contains(status);
    }).toList();
    
    // Sort
    switch (_sortBy) {
      case 'recent':
        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case 'oldest':
        filtered.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case 'status':
        filtered.sort((a, b) => _getItemStatus(a).compareTo(_getItemStatus(b)));
        break;
    }
    
    setState(() {
      _filteredItems = filtered;
    });
  }

  String _getItemStatus(RecyclingItem item) {
    final status = item.workflowStatus?.toLowerCase() ?? 'publicados';
    
    if (status == 'completado') return 'recogidos';
    if (status == 'en_proceso') return 'en_proceso';
    if (status == 'asignado') return 'sin_asignar';
    if (status == 'vencido') return 'vencidos';
    if (status == 'pendiente' || status == 'publicados') return 'en_espera';
    
    return 'publicados';
  }

  Future<void> _refreshData() async {
    await _cacheService.clearCache();
    await _loadData(forceRefresh: true);
    await _loadEmployees();

    final lastLocation = _locationService.lastKnownLocation ?? _userLocation;
    if (lastLocation != null) {
      Future.microtask(() {
        if (_mapService.isMapReady(_mapController)) {
          _mapController.move(lastLocation, _currentZoom);
        }
      });
    }
  }

  void _fitMapToShowAllArticles() {
    _mapService.fitMapToShowAllArticles(
      _mapController,
      _filteredItems,
      _userLocation,
      _hasUserLocation,
    );
  }

  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _FilterDialog(
        selectedStatuses: _selectedStatuses,
        sortBy: _sortBy,
        onApply: (statuses, sort) {
          setState(() {
            _selectedStatuses = statuses;
            _sortBy = sort;
            _applyFilters();
          });
        },
      ),
    );
  }

  void _showAssignEmployeeDialog(RecyclingItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AssignEmployeeDialog(
        item: item,
        employees: _employees,
        onAssign: (employeeId) async {
          await _assignArticleToEmployee(item, employeeId);
        },
      ),
    );
  }

  Future<void> _assignArticleToEmployee(RecyclingItem item, int employeeId) async {
    try {
      // Create task for employee
      await Supabase.instance.client.from('tasks').insert({
        'employeeID': employeeId,
        'articleID': item.id,
        'companyID': _companyId,
        'assignedBy': _currentUserId,
        'status': 'asignado',
        'priority': 'media',
        'assignedDate': DateTime.now().toIso8601String(),
      });
      
      // Update article workflow status
      await Supabase.instance.client
          .from('article')
          .update({'workflowStatus': 'asignado'})
          .eq('idArticle', item.id);
      
      if (mounted) {
        Navigator.pop(context); // Close employee selection dialog
        Navigator.pop(context); // Close article detail modal
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Artículo asignado exitosamente'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        _refreshData();
      }
    } catch (e) {
      print('❌ Error assigning article: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error al asignar: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Widget _buildMap() {
    if (_isLoading) return const SizedBox();

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _userLocation ?? MapService.cochabambaCenter,
        initialZoom: _currentZoom,
        minZoom: 10.0,
        maxZoom: 18.0,
        onPositionChanged: (position, hasGesture) {
          if (hasGesture) {
            setState(() {
              _currentZoom = position.zoom;
            });
          }
        },
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
          subdomains: const ['a', 'b', 'c'],
          maxNativeZoom: 19,
          maxZoom: 19,
        ),
        if (_hasUserLocation && _showUserMarker && _userLocation != null)
          MarkerLayer(
            markers: [
              Marker(
                point: _userLocation!,
                width: 40,
                height: 40,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.my_location, color: Colors.blue, size: 24),
                ),
              ),
            ],
          ),
        if (_filteredItems.isNotEmpty) _buildDynamicMarkers(),
      ],
    );
  }

  Widget _buildDynamicMarkers() {
    if (_filteredItems.isEmpty) return const SizedBox.shrink();

    final clusters = _clusterService.clusterItems(_filteredItems, _currentZoom);
    List<Marker> markers = [];

    for (var cluster in clusters) {
      final isExpanded = _expandedClusters[cluster.center] ?? false;

      if (cluster.isSingleItem) {
        markers.add(_buildSingleMarker(cluster.items[0]));
      } else if (isExpanded) {
        markers.addAll(_buildExpandedClusterMarkers(cluster));
      } else {
        markers.add(_buildClusterMarker(cluster));
      }
    }

    return MarkerLayer(markers: markers);
  }

  Marker _buildSingleMarker(RecyclingItem item) {
    final isSelected = _showArticleNavigation && 
                      _filteredItems[_currentArticleIndex].id == item.id;
    final status = _getItemStatus(item);
    final color = _getStatusColor(status);
    
    return Marker(
      point: LatLng(item.latitude, item.longitude),
      width: isSelected ? 60 : 50,
      height: isSelected ? 60 : 50,
      child: GestureDetector(
        onTap: () => _onMarkerTap(item),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            border: isSelected
                ? Border.all(color: Colors.white, width: 4)
                : Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Icon(
              _getStatusIcon(status),
              color: Colors.white,
              size: isSelected ? 28 : 24,
            ),
          ),
        ),
      ),
    );
  }

  Marker _buildClusterMarker(MarkerCluster cluster) {
    return Marker(
      point: cluster.center,
      width: 70,
      height: 70,
      child: GestureDetector(
        onTap: () {
          setState(() {
            _expandedClusters[cluster.center] = true;
          });
          if (_mapService.isMapReady(_mapController)) {
            _mapController.move(cluster.center, min(_currentZoom + 2, 18.0));
          }
        },
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF2D8A8A),
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${cluster.count}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Text(
                'artículos',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Marker> _buildExpandedClusterMarkers(MarkerCluster cluster) {
    List<Marker> markers = [];
    final itemCount = cluster.items.length;
    const double radius = 0.0015;

    for (int i = 0; i < itemCount; i++) {
      double angle = (2 * pi * i) / itemCount;
      double offsetLat = radius * cos(angle);
      double offsetLng = radius * sin(angle);

      LatLng position = LatLng(
        cluster.center.latitude + offsetLat,
        cluster.center.longitude + offsetLng,
      );

      final item = cluster.items[i];
      final isSelected = _showArticleNavigation && 
                        _filteredItems[_currentArticleIndex].id == item.id;
      final status = _getItemStatus(item);
      final color = _getStatusColor(status);

      markers.add(
        Marker(
          point: position,
          width: isSelected ? 60 : 50,
          height: isSelected ? 60 : 50,
          child: GestureDetector(
            onTap: () => _onMarkerTap(item),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                border: isSelected
                    ? Border.all(color: Colors.white, width: 4)
                    : Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  _getStatusIcon(status),
                  color: Colors.white,
                  size: isSelected ? 28 : 24,
                ),
              ),
            ),
          ),
        ),
      );
    }

    markers.add(_buildCollapseMarker(cluster));
    return markers;
  }

  Marker _buildCollapseMarker(MarkerCluster cluster) {
    return Marker(
      point: cluster.center,
      width: 40,
      height: 40,
      child: GestureDetector(
        onTap: () {
          setState(() {
            _expandedClusters[cluster.center] = false;
          });
        },
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.red,
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: const Icon(Icons.close, color: Colors.white, size: 20),
        ),
      ),
    );
  }

  void _onMarkerTap(RecyclingItem item) {
    final index = _filteredItems.indexWhere((i) => i.id == item.id);
    
    setState(() {
      _currentArticleIndex = index;
      _showArticleNavigation = true;
    });
    
    if (_mapService.isMapReady(_mapController)) {
      _mapController.move(LatLng(item.latitude, item.longitude), 15.0);
    }
    
    _showArticleDetailModal(item);
  }

  void _showArticleDetailModal(RecyclingItem item) async {
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      builder: (context) => _CompanyArticleModal(
        item: item,
        mediaDatabase: _mediaDatabase,
        onAssignEmployee: () {
          Navigator.pop(context);
          _showAssignEmployeeDialog(item);
        },
        onNavigateToDetails: (RecyclingItem article) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DetailRecycleScreen(item: article),
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

  Color _getStatusColor(String status) {
    switch (status) {
      case 'recogidos':
        return Colors.green;
      case 'en_proceso':
        return Colors.orange;
      case 'sin_asignar':
        return Colors.amber;
      case 'vencidos':
        return Colors.red;
      case 'en_espera':
        return Colors.purple;
      default:
        return Colors.blue;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'recogidos':
        return Icons.check_circle;
      case 'en_proceso':
        return Icons.hourglass_empty;
      case 'sin_asignar':
        return Icons.assignment;
      case 'vencidos':
        return Icons.error;
      case 'en_espera':
        return Icons.schedule;
      default:
        return Icons.article;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _buildMap(),
          _buildTopBar(),
          if (_isLoading) _buildLoadingOverlay(),
          if (_hasError) _buildErrorOverlay(),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'filter',
            onPressed: _showFilterDialog,
            backgroundColor: const Color(0xFF2D8A8A),
            child: const Icon(Icons.filter_list, color: Colors.white),
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            heroTag: 'location',
            onPressed: _goToUserLocation,
            backgroundColor: const Color(0xFF2D8A8A),
            child: const Icon(Icons.my_location, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Future<void> _goToUserLocation() async {
    await _checkLocationServices();
    
    if (!_isLocationServiceEnabled || !_hasLocationPermission) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Ubicación no disponible'),
            content: const Text('Por favor, activa la ubicación en la configuración.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
      return;
    }
    
    if (_hasUserLocation && _userLocation != null) {
      if (_mapService.isMapReady(_mapController)) {
        _mapController.move(_userLocation!, 15.0);
      }
    } else {
      await _loadUserLocation();
    }
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 50, 16, 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.7),
              Colors.transparent,
            ],
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Mapa de Artículos',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${_filteredItems.length} artículos',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: _refreshData,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.white,
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF2D8A8A)),
            SizedBox(height: 16),
            Text('Cargando artículos...'),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorOverlay() {
    return Container(
      color: Colors.white,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error: $_errorMessage'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _refreshData,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

// Filter Dialog Widget
class _FilterDialog extends StatefulWidget {
  final Set<String> selectedStatuses;
  final String sortBy;
  final Function(Set<String>, String) onApply;

  const _FilterDialog({
    required this.selectedStatuses,
    required this.sortBy,
    required this.onApply,
  });

  @override
  State<_FilterDialog> createState() => _FilterDialogState();
}

class _FilterDialogState extends State<_FilterDialog> {
  late Set<String> _tempStatuses;
  late String _tempSort;

  @override
  void initState() {
    super.initState();
    _tempStatuses = Set.from(widget.selectedStatuses);
    _tempSort = widget.sortBy;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Filtrar Artículos',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          const Text('Estados:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              _buildStatusChip('Publicados', 'publicados', Colors.blue),
              _buildStatusChip('En Espera', 'en_espera', Colors.purple),
              _buildStatusChip('Sin Asignar', 'sin_asignar', Colors.amber),
              _buildStatusChip('En Proceso', 'en_proceso', Colors.orange),
              _buildStatusChip('Recogidos', 'recogidos', Colors.green),
              _buildStatusChip('Vencidos', 'vencidos', Colors.red),
            ],
          ),
          const SizedBox(height: 20),
          const Text('Ordenar por:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          DropdownButton<String>(
            value: _tempSort,
            isExpanded: true,
            items: const [
              DropdownMenuItem(value: 'recent', child: Text('Más recientes')),
              DropdownMenuItem(value: 'oldest', child: Text('Más antiguos')),
              DropdownMenuItem(value: 'status', child: Text('Por estado')),
            ],
            onChanged: (value) {
              setState(() {
                _tempSort = value!;
              });
            },
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    widget.onApply(_tempStatuses, _tempSort);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2D8A8A),
                  ),
                  child: const Text('Aplicar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String label, String value, Color color) {
    final isSelected = _tempStatuses.contains(value);
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          if (selected) {
            _tempStatuses.add(value);
          } else {
            _tempStatuses.remove(value);
          }
        });
      },
      selectedColor: color.withOpacity(0.3),
      checkmarkColor: color,
    );
  }
}

// Assign Employee Dialog Widget
class _AssignEmployeeDialog extends StatelessWidget {
  final RecyclingItem item;
  final List<Map<String, dynamic>> employees;
  final Function(int) onAssign;

  const _AssignEmployeeDialog({
    required this.item,
    required this.employees,
    required this.onAssign,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Asignar Empleado',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          Text('Artículo: ${item.title}'),
          const SizedBox(height: 20),
          const Text('Selecciona un empleado:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          if (employees.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text('No hay empleados disponibles'),
              ),
            )
          else
            ...employees.map((employee) {
              final user = employee['users'] as Map<String, dynamic>?;
              final name = user?['names'] ?? 'Empleado';
              final email = user?['email'] ?? '';
              
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFF2D8A8A),
                  child: Text(name[0].toUpperCase()),
                ),
                title: Text(name),
                subtitle: Text(email),
                onTap: () {
                  onAssign(employee['employeeId'] as int);
                  Navigator.pop(context);
                },
              );
            }).toList(),
        ],
      ),
    );
  }
}

// Company Article Modal Widget
class _CompanyArticleModal extends StatefulWidget {
  final RecyclingItem item;
  final MediaDatabase mediaDatabase;
  final VoidCallback onAssignEmployee;
  final Function(RecyclingItem) onNavigateToDetails;

  const _CompanyArticleModal({
    required this.item,
    required this.mediaDatabase,
    required this.onAssignEmployee,
    required this.onNavigateToDetails,
  });

  @override
  State<_CompanyArticleModal> createState() => _CompanyArticleModalState();
}

class _CompanyArticleModalState extends State<_CompanyArticleModal> {
  Multimedia? currentPhoto;
  bool isLoadingPhoto = false;

  @override
  void initState() {
    super.initState();
    _loadPhoto();
  }

  Future<void> _loadPhoto() async {
    setState(() {
      isLoadingPhoto = true;
    });
    
    try {
      final photo = await widget.mediaDatabase.getMainPhotoByPattern('articles/${widget.item.id}');
      if (mounted) {
        setState(() {
          currentPhoto = photo;
          isLoadingPhoto = false;
        });
      }
    } catch (e) {
      print('❌ Error fetching photo: $e');
      if (mounted) {
        setState(() {
          isLoadingPhoto = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 6,
            width: 50,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                Text(
                  widget.item.title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                
                // Category
                Row(
                  children: [
                    Icon(
                      CategoryUtils.getCategoryIcon(widget.item.categoryName),
                      size: 20,
                      color: const Color(0xFF2D8A8A),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.item.categoryName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF2D8A8A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                
                // Condition
                if (widget.item.condition != null)
                  Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Text(
                        'Condición: ${widget.item.condition}',
                        style: TextStyle(color: Colors.grey[700], fontSize: 14),
                      ),
                    ],
                  ),
                if (widget.item.condition != null) const SizedBox(height: 8),
                
                // Description
                if (widget.item.description != null)
                  Text(
                    widget.item.description!,
                    style: TextStyle(color: Colors.grey[600]),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (widget.item.description != null) const SizedBox(height: 12),
                
                // Divider
                Divider(color: Colors.grey[300]),
                const SizedBox(height: 12),
                
                // Owner info
                Row(
                  children: [
                    Icon(Icons.person_outline, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Propietario: ${widget.item.userName}',
                        style: TextStyle(color: Colors.grey[700], fontSize: 14),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                
                // Location
                Row(
                  children: [
                    Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.item.address,
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                
                // Availability
                Row(
                  children: [
                    Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${widget.item.availableDays} • ${widget.item.availableTimeStart} - ${widget.item.availableTimeEnd}',
                        style: TextStyle(color: Colors.grey[700], fontSize: 14),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                
                // Action buttons
                Row(
                  children: [
                    // View Details button
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          widget.onNavigateToDetails(widget.item);
                        },
                        icon: const Icon(Icons.info_outline),
                        label: const Text('Ver Detalles'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF2D8A8A),
                          side: const BorderSide(color: Color(0xFF2D8A8A)),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Assign Employee button
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: widget.onAssignEmployee,
                        icon: const Icon(Icons.person_add),
                        label: const Text('Asignar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2D8A8A),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
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


