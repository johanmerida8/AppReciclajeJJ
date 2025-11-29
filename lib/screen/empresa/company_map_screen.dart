import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
import 'package:reciclaje_app/components/schedule_pickup_dialog.dart'; // ✅ Add schedule dialog import
import 'package:reciclaje_app/widgets/status_indicator.dart'; // ✅ Add StatusIndicators widget
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  
  // ✅ Track requests and tasks by article ID for status determination
  Map<int, Request> _requestsByArticleId = {}; // articleID -> Request
  Map<int, Map<String, dynamic>> _tasksByArticleId = {}; // articleID -> Task data
  
  // Filter states
  Set<String> _selectedStatuses = {'publicados', 'en_espera', 'sin_asignar', 'en_proceso', 'recogidos', 'vencidos'};
  String _sortBy = 'recent'; // 'recent', 'oldest', 'status'
  
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
  bool _isConnected = true;
  bool _hasLocationPermission = false;
  bool _isLocationServiceEnabled = false;
  bool _hasCheckedLocation = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // ✅ Clear cached data to prevent memory leaks
    _allItems.clear();
    _filteredItems.clear();
    _employees.clear();
    _requestsByArticleId.clear();
    _tasksByArticleId.clear();
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
    await _loadRequestsAndTasks(); // ✅ Load requests and tasks for status tracking
    await _loadApprovedRequestCount(); // ✅ Load notification count
    
    // ✅ Show map immediately after basic data loads
    if (mounted) {
      setState(() => _isLoading = false);
    }
    
    await _checkLocationServices();
    
    if (_isLocationServiceEnabled && _hasLocationPermission) {
      await _loadUserLocation();
    }
    
    // ✅ Load articles after map is ready (deferred for faster initial render)
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _loadData();
      }
    });
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

  /// ✅ Load all requests and tasks for this company to determine article statuses
  Future<void> _loadRequestsAndTasks() async {
    if (_companyId == null) {
      print('⚠️ Cannot load requests and tasks: _companyId is null');
      return;
    }
    
    print('🔍 Loading requests and tasks for company ID: $_companyId');
    
    try {
      // Load all requests for this company
      final requests = await Supabase.instance.client
          .from('request')
          .select('*')
          .eq('companyID', _companyId!)
          .eq('state', 1);
      
      print('📥 Received ${requests.length} requests from database');
      
      // Load all tasks for this company
      final tasks = await Supabase.instance.client
          .from('tasks')
          .select('*')
          .eq('companyID', _companyId!)
          .eq('state', 1);
      
      print('📥 Received ${tasks.length} tasks from database');
      
      if (mounted) {
        setState(() {
          // Map requests by article ID
          _requestsByArticleId = {};
          for (var req in requests) {
            final articleId = req['articleID'] as int?;
            if (articleId != null) {
              _requestsByArticleId[articleId] = Request.fromMap(req);
            }
          }
          
          // Map tasks by article ID
          _tasksByArticleId = {};
          for (var task in tasks) {
            final articleId = task['articleID'] as int?;
            if (articleId != null) {
              _tasksByArticleId[articleId] = task;
            }
          }
        });
        
        print('✅ Loaded ${_requestsByArticleId.length} requests and ${_tasksByArticleId.length} tasks for company');
      }
    } catch (e) {
      print('❌ Error loading requests and tasks: $e');
    }
  }

  /// ✅ Load count of approved requests for company
  Future<void> _loadApprovedRequestCount() async {
    if (_companyId == null) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final readNotifications = prefs.getStringList('read_company_notifications') ?? [];
      
      final approvedRequests = await Supabase.instance.client
          .from('request')
          .select('idRequest')
          .eq('companyID', _companyId!)
          .eq('status', 'aprobado');
      
      // Filter out read notifications
      final unreadRequests = (approvedRequests as List).where((req) {
        final requestId = req['idRequest'].toString();
        return !readNotifications.contains(requestId);
      }).toList();
      
      if (mounted) {
        setState(() {
          _approvedRequestCount = unreadRequests.length;
        });
      }
      print('📊 Unread approved requests: ${unreadRequests.length} out of ${approvedRequests.length} total');
    } catch (e) {
      print('❌ Error loading approved request count: $e');
    }
  }

  Future<void> _loadData({bool forceRefresh = false}) async {
    // ✅ Don't change loading state - keep map visible
    
    if (!forceRefresh && await _loadFromCache()) {
      _loadFreshDataInBackground();
      return;
    }

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

      if (!mounted) return;
      
      print('📦 Found ${items.length} items to load progressively');

      // ✅ Load items in batches of 10 for smooth progressive rendering
      const batchSize = 10;
      final allItems = <RecyclingItem>[];
      
      for (var i = 0; i < items.length; i += batchSize) {
        if (!mounted) break;
        
        final batch = items.skip(i).take(batchSize).toList();
        allItems.addAll(batch);
        
        // ✅ Update UI with each batch
        if (mounted) {
          setState(() {
            _allItems = List.from(allItems);
            _applyFilters();
            _hasError = false;
            _isLoading = false;
          });
          print('✅ Loaded batch: ${allItems.length}/${items.length} items');
        }
        
        // Small delay between batches for smooth rendering
        if (i + batchSize < items.length) {
          await Future.delayed(const Duration(milliseconds: 80));
        }
      }

      // Save cache after all items loaded
      await _cacheService.saveCache(items, categories, _currentUserId);
      print('✅ Finished loading ${items.length} items');

      if (mounted && _filteredItems.isNotEmpty) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) _fitMapToShowAllArticles();
        });
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
    
    if (mounted) {
      setState(() {
        _isLocationServiceEnabled = status['serviceEnabled'] ?? false;
        _hasLocationPermission = status['hasPermission'] ?? false;
        _hasCheckedLocation = true;
      });
    }
  }

  void _applyFilters() {
    print('🔍 Applying filters...');
    print('   Selected statuses: $_selectedStatuses');
    print('   Sort by: $_sortBy');
    print('   Total items: ${_allItems.length}');
    
    List<RecyclingItem> filtered = List.from(_allItems);
    
    // ✅ DON'T filter by company - show ALL articles like distributor
    // Companies can see all published articles to assign to their employees
    
    // Filter by selected statuses
    filtered = filtered.where((item) {
      final status = _getItemStatus(item);
      return _selectedStatuses.contains(status);
    }).toList();
    
    print('   After status filter: ${filtered.length} items');
    
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
    
    print('✅ Filters applied: ${_filteredItems.length} items displayed');
  }

  String _getItemStatus(RecyclingItem item) {
    // Check if there's a task for this article (most recent status)
    final task = _tasksByArticleId[item.id];
    if (task != null) {
      final taskStatus = task['workflowStatus'] as String?;
      if (taskStatus == 'completado') return 'recogidos'; // ✅ Completed
      if (taskStatus == 'en_proceso') return 'en_proceso'; // ✅ Employee working
      if (taskStatus == 'asignado') return 'en_proceso'; // ✅ Employee assigned (treat as en_proceso)
      // If task has employee assigned but unknown status, treat as en_proceso
      final employeeId = task['employeeID'] as int?;
      if (employeeId != null) return 'en_proceso';
      // Task exists but no employee assigned yet
      return 'sin_asignar';
    }
    
    // Check if there's a request for this article
    final request = _requestsByArticleId[item.id];
    if (request != null) {
      // If request is approved, company needs to assign employee
      if (request.status == 'aprobado') return 'sin_asignar';
      // If request is rejected, article goes back to published
      if (request.status == 'rechazado') return 'publicados';
      // Otherwise it's waiting for distributor approval
      return 'en_espera';
    }
    
    // Check article's workflow status as fallback
    final status = item.workflowStatus?.toLowerCase();
    if (status == 'vencido') return 'vencidos';
    
    // No request, no task - article is just published
    return 'publicados';
  }

  Future<void> _refreshData() async {
    setState(() => _isLoading = true);
    
    try {
      await _cacheService.clearCache();
      await _loadData(forceRefresh: true);
      await _loadEmployees();
      await _loadRequestsAndTasks(); // ✅ Refresh requests and tasks
      await _loadApprovedRequestCount(); // ✅ Refresh notification count

      final lastLocation = _locationService.lastKnownLocation ?? _userLocation;
      if (lastLocation != null) {
        Future.microtask(() {
          if (_mapService.isMapReady(_mapController)) {
            _mapController.move(lastLocation, _currentZoom);
          }
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
          if (mounted) {
            setState(() {
              _selectedStatuses = statuses;
              _sortBy = sort;
              _applyFilters();
            });
            print('✅ Filters applied: ${statuses.length} statuses, sort: $sort');
            print('   Filtered items: ${_filteredItems.length} of ${_allItems.length}');
          }
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
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text('Cancelar', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () async {
              // Store navigator and scaffold messenger references before async operations
              final navigator = Navigator.of(context);
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              
              // Close the confirmation dialog first
              navigator.pop();
              
              // ✅ Call _sendRequestToDistributor which will show schedule dialog
              try {
                await _sendRequestToDistributor(item);
                
                // Show success message
                scaffoldMessenger.showSnackBar(
                  const SnackBar(
                    content: Text('✅ Solicitud enviada al distribuidor'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 3),
                  ),
                );
                
                // Refresh data to update UI
                await _refreshData();
              } catch (e) {
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
            child: const Text('Continuar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _sendRequestToDistributor(RecyclingItem item) async {
    // Load daysAvailable data for this article
    List<Map<String, dynamic>>? daysAvailableData;
    try {
      final response = await Supabase.instance.client
          .from('daysAvailable')
          .select()
          .eq('articleID', item.id)
          .order('dateAvailable', ascending: true);
      
      daysAvailableData = response.cast<Map<String, dynamic>>();
    } catch (e) {
      print('❌ Error loading daysAvailable: $e');
    }

    // ✅ Show scheduling dialog to select day and time
    final scheduleData = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => SchedulePickupDialog(
        availableDays: item.availableDays,
        availableTimeStart: item.availableTimeStart,
        availableTimeEnd: item.availableTimeEnd,
        articleName: item.title,
        daysAvailableData: daysAvailableData,
      ),
    );

    if (scheduleData == null) return; // User cancelled

    try {
      // Parse time strings (HH:MM) and format as HH:MM:SS for database
      final startTimeParts = scheduleData['startTime']!.split(':');
      final startTimeFormatted = '${startTimeParts[0].padLeft(2, '0')}:${startTimeParts[1].padLeft(2, '0')}:00';
      
      final endTimeParts = scheduleData['endTime']!.split(':');
      final endTimeFormatted = '${endTimeParts[0].padLeft(2, '0')}:${endTimeParts[1].padLeft(2, '0')}:00';

      // Create request with status "pendiente" and scheduled time window
      final newRequest = Request(
        articleId: item.id,
        companyId: _companyId,
        status: 'pendiente',
        requestDate: DateTime.now(),
        scheduledDay: scheduleData['day'], // ✅ Add scheduled day
        scheduledStartTime: startTimeFormatted, // ✅ Add scheduled start time
        scheduledEndTime: endTimeFormatted, // ✅ Add scheduled end time
        state: 1, // Active
        lastUpdate: DateTime.now(),
      );

      await _requestDatabase.createRequest(newRequest);
      
      // Success - no need to refresh map as the request is on the distributor side
      print('✅ Request sent successfully to distributor with schedule: ${scheduleData['day']} between ${scheduleData['startTime']} - ${scheduleData['endTime']}');
    } catch (e) {
      print('❌ Error sending request: $e');
      rethrow; // Re-throw to handle in calling code
    }
  }

  /// ✅ Assign employee to approved request and update task
  Future<void> _assignArticleToEmployee(
    RecyclingItem item, 
    int employeeId, 
    Request approvedRequest,
  ) async {
    try {
      if (_companyId == null) {
        throw Exception('Company ID not found');
      }

      // ✅ Get existing task created by distributor with "sin_asignar" status
      final existingTask = await _taskDatabase.getTaskByRequestId(approvedRequest.id!);

      if (existingTask == null) {
        throw Exception('No se encontró la tarea para esta solicitud');
      }

      // ✅ Update task to assign employee and change status to "en_proceso"
      final updatedTask = Task(
        idTask: existingTask.idTask,
        employeeId: employeeId, // ✅ Assign employee
        articleId: item.id,
        companyId: _companyId,
        requestId: approvedRequest.id,
        assignedDate: existingTask.assignedDate,
        workflowStatus: 'en_proceso', // ✅ Employee starts working immediately
        state: 1,
        lastUpdate: DateTime.now(),
      );

      await _taskDatabase.updateTask(updatedTask);
      
      print('✅ Task updated successfully - Employee: $employeeId assigned and working on Article: ${item.id}');

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
        minZoom: 6.0,  // ✅ Prevent zooming out beyond Bolivia
        maxZoom: 18.0,
        // ✅ Disable map rotation
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
        cameraConstraint: CameraConstraint.contain(
          bounds: LatLngBounds(
            const LatLng(-22.9, -69.7), // Southwest corner of Bolivia
            const LatLng(-9.6, -57.4),   // Northeast corner of Bolivia
          ),
        ),
        onPositionChanged: (MapCamera position, bool hasGesture) {
          if (hasGesture) {
            setState(() {
              _currentZoom = position.zoom;
            });
          }
        }
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
      if (cluster.isSingleItem) {
        markers.add(_buildSingleMarker(cluster.items[0]));
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
          // ✅ Show navigation modal instead of expanding cluster
          _onClusterTap(cluster);
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
  
  /// ✅ Handle cluster tap - Show navigation modal
  void _onClusterTap(MarkerCluster cluster) {
    // Find the index of the first article in the cluster
    final firstItem = cluster.items[0];
    final index = _filteredItems.indexWhere((i) => i.id == firstItem.id);
    
    // Activate navigation and update index
    setState(() {
      _currentArticleIndex = index;
      _showArticleNavigation = true;
    });
    
    // ✅ Center map on the cluster
    if (_mapService.isMapReady(_mapController)) {
      _mapController.move(cluster.center, 16.0);
    }
    
    // Show modal with navigation through the cluster's articles
    _showClusterNavigationModal(cluster);
    
    print('📦 Cluster tapped - ${cluster.count} articles to navigate');
  }
  
  /// ✅ Modal for navigating through clustered articles
  void _showClusterNavigationModal(MarkerCluster cluster) {
    if (!mounted) return;

    final clusterItems = cluster.items;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      builder: (context) => _CompanyArticleNavigationModal(
        articles: clusterItems,
        initialIndex: 0,
        mediaDatabase: _mediaDatabase,
        onAssignEmployee: (item) {
          Navigator.pop(context);
          _showSendRequestDialog(item);
        },
        onAssignEmployeeApproved: (article, request) {
          Navigator.pop(context);
          _showAssignEmployeeDialogWithRequest(article, request);
        },
        onNavigateToDetails: (article) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DetailRecycleScreen(item: article),
            ),
          );
        },
        onArticleChange: (article) {
          // Update map position when navigating
          if (_mapService.isMapReady(_mapController)) {
            _mapController.move(LatLng(article.latitude, article.longitude), 16.0);
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

  void _onMarkerTap(RecyclingItem item) {
    final index = _filteredItems.indexWhere((i) => i.id == item.id);
    
    // ✅ Find nearby articles within 300 meters
    final nearbyArticles = _findNearbyArticles(item, maxDistance: 300.0);
    
    setState(() {
      _currentArticleIndex = index;
      _showArticleNavigation = true;
    });
    
    if (_mapService.isMapReady(_mapController)) {
      _mapController.move(LatLng(item.latitude, item.longitude), 16.0);
    }
    
    // ✅ Show navigation modal if multiple articles nearby, otherwise single modal
    if (nearbyArticles.length > 1) {
      _showArticleNavigationModal(nearbyArticles, item);
    } else {
      _showArticleDetailModal(item);
    }
  }
  
  /// ✅ Find articles near the given article
  List<RecyclingItem> _findNearbyArticles(RecyclingItem item, {required double maxDistance}) {
    List<RecyclingItem> nearbyArticles = [item]; // Include current article
    
    for (var otherItem in _filteredItems) {
      if (otherItem.id == item.id) continue; // Skip same article
      
      final distance = _calculateDistance(
        item.latitude,
        item.longitude,
        otherItem.latitude,
        otherItem.longitude,
      );
      
      if (distance <= maxDistance) {
        nearbyArticles.add(otherItem);
      }
    }
    
    return nearbyArticles;
  }
  
  /// ✅ Calculate distance between two points in meters (Haversine formula)
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
  
  /// ✅ Show article navigation modal (with anterior/siguiente buttons)
  void _showArticleNavigationModal(List<RecyclingItem> articles, RecyclingItem currentItem) {
    if (!mounted) return;

    final currentIndex = articles.indexWhere((a) => a.id == currentItem.id);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      builder: (context) => _CompanyArticleNavigationModal(
        articles: articles,
        initialIndex: currentIndex,
        mediaDatabase: _mediaDatabase,
        onAssignEmployee: (item) {
          Navigator.pop(context);
          _showSendRequestDialog(item);
        },
        onAssignEmployeeApproved: (article, request) {
          Navigator.pop(context);
          _showAssignEmployeeDialogWithRequest(article, request);
        },
        onNavigateToDetails: (article) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DetailRecycleScreen(item: article),
            ),
          );
        },
        onArticleChange: (article) {
          // Update map position when navigating
          if (_mapService.isMapReady(_mapController)) {
            _mapController.move(LatLng(article.latitude, article.longitude), 16.0);
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
            onPressed: _showLocationMenu,
            backgroundColor: const Color(0xFF2D8A8A),
            child: const Icon(Icons.my_location, color: Colors.white),
          ),
        ],
      ),
    );
  }

  /// ✅ Mostrar menú de opciones de ubicación
  void _showLocationMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.location_on, color: Color(0xFF2D8A8A)),
                const SizedBox(width: 12),
                const Text(
                  'Opciones de Ubicación',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D8A8A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFF2D8A8A),
                child: Icon(Icons.my_location, color: Colors.white),
              ),
              title: const Text(
                'Ir a mi ubicación',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text('Centrar mapa en mi posición actual'),
              onTap: () {
                Navigator.pop(context);
                _goToUserLocation();
              },
            ),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: const Color(0xFF2D8A8A),
                child: Icon(
                  _showUserMarker ? Icons.visibility : Icons.visibility_off,
                  color: Colors.white,
                ),
              ),
              title: const Text(
                'Ocultar mi marcador',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text('El marcador azul desaparecerá del mapa'),
              trailing: Switch(
                value: _showUserMarker,
                onChanged: (value) {
                  setState(() {
                    _showUserMarker = value;
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        _showUserMarker 
                            ? '✅ Marcador visible' 
                            : '❌ Marcador oculto'
                      ),
                      duration: const Duration(seconds: 1),
                      backgroundColor: _showUserMarker ? Colors.green : Colors.grey,
                    ),
                  );
                },
                activeColor: const Color(0xFF2D8A8A),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  /// ✅ Ir a la ubicación del usuario
  Future<void> _goToUserLocation() async {
    // ✅ Primero verificar el estado del GPS
    await _checkLocationServices();
    
    // Si GPS está deshabilitado o sin permisos, mostrar diálogo de habilitación
    if (!_isLocationServiceEnabled || !_hasLocationPermission) {
      _showEnableLocationDialog();
      return;
    }
    
    if (_hasUserLocation && _userLocation != null) {
      // Ya tenemos la ubicación, solo centrar el mapa
      if (_mapService.isMapReady(_mapController)) {
        _mapController.move(_userLocation!, 16.0);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📍 Centrado en tu ubicación'),
            duration: Duration(seconds: 1),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      // No tenemos ubicación, intentar obtenerla
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📍 Obteniendo tu ubicación...'),
            duration: Duration(seconds: 2),
            backgroundColor: Color(0xFF2D8A8A),
          ),
        );
      }
      
      await _loadUserLocation();
      
      if (_hasUserLocation && _userLocation != null && mounted) {
        if (_mapService.isMapReady(_mapController)) {
          _mapController.move(_userLocation!, 16.0);
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Ubicación encontrada'),
            duration: Duration(seconds: 1),
            backgroundColor: Colors.green,
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ No se pudo obtener la ubicación'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// ✅ Mostrar diálogo para activar ubicación
  void _showEnableLocationDialog() {
    if (!mounted || ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2D8A8A).withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.location_on,
                  color: Color(0xFF2D8A8A),
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Habilitar ubicación',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Para una mejor experiencia, tu dispositivo necesita usar la ubicación.',
                style: TextStyle(fontSize: 15, height: 1.4),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green.shade600, size: 20),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Ver tu ubicación en el mapa',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green.shade600, size: 20),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Asignar tareas a empleados cercanos',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (!_isLocationServiceEnabled) ...[
                const SizedBox(height: 12),
                Text(
                  '⚠️ GPS está desactivado',
                  style: TextStyle(
                    color: Colors.orange.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              if (!_hasLocationPermission) ...[
                const SizedBox(height: 12),
                Text(
                  '⚠️ Permisos de ubicación no otorgados',
                  style: TextStyle(
                    color: Colors.orange.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                print('❌ Usuario rechazó activar ubicación');
              },
              child: Text(
                'No, gracias',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                print('✅ Usuario quiere activar ubicación');
                
                // ✅ Solicitar servicio de GPS primero
                if (!_isLocationServiceEnabled) {
                  final serviceEnabled = await _locationService.requestLocationService();
                  if (!serviceEnabled) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('⚠️ GPS no activado. Por favor, activa el GPS manualmente'),
                          duration: Duration(seconds: 3),
                          backgroundColor: Colors.orange,
                        ),
                      );
                    }
                    return;
                  }
                }
                
                // ✅ Solicitar permisos de ubicación
                if (!_hasLocationPermission) {
                  final permissionGranted = await _locationService.requestLocationPermission();
                  if (!permissionGranted) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('⚠️ Permisos denegados. Por favor, otorga permisos de ubicación'),
                          duration: Duration(seconds: 3),
                          backgroundColor: Colors.orange,
                        ),
                      );
                    }
                    return;
                  }
                }
                
                // Verificar estado actualizado
                await _checkLocationServices();
                
                // Intentar cargar ubicación
                if (_isLocationServiceEnabled && _hasLocationPermission) {
                  await _loadUserLocation();
                  
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✅ Ubicación activada correctamente'),
                        duration: Duration(seconds: 2),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2D8A8A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Activar'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTopBar() {
    // Count only published articles (excluding completed tasks)
    final publishedCount = _filteredItems.where((item) {
      final status = _getItemStatus(item);
      return status != 'recogidos'; // Exclude completed/recogidos
    }).length;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                // Status indicators below
                StatusIndicators(
                  isDeviceConnected: _isConnected,
                  isLocationServiceEnabled: _isLocationServiceEnabled,
                  hasLocationPermission: _hasLocationPermission,
                  hasCheckedLocation: _hasCheckedLocation,
                  onGpsTap: _checkLocationServices,
                  onRefreshTap: _refreshData,
                  notificationCount: _approvedRequestCount,
                  onNotificationTap: _navigateToNotifications,
                ),
                const SizedBox(height: 8),
                // Article count at the top
                Text(
                  'Total $publishedCount artículos',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    shadows: [
                      Shadow(
                        color: Colors.black87,
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
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
            Text(
              'Cargando mapa...',
              style: TextStyle(color: Color(0xFF2D8A8A), fontSize: 16),
            ),
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
    final startTime = widget.approvedRequest.scheduledStartTime;
    final endTime = widget.approvedRequest.scheduledEndTime;
    final formattedStartTime = startTime != null ? _formatTime(startTime) : 'No especificado';
    final formattedEndTime = endTime != null ? _formatTime(endTime) : 'No especificado';

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
                  'Horario: $formattedStartTime - $formattedEndTime',
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
  Map<String, dynamic>? _existingTask; // ✅ Track task status
  bool _isLoadingTask = false; // ✅ Loading task status

  @override
  void initState() {
    super.initState();
    _loadPhoto();
    _loadRequestStatus(); // ✅ Load request status (this will also load task status)
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
            
            // ✅ Load task status after we have companyId
            await _loadTaskStatus();
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

  /// ✅ Load task status for this article
  Future<void> _loadTaskStatus() async {
    if (_isLoadingTask) return; // Prevent duplicate calls
    setState(() => _isLoadingTask = true);

    try {
      if (_companyId != null) {
        final existingTask = await Supabase.instance.client
            .from('tasks')
            .select()
            .eq('articleID', widget.item.id)
            .eq('companyID', _companyId!)
            .order('assignedDate', ascending: false)
            .limit(1)
            .maybeSingle();

        if (existingTask != null && mounted) {
          setState(() {
            _existingTask = existingTask;
          });
          print('✅ Found task for article ${widget.item.id}: ${existingTask['workflowStatus']}');
        } else {
          print('ℹ️ No task found for article ${widget.item.id}');
        }
      }
    } catch (e) {
      print('❌ Error loading task status: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingTask = false);
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
                
                // ✅ Task status badge (similar to employee view in detail_recycle_screen)
                if (_existingTask != null && _existingTask!['workflowStatus'] != null) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: _existingTask!['workflowStatus'] == 'completado' 
                          ? Colors.green.shade50 
                          : Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _existingTask!['workflowStatus'] == 'completado' 
                            ? Colors.green.shade200 
                            : Colors.amber.shade200
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _existingTask!['workflowStatus'] == 'completado' 
                                ? Colors.green 
                                : Colors.amber,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            _existingTask!['workflowStatus'] == 'completado'
                                ? Icons.check_circle_outline
                                : Icons.work_outline,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _existingTask!['workflowStatus'] == 'completado'
                                    ? 'Completado'
                                    : 'En Proceso',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: _existingTask!['workflowStatus'] == 'completado' 
                                      ? Colors.green 
                                      : Colors.amber,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _existingTask!['workflowStatus'] == 'completado'
                                    ? 'Esta tarea ha sido completada'
                                    : 'Esta tarea está en progreso',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                
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

  /// ✅ Build action button based on request status and task status
  Widget _buildActionButton() {
    // ✅ Check if task exists and is assigned
    if (_existingTask != null) {
      final workflowStatus = _existingTask!['workflowStatus'] as String?;
      
      if (workflowStatus == 'completado') {
        // Task completed - show completed status (disabled)
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green.withOpacity(0.3)),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 20),
              SizedBox(width: 8),
              Text(
                'Completado',
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      } else {
        // Task in progress - show en proceso status (disabled)
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: Colors.amber.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.amber.withOpacity(0.3)),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.work_outline, color: Colors.amber, size: 20),
              SizedBox(width: 8),
              Text(
                'En Proceso',
                style: TextStyle(
                  color: Colors.amber,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      }
    }
    
    // No task assigned yet - check request status
    if (_existingRequest == null) {
      // No request exists - show "Solicitar" button
      return ElevatedButton.icon(
        onPressed: widget.onAssignEmployee,
        icon: const Icon(Icons.send),
        label: const Text(
          'Solicitar',
          style: TextStyle(
            color: Colors.white,
          ),
        ),
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
      label: const Text(
        'Solicitar',
        style: TextStyle(
          color: Colors.white,
        ),
      ),
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

// ============================================================================
// Company Article Navigation Modal Widget (with Anterior/Siguiente buttons)
// ============================================================================

class _CompanyArticleNavigationModal extends StatefulWidget {
  final List<RecyclingItem> articles;
  final int initialIndex;
  final MediaDatabase mediaDatabase;
  final Function(RecyclingItem) onAssignEmployee;
  final Function(RecyclingItem, Request) onAssignEmployeeApproved;
  final Function(RecyclingItem) onNavigateToDetails;
  final Function(RecyclingItem) onArticleChange;

  const _CompanyArticleNavigationModal({
    required this.articles,
    required this.initialIndex,
    required this.mediaDatabase,
    required this.onAssignEmployee,
    required this.onAssignEmployeeApproved,
    required this.onNavigateToDetails,
    required this.onArticleChange,
  });

  @override
  State<_CompanyArticleNavigationModal> createState() => _CompanyArticleNavigationModalState();
}

class _CompanyArticleNavigationModalState extends State<_CompanyArticleNavigationModal> {
  late int currentIndex;
  late RecyclingItem currentItem;
  Multimedia? currentPhoto;
  bool isLoadingPhoto = false;
  Request? _existingRequest;
  bool _isLoadingRequest = false;
  int? _companyId;
  Map<String, dynamic>? _existingTask;
  bool _isLoadingTask = false;

  @override
  void initState() {
    super.initState();
    currentIndex = widget.initialIndex;
    currentItem = widget.articles[currentIndex];
    _loadPhoto();
    _loadRequestStatus();
  }

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

  Future<void> _loadRequestStatus() async {
    setState(() => _isLoadingRequest = true);

    try {
      final email = AuthService().getCurrentUserEmail();
      if (email != null) {
        final userData = await UsersDatabase().getUserByEmail(email);
        if (userData != null) {
          final companyData = await Supabase.instance.client
              .from('company')
              .select('idCompany')
              .eq('adminUserID', userData.id!)
              .maybeSingle();

          if (companyData != null) {
            _companyId = companyData['idCompany'] as int;

            final requestData = await Supabase.instance.client
                .from('request')
                .select('*')
                .eq('articleID', currentItem.id)
                .eq('companyID', _companyId!)
                .maybeSingle();

            if (requestData != null && mounted) {
              _existingRequest = Request.fromMap(requestData);
              
              if (_existingRequest!.status == 'aprobado') {
                await _loadTaskStatus();
              }
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

  Future<void> _loadTaskStatus() async {
    if (_isLoadingTask) return;
    setState(() => _isLoadingTask = true);

    try {
      final taskData = await Supabase.instance.client
          .from('tasks')
          .select('*')
          .eq('articleID', currentItem.id)
          .eq('companyID', _companyId!)
          .maybeSingle();

      if (mounted && taskData != null) {
        setState(() {
          _existingTask = taskData;
        });
      }
    } catch (e) {
      print('❌ Error loading task status: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingTask = false);
      }
    }
  }

  void _goToPrevious() {
    if (currentIndex > 0) {
      setState(() {
        currentIndex--;
        currentItem = widget.articles[currentIndex];
        currentPhoto = null;
        _existingRequest = null;
        _existingTask = null;
      });
      _loadPhoto();
      _loadRequestStatus();
      widget.onArticleChange(currentItem);
    }
  }

  void _goToNext() {
    if (currentIndex < widget.articles.length - 1) {
      setState(() {
        currentIndex++;
        currentItem = widget.articles[currentIndex];
        currentPhoto = null;
        _existingRequest = null;
        _existingTask = null;
      });
      _loadPhoto();
      _loadRequestStatus();
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
            margin: const EdgeInsets.symmetric(vertical: 10),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Navigation header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: currentIndex > 0 ? _goToPrevious : null,
                  icon: const Icon(Icons.arrow_back),
                  color: currentIndex > 0 ? const Color(0xFF2D8A8A) : Colors.grey,
                ),
                Text(
                  '${currentIndex + 1} de ${widget.articles.length}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D8A8A),
                  ),
                ),
                IconButton(
                  onPressed: currentIndex < widget.articles.length - 1 ? _goToNext : null,
                  icon: const Icon(Icons.arrow_forward),
                  color: currentIndex < widget.articles.length - 1 ? const Color(0xFF2D8A8A) : Colors.grey,
                ),
              ],
            ),
          ),
          
          const Divider(height: 1),
          
          // Article content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Photo
                  if (isLoadingPhoto)
                    _buildPlaceholder()
                  else if (currentPhoto != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl: currentPhoto!.url ?? '',
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => _buildPlaceholder(),
                        errorWidget: (context, url, error) => _buildPlaceholder(),
                      ),
                    )
                  else
                    _buildPlaceholder(),
                  
                  const SizedBox(height: 16),
                  
                  // Title
                  Text(
                    currentItem.title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Category
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2D8A8A).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          CategoryUtils.getCategoryIcon(currentItem.categoryName),
                          size: 16,
                          color: const Color(0xFF2D8A8A),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          currentItem.categoryName,
                          style: const TextStyle(
                            color: Color(0xFF2D8A8A),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Description
                  if (currentItem.description != null && currentItem.description!.isNotEmpty) ...[
                    const Text(
                      'Descripción:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(currentItem.description!),
                    const SizedBox(height: 16),
                  ],
                  
                  // Info rows
                  _buildInfoRow(Icons.location_on, 'Ubicación', currentItem.address),
                  const SizedBox(height: 8),
                  _buildInfoRow(Icons.calendar_today, 'Publicado', 
                    '${currentItem.createdAt.day}/${currentItem.createdAt.month}/${currentItem.createdAt.year}'),
                  
                  const SizedBox(height: 20),
                  
                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => widget.onNavigateToDetails(currentItem),
                          icon: const Icon(Icons.info_outline),
                          label: const Text('Ver Detalles'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF2D8A8A),
                            side: const BorderSide(color: Color(0xFF2D8A8A)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Request/Assign button
                  SizedBox(
                    width: double.infinity,
                    child: _buildActionButton(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton() {
    if (_isLoadingRequest || _isLoadingTask) {
      return const Center(child: CircularProgressIndicator());
    }

    // ✅ Check if article itself has completed workflow status
    if (currentItem.workflowStatus?.toLowerCase() == 'completado') {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.green.withOpacity(0.3)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 20),
            SizedBox(width: 8),
            Text(
              'Artículo Completado',
              style: TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    // Check if task exists and is assigned
    if (_existingTask != null) {
      final workflowStatus = _existingTask!['workflowStatus'] as String?;
      
      if (workflowStatus == 'asignado' || workflowStatus == 'en_proceso') {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.withOpacity(0.3)),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.assignment_turned_in, color: Colors.blue, size: 20),
              SizedBox(width: 8),
              Text(
                'Artículo Asignado',
                style: TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      } else if (workflowStatus == 'completado') {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: Colors.teal.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.teal.withOpacity(0.3)),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.task_alt, color: Colors.teal, size: 20),
              SizedBox(width: 8),
              Text(
                'Completado',
                style: TextStyle(
                  color: Colors.teal,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      }
    }
    
    // No task assigned yet - check request status
    if (_existingRequest == null) {
      return ElevatedButton.icon(
        onPressed: () => widget.onAssignEmployee(currentItem),
        icon: const Icon(Icons.send, color: Colors.white),
        label: const Text(
          'Solicitar Artículo',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2D8A8A),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      );
    } else if (_existingRequest!.status == 'pendiente') {
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
      return ElevatedButton.icon(
        onPressed: () => widget.onAssignEmployeeApproved(currentItem, _existingRequest!),
        icon: const Icon(Icons.assignment_ind, color: Colors.white),
        label: const Text(
          'Asignar Empleado',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2D8A8A),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      );
    } else if (_existingRequest!.status == 'rechazado') {
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
    
    // Fallback
    return ElevatedButton.icon(
      onPressed: () => widget.onAssignEmployee(currentItem),
      icon: const Icon(Icons.send, color: Colors.white),
      label: const Text(
        'Solicitar Artículo',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
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
          CategoryUtils.getCategoryIcon(currentItem.categoryName),
          size: 60,
          color: Colors.grey[600],
        ),
      ),
    );
  }
}



