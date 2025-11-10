import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:reciclaje_app/auth/auth_service.dart';
import 'package:reciclaje_app/model/recycling_items.dart';
import 'package:reciclaje_app/model/request.dart';
import 'package:reciclaje_app/database/request_database.dart';
import 'package:reciclaje_app/database/users_database.dart'; // ✅ Add UsersDatabase
import 'package:reciclaje_app/database/task_database.dart'; // ✅ Add TaskDatabase
import 'package:reciclaje_app/model/task.dart'; // ✅ Add Task model
import 'package:reciclaje_app/services/cache_service.dart';
import 'package:reciclaje_app/services/location_service.dart';
import 'package:reciclaje_app/services/map_service.dart';
import 'package:reciclaje_app/database/media_database.dart';
import 'package:reciclaje_app/model/multimedia.dart';
import 'package:reciclaje_app/services/marker_cluster.dart';
import 'package:reciclaje_app/services/recycling_data.dart';
import 'package:reciclaje_app/utils/category_utils.dart';
import 'package:reciclaje_app/screen/distribuidor/detail_recycle_screen.dart';
import 'package:reciclaje_app/screen/empresa/company_notifications_screen.dart'; // ✅ Add import
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
  final _requestDatabase = RequestDatabase();
  final _taskDatabase = TaskDatabase(); // ✅ Add TaskDatabase

  // Controllers
  final _mapController = MapController();

  // State variables
  List<RecyclingItem> _allItems = [];
  List<RecyclingItem> _filteredItems = [];
  List<Map<String, dynamic>> _employees = [];
  int? _currentUserId;
  int? _companyId;
  int _approvedRequestCount = 0; // ✅ Notification count for approved requests
  
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
    await _loadApprovedRequestCount(); // ✅ Load notification count
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
          // Try to get company ID from empresa table (if user is admin-empresa)
          Map<String, dynamic>? companyData = await Supabase.instance.client
              .from('company')
              .select('idCompany')
              .eq('adminUserID', _currentUserId!)
              .maybeSingle();
          
          int? foundCompanyId;
          
          // If not found in empresa table, try employees table (if user is employee)
          if (companyData == null) {
            companyData = await Supabase.instance.client
                .from('employees')
                .select('companyID')
                .eq('userID', _currentUserId!)
                .maybeSingle();
            
            if (companyData != null) {
              foundCompanyId = companyData['companyID'] as int?;
            }
          } else {
            foundCompanyId = companyData['idCompany'] as int?;
          }
          
          if (foundCompanyId != null) {
            setState(() {
              _companyId = foundCompanyId;
            });
          }
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
          .select('idEmployee, userID, users:userID(names, email)')
          .eq('companyID', _companyId!);
      
      if (mounted) {
        setState(() {
          _employees = List<Map<String, dynamic>>.from(employees);
        });
        print('✅ Loaded ${_employees.length} employees');
      }
    } catch (e) {
      print('❌ Error loading employees: $e');
    }
  }

  /// ✅ Load count of approved requests for company
  Future<void> _loadApprovedRequestCount() async {
    if (_companyId == null) return;
    
    try {
      final approvedRequests = await Supabase.instance.client
          .from('request')
          .select('idRequest')
          .eq('companyID', _companyId!)
          .eq('status', 'aprobado');
      
      if (mounted) {
        setState(() {
          _approvedRequestCount = approvedRequests.length;
        });
      }
      print('✅ Loaded $_approvedRequestCount approved requests');
    } catch (e) {
      print('❌ Error loading approved request count: $e');
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

      if (mounted) {
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
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _hasError = true;
          _isLoading = false;
        });
      }
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
    if (status == 'solicitado') return 'en_espera'; // Request sent, waiting for distributor approval
    if (status == 'vencido') return 'vencidos';
    if (status == 'pendiente' || status == 'publicados') return 'publicados';
    
    return 'publicados';
  }

  Future<void> _refreshData() async {
    await _cacheService.clearCache();
    await _loadData(forceRefresh: true);
    await _loadEmployees();
    await _loadApprovedRequestCount(); // ✅ Refresh notification count

    final lastLocation = _locationService.lastKnownLocation ?? _userLocation;
    if (lastLocation != null) {
      Future.microtask(() {
        if (_mapService.isMapReady(_mapController)) {
          _mapController.move(lastLocation, _currentZoom);
        }
      });
    }
  }

  /// ✅ Navigate to company notifications screen
  Future<void> _navigateToNotifications() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CompanyNotificationsScreen(),
      ),
    );
    // Refresh count after returning from notifications
    await _loadApprovedRequestCount();
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

  /// ✅ Show employee assignment dialog (when request is approved)
  void _showAssignEmployeeDialogWithRequest(RecyclingItem item, Request approvedRequest) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        contentPadding: EdgeInsets.zero,
        content: _AssignEmployeeDialog(
          item: item,
          employees: _employees,
          approvedRequest: approvedRequest,
          onAssign: (employeeId) async {
            await _assignArticleToEmployee(item, employeeId, approvedRequest);
          },
        ),
      ),
    );
  }

  /// ✅ Show request dialog (when no request exists)
  void _showSendRequestDialog(RecyclingItem item) {
    // Changed from "Asignar" to "Solicitar"
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF2D8A8A).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send, color: Color(0xFF2D8A8A), size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Solicitar Artículo',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '¿Deseas enviar una solicitud al distribuidor para recoger este artículo?',
              style: TextStyle(fontSize: 15, color: Colors.grey[700]),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'El distribuidor recibirá una notificación y podrá aprobar o rechazar tu solicitud.',
                      style: TextStyle(fontSize: 13, color: Colors.blue[900]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () async {
              // Store navigator and scaffold messenger references before async operations
              final navigator = Navigator.of(context);
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              
              // Close the confirmation dialog first
              navigator.pop();
              
              // Show loading indicator
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF2D8A8A),
                  ),
                ),
              );
              
              // Send request
              try {
                await _sendRequestToDistributor(item);
                
                // Close loading indicator only
                navigator.pop(); // Close loading indicator
                
                // Show success message
                scaffoldMessenger.showSnackBar(
                  const SnackBar(
                    content: Text('✅ Solicitud enviada al distribuidor'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 3),
                  ),
                );
              } catch (e) {
                // Close loading indicator only
                navigator.pop(); // Close loading indicator
                
                // Show error message
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text('❌ Error: $e'),
                    backgroundColor: Colors.red,
                    duration: const Duration(seconds: 3),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2D8A8A),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Enviar Solicitud', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _sendRequestToDistributor(RecyclingItem item) async {
    try {
      // Create request with status "pendiente"
      final newRequest = Request(
        articleId: item.id,
        companyId: _companyId,
        status: 'pendiente',
        requestDate: DateTime.now(),
        state: 1, // Active
        lastUpdate: DateTime.now(),
      );

      await _requestDatabase.createRequest(newRequest);
      
      // Success - no need to refresh map as the request is on the distributor side
      print('✅ Request sent successfully to distributor');
    } catch (e) {
      print('❌ Error sending request: $e');
      rethrow; // Re-throw to handle in calling code
    }
  }

  /// ✅ Assign employee to approved request and create task
  Future<void> _assignArticleToEmployee(
    RecyclingItem item, 
    int employeeId, 
    Request approvedRequest,
  ) async {
    try {
      if (_companyId == null) {
        throw Exception('Company ID not found');
      }

      // Create task with requestID linking to the approved request
      final task = Task(
        employeeId: employeeId,
        articleId: item.id,
        companyId: _companyId,
        requestId: approvedRequest.id, // ✅ Link to request with schedule
        assignedDate: DateTime.now(),
        workflowStatus: 'asignado',
        state: 1,
        lastUpdate: DateTime.now(),
      );

      await _taskDatabase.createTask(task);
      
      print('✅ Task created successfully - Employee: $employeeId, Article: ${item.id}, Request: ${approvedRequest.id}');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Tarea asignada exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Refresh data
      await _loadApprovedRequestCount();
      await _loadData(forceRefresh: true);
    } catch (e) {
      print('❌ Error assigning employee: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error al asignar empleado: $e'),
            backgroundColor: Colors.red,
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
          _showSendRequestDialog(item);
        },
        onAssignEmployeeApproved: (article, request) {
          Navigator.pop(context);
          _showAssignEmployeeDialogWithRequest(article, request);
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
            // ✅ Notification bell with badge
            Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                  onPressed: _navigateToNotifications,
                  tooltip: 'Notificaciones',
                ),
                if (_approvedRequestCount > 0)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      child: Text(
                        _approvedRequestCount > 99 ? '99+' : '$_approvedRequestCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
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

// ✅ Assign Employee Dialog Widget with Schedule Confirmation
class _AssignEmployeeDialog extends StatefulWidget {
  final RecyclingItem item;
  final List<Map<String, dynamic>> employees;
  final Request approvedRequest;
  final Function(int) onAssign;

  const _AssignEmployeeDialog({
    required this.item,
    required this.employees,
    required this.approvedRequest,
    required this.onAssign,
  });

  @override
  State<_AssignEmployeeDialog> createState() => _AssignEmployeeDialogState();
}

class _AssignEmployeeDialogState extends State<_AssignEmployeeDialog> {
  String _formatTime(String timeStr) {
    try {
      final parts = timeStr.split(':');
      if (parts.length >= 2) {
        return '${parts[0]}:${parts[1]}';
      }
      return timeStr;
    } catch (e) {
      return timeStr;
    }
  }

  void _showConfirmationDialog(Map<String, dynamic> employee) {
    final user = employee['users'] as Map<String, dynamic>?;
    final name = user?['names'] ?? 'Empleado';
    
    final scheduledDay = widget.approvedRequest.scheduledDay ?? 'No especificado';
    final scheduledTime = widget.approvedRequest.scheduledTime != null
        ? _formatTime(widget.approvedRequest.scheduledTime!)
        : 'No especificado';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Asignación'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Asignar tarea a: $name',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.article, color: Color(0xFF2D8A8A), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.item.title,
                    style: const TextStyle(fontSize: 15),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.calendar_today, color: Color(0xFF2D8A8A), size: 20),
                const SizedBox(width: 8),
                Text(
                  'Día: $scheduledDay',
                  style: const TextStyle(fontSize: 15),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.access_time, color: Color(0xFF2D8A8A), size: 20),
                const SizedBox(width: 8),
                Text(
                  'Hora: $scheduledTime',
                  style: const TextStyle(fontSize: 15),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx); // Close confirmation dialog
              Navigator.pop(context); // Close employee list dialog
              final employeeId = employee['idEmployee'] as int?;
              if (employeeId != null) {
                widget.onAssign(employeeId);
              } else {
                print('❌ Error: employeeId is null');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2D8A8A),
            ),
            child: const Text('Asignar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
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
            'Asignar Empleado',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          Text('Artículo: ${widget.item.title}'),
          const SizedBox(height: 20),
          const Text('Selecciona un empleado:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          if (widget.employees.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text('No hay empleados disponibles'),
              ),
            )
          else
            ...widget.employees.map((employee) {
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
                onTap: () => _showConfirmationDialog(employee),
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
  final Function(RecyclingItem, Request) onAssignEmployeeApproved; // ✅ Add callback with request
  final Function(RecyclingItem) onNavigateToDetails;

  const _CompanyArticleModal({
    required this.item,
    required this.mediaDatabase,
    required this.onAssignEmployee,
    required this.onAssignEmployeeApproved,
    required this.onNavigateToDetails,
  });

  @override
  State<_CompanyArticleModal> createState() => _CompanyArticleModalState();
}

class _CompanyArticleModalState extends State<_CompanyArticleModal> {
  Multimedia? currentPhoto;
  bool isLoadingPhoto = false;
  Request? _existingRequest; // ✅ Track request status
  bool _isLoadingRequest = false; // ✅ Loading request status
  int? _companyId;

  @override
  void initState() {
    super.initState();
    _loadPhoto();
    _loadRequestStatus(); // ✅ Load request status
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

  /// ✅ Load request status for this article
  Future<void> _loadRequestStatus() async {
    setState(() => _isLoadingRequest = true);

    try {
      final authService = AuthService();
      final usersDatabase = UsersDatabase();
      final email = authService.getCurrentUserEmail();
      
      if (email != null) {
        final user = await usersDatabase.getUserByEmail(email);
        
        if (user != null) {
          // Get company ID
          var companyData = await Supabase.instance.client
              .from('company')
              .select('idCompany')
              .eq('adminUserID', user.id!)
              .limit(1)
              .maybeSingle();
          
          if (companyData == null) {
            companyData = await Supabase.instance.client
                .from('employees')
                .select('companyID')
                .eq('userID', user.id!)
                .limit(1)
                .maybeSingle();
            
            if (companyData != null) {
              _companyId = companyData['companyID'] as int?;
            }
          } else {
            _companyId = companyData['idCompany'] as int?;
          }

          // Check for existing request
          if (_companyId != null) {
            final existingRequest = await Supabase.instance.client
                .from('request')
                .select()
                .eq('articleID', widget.item.id)
                .eq('companyID', _companyId!)
                .order('lastUpdate', ascending: false)
                .limit(1)
                .maybeSingle();

            if (existingRequest != null && mounted) {
              setState(() {
                _existingRequest = Request.fromMap(existingRequest);
              });
            }
          }
        }
      }
    } catch (e) {
      print('❌ Error loading request status: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingRequest = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.70,
      ),
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
          Expanded(
            child: SingleChildScrollView(
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
                if (_isLoadingRequest)
                  const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF2D8A8A),
                    ),
                  )
                else
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
                      // Dynamic button based on request status
                      Expanded(
                        child: _buildActionButton(),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        ],
      ),
    );
  }

  /// ✅ Build action button based on request status
  Widget _buildActionButton() {
    if (_existingRequest == null) {
      // No request exists - show "Solicitar" button
      return ElevatedButton.icon(
        onPressed: widget.onAssignEmployee,
        icon: const Icon(Icons.send),
        label: const Text('Solicitar'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2D8A8A),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      );
    } else if (_existingRequest!.status == 'pendiente') {
      // Request is pending - show yellow "Pendiente" button (disabled)
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange.withOpacity(0.3)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.pending, color: Colors.orange, size: 20),
            SizedBox(width: 8),
            Text(
              'Solicitud Pendiente',
              style: TextStyle(
                color: Colors.orange,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    } else if (_existingRequest!.status == 'aprobado') {
      // Request approved - show green "Asignar Empleado" button
      return ElevatedButton.icon(
        onPressed: () => widget.onAssignEmployeeApproved(widget.item, _existingRequest!),
        icon: const Icon(Icons.assignment_ind),
        label: const Text('Asignar Empleado'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      );
    } else if (_existingRequest!.status == 'rechazado') {
      // Request rejected - show red "Rechazada" button (disabled)
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red.withOpacity(0.3)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cancel, color: Colors.red, size: 20),
            SizedBox(width: 8),
            Text(
              'Solicitud Rechazada',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }
    
    // Fallback - show default "Solicitar" button
    return ElevatedButton.icon(
      onPressed: widget.onAssignEmployee,
      icon: const Icon(Icons.send),
      label: const Text('Solicitar'),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF2D8A8A),
        padding: const EdgeInsets.symmetric(vertical: 16),
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


