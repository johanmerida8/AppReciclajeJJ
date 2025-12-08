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
import 'package:shared_preferences/shared_preferences.dart';

class EmployeeMapScreen extends StatefulWidget {
  const EmployeeMapScreen({super.key});

  @override
  State<EmployeeMapScreen> createState() => _EmployeeMapScreenState();
}

class _EmployeeMapScreenState extends State<EmployeeMapScreen>
    with WidgetsBindingObserver {
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
  bool _isConnected = true;
  bool _hasCheckedLocation = false;
  bool _userDismissedLocationDialog = false;
  int _pendingRequestCount = 0; // Notification count for new assigned tasks

  RealtimeChannel? _taskChannel; // ✅ Real-time listener for task updates

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
    _monitorConnection();
    _setupRealtimeListener(); // ✅ Setup real-time updates
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _taskChannel?.unsubscribe(); // ✅ Unsubscribe from real-time
    // ✅ Clear cached data to prevent memory leaks
    _assignedArticles.clear();
    _expandedClusters.clear();
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

  /// ✅ Setup real-time listener for task updates
  void _setupRealtimeListener() {
    _taskChannel =
        Supabase.instance.client
            .channel('employee-task-updates')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'tasks',
              callback: (payload) {
                print('🔔 Employee: Real-time task update received');
                _loadPendingTaskCount();
                _loadAssignedArticles();
              },
            )
            .subscribe();
  }

  /// Load pending task count for notifications
  Future<void> _loadPendingTaskCount() async {
    if (_employeeId == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final readNotifications =
          prefs.getStringList('read_employee_notifications') ?? [];

      // ✅ Check for 'en_proceso' tasks (when employee is assigned)
      final tasks = await Supabase.instance.client
          .from('tasks')
          .select('idTask')
          .eq('employeeID', _employeeId!)
          .eq('workflowStatus', 'en_proceso')
          .order('lastUpdate', ascending: false);

      // Filter out read notifications
      final unreadTasks =
          (tasks as List).where((task) {
            final taskId = task['idTask'].toString();
            return !readNotifications.contains(taskId);
          }).toList();

      if (mounted) {
        setState(() {
          _pendingRequestCount = unreadTasks.length;
        });
      }
      print(
        '📊 Unread tasks: ${unreadTasks.length} out of ${tasks.length} total',
      );
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
    // ✅ Show map UI immediately
    setState(() {
      _isLoading = false;
      _hasError = false;
    });

    try {
      final email = _authService.getCurrentUserEmail();
      if (email == null) throw Exception('No user email found');

      final user = await _usersDatabase.getUserByEmail(email);
      if (user == null) throw Exception('User not found');

      // Get employee ID
      final employeeData =
          await Supabase.instance.client
              .from('employees')
              .select('idEmployee')
              .eq('userID', user.id!)
              .maybeSingle();

      if (employeeData == null) throw Exception('Employee not found');

      _employeeId = employeeData['idEmployee'] as int;

      // ✅ Defer article loading - show map first
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          _loadAssignedArticles();
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
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
              condition,
              lastUpdate,
              category:categoryID(idCategory, name),
              user:userID(names, email)
            ),
            request:requestID(
              scheduledDay,
              scheduledStartTime,
              scheduledEndTime
            )
          ''')
          .eq('employeeID', _employeeId!)
          .inFilter('workflowStatus', ['asignado', 'en_proceso'])
          .order('assignedDate', ascending: false);

      if (!mounted) return;

      print('📦 Found ${tasks.length} tasks to load progressively');

      // ✅ Load articles in batches of 5 for smooth progressive rendering
      const batchSize = 5;
      final allArticles = <RecyclingItem>[];

      for (var i = 0; i < tasks.length; i += batchSize) {
        if (!mounted) break;

        final batch = tasks.skip(i).take(batchSize);
        final batchArticles = <RecyclingItem>[];

        for (var task in batch) {
          final article = task['article'] as Map<String, dynamic>?;
          final request = task['request'] as Map<String, dynamic>?;

          if (article != null) {
            final category = article['category'] as Map<String, dynamic>?;
            final user = article['user'] as Map<String, dynamic>?;

            // ✅ Check if task is vencido (overdue)
            String? workflowStatus = task['workflowStatus'] as String?;
            if (workflowStatus == 'asignado' ||
                workflowStatus == 'en_proceso') {
              if (request != null) {
                final scheduledDay = request['scheduledDay'] as String?;
                final scheduledEndTime = request['scheduledEndTime'] as String?;

                if (scheduledDay != null && scheduledEndTime != null) {
                  try {
                    final scheduledDate = DateTime.parse(scheduledDay);
                    final endTimeParts = scheduledEndTime.split(':');
                    final scheduledDateTime = DateTime(
                      scheduledDate.year,
                      scheduledDate.month,
                      scheduledDate.day,
                      int.parse(endTimeParts[0]),
                      int.parse(endTimeParts[1]),
                    );

                    if (DateTime.now().isAfter(scheduledDateTime)) {
                      workflowStatus = 'vencido';
                    }
                  } catch (e) {
                    print('Error checking vencido: $e');
                  }
                }
              }
            }

            batchArticles.add(
              RecyclingItem(
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
                condition: article['condition'] as String?,
                workflowStatus: workflowStatus,
                createdAt: DateTime.now(), // Use current time as fallback
              ),
            );
          }
        }

        // ✅ Update UI with each batch
        allArticles.addAll(batchArticles);
        if (mounted) {
          setState(() {
            _assignedArticles = List.from(allArticles);
          });
          print(
            '✅ Loaded batch: ${allArticles.length}/${tasks.length} articles',
          );
        }

        // Small delay between batches for smooth rendering
        if (i + batchSize < tasks.length) {
          await Future.delayed(const Duration(milliseconds: 100));
        }
      }

      print('✅ Finished loading ${allArticles.length} assigned articles');

      // Fit map to show all articles after loading complete
      if (mounted && _assignedArticles.isNotEmpty) {
        _fitMapToShowAllArticles();
      }
    } catch (e) {
      print('❌ Error loading assigned articles: $e');
      if (mounted) {
        setState(() {
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
    final wasEnabled = _isLocationServiceEnabled;
    final hadPermission = _hasLocationPermission;

    if (!mounted) return;

    setState(() {
      _isLocationServiceEnabled = status['serviceEnabled'] ?? false;
      _hasLocationPermission = status['hasPermission'] ?? false;
      _hasCheckedLocation = true;
    });

    print(
      '📊 Estado GPS - Servicio: $_isLocationServiceEnabled, Permisos: $_hasLocationPermission',
    );
    print(
      '📊 Estado anterior - Servicio: $wasEnabled, Permisos: $hadPermission',
    );

    // ✅ Si GPS se habilitó después del inicio, recargar ubicación
    if (_isLocationServiceEnabled && _hasLocationPermission) {
      if (!wasEnabled || !hadPermission) {
        print('🔄 GPS habilitado, recargando ubicación del usuario...');
        await _loadUserLocation();

        // ✅ Forzar rebuild del widget para mostrar el marcador
        if (mounted) {
          setState(() {});
        }
      }
    } else {
      // ✅ Si GPS se deshabilitó, limpiar ubicación
      if (wasEnabled || hadPermission) {
        print('⚠️ GPS deshabilitado, limpiando ubicación');
        if (!mounted) return;

        setState(() {
          _hasUserLocation = false;
          _userLocation = null;
        });
      }
    }
  }

  void _fitMapToShowAllArticles() {
    if (_assignedArticles.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No hay tareas asignadas para mostrar'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    _mapService.fitMapToShowAllArticles(
      _mapController,
      _assignedArticles,
      _userLocation,
      _hasUserLocation,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Mostrando ${_assignedArticles.length} tarea${_assignedArticles.length == 1 ? "" : "s"}',
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
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
                'Para ver tu ubicación en el mapa, necesitas activar los servicios de ubicación.',
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
                        Icon(
                          Icons.check_circle,
                          color: Colors.green.shade600,
                          size: 20,
                        ),
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
                        Icon(
                          Icons.check_circle,
                          color: Colors.green.shade600,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Navegar a las ubicaciones de tus tareas',
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
                setState(() {
                  _userDismissedLocationDialog = true;
                });
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
                  final serviceEnabled =
                      await _locationService.requestLocationService();
                  if (!serviceEnabled) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            '⚠️ GPS no activado. Por favor, activa el GPS manualmente',
                          ),
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
                  final permissionGranted =
                      await _locationService.requestLocationPermission();
                  if (!permissionGranted) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            '⚠️ Permisos denegados. Por favor, otorga permisos de ubicación',
                          ),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
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

  Future<void> _refreshData() async {
    setState(() => _isLoading = true);

    try {
      await _loadAssignedArticles();
      await _loadUserLocation();
      await _loadPendingTaskCount();
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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
        minZoom: 6.0, // ✅ Prevent zooming out beyond Bolivia
        maxZoom: 18.0,
        // ✅ Disable map rotation
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
        cameraConstraint: CameraConstraint.contain(
          bounds: LatLngBounds(
            const LatLng(-22.9, -69.7), // Southwest corner of Bolivia
            const LatLng(-9.6, -57.4), // Northeast corner of Bolivia
          ),
        ),
        onPositionChanged: (MapCamera position, bool hasGesture) {
          if (hasGesture) {
            setState(() {
              _currentZoom = position.zoom;
              if (position.zoom >= 14 || position.zoom < 12) {
                _expandedClusters.clear();
              }
            });
          }
        },
      ),
      children: [
        TileLayer(
          urlTemplate:
              'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
          subdomains: const ['a', 'b', 'c'],
        ),
        // ✅ User location marker with same style as distributor
        if (_showUserMarker && _hasUserLocation && _userLocation != null)
          MarkerLayer(markers: [MapMarkers.userLocationMarker(_userLocation!)]),
        if (_assignedArticles.isNotEmpty) _buildDynamicMarkers(),
      ],
    );
  }

  Widget _buildDynamicMarkers() {
    if (_assignedArticles.isEmpty) return const SizedBox.shrink();

    final clusters = _clusterService.clusterItems(
      _assignedArticles,
      _currentZoom,
    );
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
    final isSelected =
        _showArticleNavigation &&
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
  List<RecyclingItem> _findNearbyArticles(
    RecyclingItem item, {
    required double maxDistance,
  }) {
    List<RecyclingItem> nearby = [];

    for (var article in _assignedArticles) {
      final distance = _calculateDistance(
        item.latitude,
        item.longitude,
        article.latitude,
        article.longitude,
      );

      if (distance <= maxDistance) {
        nearby.add(article);
      }
    }

    return nearby;
  }

  /// Calculate distance between two points in meters (Haversine formula)
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371000; // meters

    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

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
      builder:
          (context) => _EmployeeSingleArticleModal(
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
  void _showArticleNavigationModal(
    List<RecyclingItem> articles,
    RecyclingItem currentItem,
  ) async {
    if (!mounted) return;

    final currentIndex = articles.indexWhere((a) => a.id == currentItem.id);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => _EmployeeArticleNavigationModal(
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
      heroTag: 'location_menu',
      onPressed: _showLocationMenu,
      backgroundColor: const Color(0xFF2D8A8A),
      elevation: 6,
      child: const Icon(Icons.location_searching, color: Colors.white),
    );
  }

  /// ✅ Show location menu options
  void _showLocationMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Título
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on, color: Color(0xFF2D8A8A)),
                      const SizedBox(width: 8),
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
                ),

                const Divider(height: 1),

                // Opción 1: Ir a mi ubicación
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFF2D8A8A),
                    child: Icon(
                      Icons.my_location,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  title: const Text(
                    'Ir a mi ubicación',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    _hasUserLocation
                        ? 'Centrar mapa en mi posición actual'
                        : 'GPS deshabilitado',
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _goToUserLocation();
                  },
                ),

                // Opción 2: Toggle marcador de usuario
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        _showUserMarker
                            ? const Color(0xFF2D8A8A)
                            : Colors.grey[400],
                    child: Icon(
                      _showUserMarker ? Icons.visibility : Icons.visibility_off,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    _showUserMarker
                        ? 'Ocultar mi marcador'
                        : 'Mostrar mi marcador',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    _showUserMarker
                        ? 'El marcador azul desaparecerá del mapa'
                        : 'Mostrar marcador azul en el mapa',
                  ),
                  trailing: Switch(
                    value: _showUserMarker,
                    onChanged: (value) {
                      Navigator.pop(context);
                      setState(() {
                        _showUserMarker = value;
                      });

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            _showUserMarker
                                ? '✅ Marcador visible'
                                : '❌ Marcador oculto',
                          ),
                          duration: const Duration(seconds: 1),
                          backgroundColor:
                              _showUserMarker ? Colors.green : Colors.grey,
                        ),
                      );
                    },
                    activeColor: const Color(0xFF2D8A8A),
                  ),
                ),

                // Opción 3: Ver todas las tareas
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.orange,
                    child: Icon(Icons.map, color: Colors.white, size: 20),
                  ),
                  title: const Text(
                    'Ver todas las tareas',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    _assignedArticles.isEmpty
                        ? 'No hay tareas asignadas'
                        : 'Ajustar mapa para mostrar todas las ubicaciones',
                  ),
                  onTap:
                      _assignedArticles.isEmpty
                          ? null
                          : () {
                            Navigator.pop(context);
                            _fitMapToShowAllArticles();
                          },
                ),

                // Opción 3: Recargar tareas
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFF2D8A8A),
                    child: Icon(Icons.refresh, color: Colors.white, size: 20),
                  ),
                  title: const Text(
                    'Recargar Tareas',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text('Actualizar lista de tareas asignadas'),
                  onTap: () async {
                    Navigator.pop(context);

                    // Show loading snackbar
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Row(
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            ),
                            SizedBox(width: 12),
                            Text('Recargando tareas...'),
                          ],
                        ),
                        duration: Duration(seconds: 2),
                        backgroundColor: Color(0xFF2D8A8A),
                      ),
                    );

                    await _refreshData();

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '✅ ${_assignedArticles.length} tarea${_assignedArticles.length == 1 ? "" : "s"} cargada${_assignedArticles.length == 1 ? "" : "s"}',
                          ),
                          duration: const Duration(seconds: 2),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  },
                ),

                const SizedBox(height: 16),
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
      _showEnableLocationDialog();
      return;
    }

    if (_hasUserLocation && _userLocation != null) {
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

      if (_hasUserLocation && _userLocation != null) {
        if (_mapService.isMapReady(_mapController)) {
          _mapController.move(_userLocation!, 16.0);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ No se pudo obtener tu ubicación'),
              duration: Duration(seconds: 2),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
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
  State<_EmployeeSingleArticleModal> createState() =>
      _EmployeeSingleArticleModalState();
}

class _EmployeeSingleArticleModalState
    extends State<_EmployeeSingleArticleModal> {
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
      final photo = await widget.mediaDatabase.getMainPhotoByPattern(
        urlPattern,
      );

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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              CategoryUtils.getCategoryIcon(
                                widget.item.categoryName,
                              ),
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
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        color: Colors.red,
                        size: 20,
                      ),
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
  State<_EmployeeArticleNavigationModal> createState() =>
      _EmployeeArticleNavigationModalState();
}

class _EmployeeArticleNavigationModalState
    extends State<_EmployeeArticleNavigationModal> {
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
      final photo = await widget.mediaDatabase.getMainPhotoByPattern(
        urlPattern,
      );

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
                      backgroundColor:
                          currentIndex > 0
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
                    onPressed:
                        currentIndex < widget.articles.length - 1
                            ? _goToNext
                            : null,
                    icon: const Icon(Icons.arrow_forward),
                    style: IconButton.styleFrom(
                      backgroundColor:
                          currentIndex < widget.articles.length - 1
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              CategoryUtils.getCategoryIcon(
                                currentItem.categoryName,
                              ),
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
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        color: Colors.red,
                        size: 20,
                      ),
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
