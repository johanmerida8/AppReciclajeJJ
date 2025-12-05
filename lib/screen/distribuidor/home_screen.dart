import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:reciclaje_app/auth/auth_service.dart';
import 'package:reciclaje_app/model/recycling_items.dart';
import 'package:reciclaje_app/services/location_service.dart';
import 'package:reciclaje_app/services/cache_service.dart';
import 'package:reciclaje_app/services/marker_cluster.dart';
import 'package:reciclaje_app/services/recycling_data.dart';
import 'package:reciclaje_app/services/workflow_service.dart';
import 'package:reciclaje_app/services/map_service.dart';
import 'package:reciclaje_app/screen/distribuidor/RegisterRecycle_screen.dart';
import 'package:reciclaje_app/screen/distribuidor/detail_recycle_screen.dart';
import 'package:reciclaje_app/screen/distribuidor/notifications_screen.dart';
import 'package:geocoding/geocoding.dart';
import 'package:reciclaje_app/utils/category_utils.dart';
import 'package:reciclaje_app/widgets/map_marker.dart';
import 'package:reciclaje_app/widgets/quick_register_dialog.dart';
import 'package:reciclaje_app/widgets/status_indicator.dart';
import 'package:reciclaje_app/database/media_database.dart';
import 'package:reciclaje_app/model/multimedia.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
// import 'package:reciclaje_app/widgets/category_utils.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  // Services
  final _authService = AuthService();
  final _dataService = RecyclingDataService();
  final _locationService = LocationService();
  final _cacheService = CacheService();
  final _workflowService = WorkflowService();
  final _mapService = MapService();
  final _clusterService = MarkerClusterService();
  final _mediaDatabase = MediaDatabase();

  // Controllers
  final _mapController = MapController();

  // State variables
  List<RecyclingItem> _items = [];
  int? _currentUserId;
  int _pendingRequestCount = 0; // Notification count

  // ✅ NUEVO: Estado para navegación de artículos
  int _currentArticleIndex = 0;
  bool _showArticleNavigation = false;

  // ✅ Estado del zoom para clustering dinámico
  double _currentZoom = 13.0;

  Map<LatLng, bool> _expandedClusters = {};

  // Location state
  LatLng? _userLocation;
  LatLng? _quickRegisterLocation;
  String? _quickRegisterAddress;
  bool _hasUserLocation = false;
  bool _showTemporaryMarker = false;
  bool _showUserMarker =
      true; // ✅ NUEVO: Toggle para mostrar/ocultar marcador de usuario

  // Loading & error state
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';

  // Connection state
  bool _isConnected = true;
  bool _hasLocationPermission = false;
  bool _isLocationServiceEnabled = false;
  bool _hasCheckedLocation = false;
  // Track if user dismissed the enable-location dialog to prevent showing it again in same session
  bool _userDismissedLocationDialog = false;

  // ✅ Real-time listeners
  RealtimeChannel? _requestChannel;
  RealtimeChannel? _taskChannel;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupRealtimeListeners(); // ✅ Setup real-time updates
    _initialize();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _requestChannel?.unsubscribe(); // ✅ Unsubscribe from real-time
    _taskChannel?.unsubscribe();
    super.dispose();
  }

  /// ✅ NUEVO: Detectar cuando el usuario regresa a la app después de cambiar configuración de GPS
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed) {
      print('🔄 App resumed - Verificando estado de ubicación...');
      // Verificar si GPS fue habilitado mientras estábamos en segundo plano
      _recheckLocationAfterResume();
      // Reload notification count when app resumes
      _loadPendingRequestCount();
    }
  }

  /// ✅ Setup real-time listeners for notifications
  void _setupRealtimeListeners() {
    // Listen to request table for company requests
    _requestChannel =
        Supabase.instance.client
            .channel('distributor-home-requests')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'request',
              callback: (payload) {
                print('🔔 Distributor: Real-time request update');
                _loadPendingRequestCount();
              },
            )
            .subscribe();

    // Listen to tasks table for employee assignments
    _taskChannel =
        Supabase.instance.client
            .channel('distributor-home-tasks')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'tasks',
              callback: (payload) {
                print('🔔 Distributor: Real-time task update');
                _loadPendingRequestCount();
              },
            )
            .subscribe();
  }

  /// ✅ NUEVO: Re-verificar ubicación después de que la app vuelve del background
  Future<void> _recheckLocationAfterResume() async {
    final previousServiceEnabled = _isLocationServiceEnabled;
    final previousPermission = _hasLocationPermission;

    // Verificar estado actual
    await _checkLocationServices();

    // Si GPS fue habilitado mientras estábamos en background, recargar ubicación
    final gpsJustEnabled = !previousServiceEnabled && _isLocationServiceEnabled;
    final permissionJustGranted = !previousPermission && _hasLocationPermission;

    if (gpsJustEnabled || permissionJustGranted) {
      print('✅ GPS/Permisos habilitados - Recargando ubicación...');
      await _loadUserLocation();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Ubicación activada'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// Initialize all data
  Future<void> _initialize() async {
    await _loadUserData();
    await _loadPendingRequestCount(); // Load notification count
    await _loadData();

    // ✅ Verificar GPS primero antes de intentar cargar ubicación
    await _checkLocationServices();

    // ✅ Mostrar diálogo si GPS está deshabilitado (solo si usuario no lo rechazó previamente)
    if ((!_isLocationServiceEnabled || !_hasLocationPermission) &&
        !_userDismissedLocationDialog) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // ✅ Verificar que el widget esté montado y sea la ruta activa
        if (mounted && ModalRoute.of(context)?.isCurrent == true) {
          _showEnableLocationDialog();
        }
      });
    } else if (_isLocationServiceEnabled && _hasLocationPermission) {
      // GPS está habilitado, cargar ubicación automáticamente
      await _loadUserLocation();
    }
  }

  /// Load current user data
  Future<void> _loadUserData() async {
    final email = _authService.getCurrentUserEmail();
    if (email != null) {
      final userData = await _dataService.userDatabase.getUserByEmail(email);

      if (!mounted) return;

      setState(() {
        _currentUserId = userData?.id;
      });
    }
  }

  /// Load pending request count for notifications
  Future<void> _loadPendingRequestCount() async {
    if (_currentUserId == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final readNotifications =
          prefs.getStringList('read_distributor_notifications') ?? [];
      final readAssignedTasks =
          prefs.getStringList('read_distributor_assigned_tasks') ?? [];

      // Get pending requests
      final response = await Supabase.instance.client
          .from('request')
          .select('*, article!inner(userID)')
          .eq('status', 'pendiente')
          .eq('article.userID', _currentUserId!);

      // Filter out read notifications
      final unreadRequests =
          (response as List).where((req) {
            final requestId = req['idRequest'].toString();
            return !readNotifications.contains(requestId);
          }).toList();

      // ✅ Get tasks with assigned employees
      final tasksResponse = await Supabase.instance.client
          .from('tasks')
          .select('idTask, article!inner(userID)')
          .eq('workflowStatus', 'en_proceso')
          .eq('article.userID', _currentUserId!);

      // Filter out read assigned tasks
      final unreadTasks =
          (tasksResponse as List).where((task) {
            final taskId = task['idTask'].toString();
            return !readAssignedTasks.contains(taskId);
          }).toList();

      if (mounted) {
        setState(() {
          _pendingRequestCount = unreadRequests.length + unreadTasks.length;
        });
      }
      print(
        '📊 Unread notifications: ${unreadRequests.length} requests + ${unreadTasks.length} assigned tasks = ${unreadRequests.length + unreadTasks.length} total',
      );
    } catch (e) {
      print('Error loading pending request count: $e');
    }
  }

  /// Navigate to notifications screen
  Future<void> _navigateToNotifications() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const NotificationsScreen()),
    );
    // Refresh count after returning from notifications
    await _loadPendingRequestCount();
  }

  /// Load articles
  Future<void> _loadData({bool forceRefresh = false}) async {
    if (!forceRefresh && await _loadFromCache()) {
      _loadFreshDataInBackground();
      return;
    }

    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    await _loadFreshData();
  }

  /// Load from cache
  Future<bool> _loadFromCache() async {
    try {
      final cachedData = await _cacheService.loadCache(_currentUserId);
      if (cachedData != null && cachedData['items'] != null) {
        if (!mounted) return false;

        setState(() {
          _items = List<RecyclingItem>.from(cachedData['items']);
          _isLoading = false;
        });
        print('✅ Loaded ${_items.length} items from cache');
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Error loading from cache: $e');
      return false;
    }
  }

  /// Load fresh data from database
  Future<void> _loadFreshData({bool showLoading = true}) async {
    try {
      final items = await _dataService.loadRecyclingItems();
      final categories = await _dataService.loadCategories();

      if (!mounted) return;

      setState(() {
        _items = items;
        _isLoading = false;
        _hasError = false;
      });

      await _cacheService.saveCache(items, categories, _currentUserId);
      print('✅ Loaded ${items.length} items fresh');

      // ✅ Ajustar mapa después de cargar artículos (con delay corto para asegurar que el mapa esté renderizado)
      if (_myItems.isNotEmpty) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted && _mapService.isMapReady(_mapController)) {
            _fitMapToShowAllArticles();
            print('✅ Mapa ajustado para mostrar artículos del usuario');
          }
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _hasError = true;
        _errorMessage = 'Error al cargar datos: $e';
        _isLoading = false;
      });
      print('❌ Error loading fresh data: $e');
    }
  }

  /// Load fresh data in background
  Future<void> _loadFreshDataInBackground() async {
    try {
      await _loadFreshData(showLoading: false);
    } catch (e) {
      print('Error updating in background: $e');
    }
  }

  /// Load user's current location
  Future<void> _loadUserLocation() async {
    try {
      print('📍 Cargando ubicación del usuario...');

      // ✅ Verificar primero si GPS está habilitado
      await _checkLocationServices();

      if (!_isLocationServiceEnabled) {
        print('⚠️ GPS desactivado - no se puede obtener ubicación');
        setState(() {
          _hasUserLocation = false;
          _userLocation = null;
        });
        return;
      }

      if (!_hasLocationPermission) {
        print('⚠️ Permisos de ubicación no otorgados');
        setState(() {
          _hasUserLocation = false;
          _userLocation = null;
        });
        return;
      }

      final location = await _locationService.getCurrentLocation();

      if (location != null) {
        if (!mounted) return;

        setState(() {
          _userLocation = location;
          _hasUserLocation = true;
        });
        print(
          '✅ Ubicación del usuario obtenida: ${location.latitude}, ${location.longitude}',
        );
        print('✅ Estado _hasUserLocation: $_hasUserLocation');
        print('✅ _userLocation: $_userLocation');

        // ✅ Centrar mapa en ubicación del usuario solo si no hay artículos
        Future.microtask(() {
          if (mounted && _mapService.isMapReady(_mapController)) {
            if (_myItems.isEmpty) {
              _mapController.move(_userLocation!, MapService.closeZoomLevel);
              print('✅ Mapa centrado en ubicación del usuario');
            } else {
              print(
                '✅ Marcador de ubicación visible, mapa ajustado a artículos',
              );
            }
          }
        });
      } else {
        print('⚠️ No se pudo obtener la ubicación del usuario');
        if (!mounted) return;

        setState(() {
          _hasUserLocation = false;
          _userLocation = null;
        });
      }
    } catch (e) {
      print('❌ Error obteniendo ubicación del usuario: $e');
      if (!mounted) return;

      setState(() {
        _hasUserLocation = false;
        _userLocation = null;
      });

      // ✅ Mostrar mensaje de error al usuario solo si fue un timeout
      if (mounted && e.toString().contains('Timeout')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '⏱️ GPS tardando mucho. Verifica que estés al aire libre',
            ),
            duration: Duration(seconds: 3),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  /// Check location services and reload location if enabled
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

  /// ✅ Mostrar diálogo para activar ubicación cuando la app inicia
  void _showEnableLocationDialog() {
    // ✅ Verificar que la ruta actual sea HomeScreen antes de mostrar el diálogo
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
                            'Registrar artículos en tu ubicación actual',
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
                // Mark that user dismissed the dialog so we don't show it again in this session
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

  /// Refresh all data
  Future<void> _refreshData() async {
    await _cacheService.clearCache();
    await _loadData(forceRefresh: true);

    // ✅ Mueve el mapa usando la última ubicación conocida
    final lastLocation = _locationService.lastKnownLocation ?? _userLocation;
    if (lastLocation != null) {
      Future.microtask(() {
        if (_mapService.isMapReady(_mapController)) {
          _mapController.move(lastLocation, 14.0);
          print('♻️ Mapa recentrado en última ubicación conocida');
        }
      });
    }
  }

  /// Get only current user's items (excluding completed tasks)
  List<RecyclingItem> get _myItems {
    if (_currentUserId == null) return [];
    // ✅ Filter out articles with completed workflow status (they're in history)
    return _items
        .where(
          (item) =>
              item.ownerUserId == _currentUserId &&
              item.workflowStatus != 'completado',
        )
        .toList();
  }

  /// Handle map tap for quick register
  Future<void> _onMapTap(LatLng point) async {
    if (!await _workflowService.canUserPublish()) {
      _showCannotPublishMessage();
      return;
    }

    String address = await _getAddressFromCoordinates(point);

    if (!mounted) return;

    setState(() {
      _quickRegisterLocation = point;
      _quickRegisterAddress = address;
      _showTemporaryMarker = true;
    });

    if (_mapService.isMapReady(_mapController)) {
      _mapController.move(point, MapService.closeZoomLevel);
    }
    _showQuickRegisterDialog();
  }

  /// Get address from coordinates
  Future<String> _getAddressFromCoordinates(LatLng point) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        point.latitude,
        point.longitude,
      );

      if (placemarks.isNotEmpty) {
        final place = placemarks[0];
        List<String> parts = [];

        if (place.street?.isNotEmpty == true) parts.add(place.street!);
        if (place.subThoroughfare?.isNotEmpty == true)
          parts.add(place.subThoroughfare!);
        if (place.locality?.isNotEmpty == true) parts.add(place.locality!);

        return parts.isNotEmpty ? parts.join(', ') : place.country ?? 'Bolivia';
      }
    } catch (e) {
      print('Error getting address: $e');
    }

    return 'Lat: ${point.latitude.toStringAsFixed(4)}, Lng: ${point.longitude.toStringAsFixed(4)}';
  }

  /// Show quick register dialog
  void _showQuickRegisterDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (context) => QuickRegisterDialog(
            address: _quickRegisterAddress,
            onCancel: _cancelQuickRegister,
            onConfirm: _confirmQuickRegister,
          ),
    );
  }

  /// Cancel quick register
  void _cancelQuickRegister() {
    Navigator.pop(context);
    setState(() {
      _quickRegisterLocation = null;
      _quickRegisterAddress = null;
      _showTemporaryMarker = false;
    });
  }

  /// Confirm quick register
  Future<void> _confirmQuickRegister() async {
    Navigator.pop(context);

    if (_quickRegisterLocation != null) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => RegisterRecycleScreen(
                preselectedLocation: _quickRegisterLocation!,
                preselectedAddress: _quickRegisterAddress!,
              ),
        ),
      );

      if (!mounted) return;

      setState(() {
        _quickRegisterLocation = null;
        _quickRegisterAddress = null;
        _showTemporaryMarker = false;
      });

      // ✅ Siempre refrescar datos al volver del registro
      print('🔄 Reloading data after returning from registration...');
      await _refreshData();
    }
  }

  /// Show cannot publish message
  void _showCannotPublishMessage() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning,
                  color: Colors.orange,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Límite alcanzado',
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
                'Ya tienes 3 artículos pendientes de recogida.',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Para publicar más artículos:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '• Espera a que una empresa recoja tus artículos\n'
                      '• El proceso debe completarse\n'
                      '• Luego podrás registrar nuevos artículos\n'
                      '• Límite máximo: 3 artículos pendientes',
                      style: TextStyle(fontSize: 13, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2D8A8A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              child: const Text('Entendido'),
            ),
          ],
        );
      },
    );
  }

  /// Fit map to show all articles
  void _fitMapToShowAllArticles() {
    _mapService.fitMapToShowAllArticles(
      _mapController,
      _myItems,
      _userLocation,
      _hasUserLocation,
    );
  }

  /// Show item details
  void _showItemDetails(RecyclingItem item) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => DetailRecycleScreen(item: item)),
    );

    // ✅ Reload data if article was updated or deleted
    if (result == true && mounted) {
      print('🔄 Reloading data after article update/delete...');
      await _refreshData();
    }
  }

  /// =====================
  /// UI Building Methods
  /// =====================

  Widget _buildMap() {
    if (_isLoading) return const SizedBox();

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        // ✅ Siempre iniciar en Cochabamba con zoom moderado
        initialCenter: MapService.cochabambaCenter,
        initialZoom: 13.0, // ✅ Zoom moderado para ver la ciudad completa
        minZoom: 6.0, // ✅ Prevent zooming out beyond Bolivia
        maxZoom: 18.0,
        // ✅ Disable map rotation
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
        // ✅ Restrict map to Bolivia boundaries
        cameraConstraint: CameraConstraint.contain(
          bounds: LatLngBounds(
            const LatLng(-22.9, -69.7), // Southwest corner of Bolivia
            const LatLng(-9.6, -57.4), // Northeast corner of Bolivia
          ),
        ),
        onTap: (_, point) => _onMapTap(point),
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
        // ✅ Mostrar marcador de usuario solo si está habilitado el toggle
        if (_showUserMarker && _hasUserLocation && _userLocation != null)
          MarkerLayer(markers: [MapMarkers.userLocationMarker(_userLocation!)]),
        if (_showTemporaryMarker && _quickRegisterLocation != null)
          MarkerLayer(
            markers: [MapMarkers.temporaryMarker(_quickRegisterLocation!)],
          ),
        if (_myItems.isNotEmpty) _buildDynamicMarkers(),
      ],
    );
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
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 64),
              const SizedBox(height: 16),
              Text(
                _errorMessage,
                style: const TextStyle(color: Colors.red, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _refreshData,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2D8A8A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _buildMap(),
          _buildTopBar(),

          // ✅ Tarjeta de navegación de artículos (debajo del TopBar)
          // Se muestra cuando hay al menos 1 artículo y está activada la navegación
          // DISABLED: Now using modal navigation instead
          // if (_myItems.isNotEmpty && _showArticleNavigation)
          //   Positioned(
          //     top: MediaQuery.of(context).padding.top + 70,
          //     left: 16,
          //     right: 16,
          //     child: _buildArticleNavigationWidget(),
          //   ),
          if (_isLoading) _buildLoadingOverlay(),
          if (_hasError) _buildErrorOverlay(),
        ],
      ),
      floatingActionButton: _buildLocationFAB(),
    );
  }

  /// ✅ Botón flotante unificado con menú de opciones
  Widget _buildLocationFAB() {
    return FloatingActionButton(
      heroTag: 'location_menu',
      onPressed: _showLocationMenu,
      backgroundColor: const Color(0xFF2D8A8A),
      elevation: 6,
      child: const Icon(Icons.location_searching, color: Colors.white),
    );
  }

  /// ✅ Mostrar menú de opciones de ubicación
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
                  subtitle: const Text('Centrar mapa en mi posición actual'),
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

  // ✅ Construir marcadores dinámicos con clustering inteligente
  Widget _buildDynamicMarkers() {
    if (_myItems.isEmpty) return const SizedBox.shrink();

    // Generar clusters según el zoom actual
    final clusters = _clusterService.clusterItems(_myItems, _currentZoom);

    List<Marker> markers = [];

    for (var cluster in clusters) {
      final isExpanded = _expandedClusters[cluster.center] ?? false;

      if (cluster.isSingleItem) {
        // Marcador individual
        markers.add(_buildSingleMarker(cluster.items[0]));
      } else if (isExpanded) {
        // Cluster expandido - mostrar todos los marcadores en círculo
        markers.addAll(_buildExpandedClusterMarkers(cluster));
      } else {
        // Cluster colapsado - mostrar solo el marcador agrupado
        markers.add(_buildClusterMarker(cluster));
      }
    }

    return MarkerLayer(markers: markers);
  }

  // ✅ Marcador individual
  Marker _buildSingleMarker(RecyclingItem item) {
    final isSelected =
        _showArticleNavigation && _myItems[_currentArticleIndex].id == item.id;

    // ✅ Determine marker color based on workflow status
    Color markerColor;
    if (item.workflowStatus == 'completado') {
      markerColor = Colors.green; // ✅ Completed - Green
    } else if (item.workflowStatus == 'vencido') {
      markerColor = Colors.red; // ✅ Overdue - Red
    } else if (item.workflowStatus == 'en_proceso' ||
        item.workflowStatus == 'asignado') {
      markerColor = Colors.amber; // ✅ In progress/Assigned - Amber
    } else if (item.workflowStatus == 'sin_asignar') {
      markerColor = const Color(
        0xFFFDD835,
      ); // ✅ Unassigned (company requested) - Yellow
    } else {
      // Default: Blue for all published articles (not requested yet)
      markerColor = Colors.blue;
    }

    return Marker(
      point: LatLng(item.latitude, item.longitude),
      width: isSelected ? 60 : 50, // ✅ Más grande cuando está seleccionado
      height: isSelected ? 60 : 50,
      child: GestureDetector(
        onTap: () => _onMarkerTap(item),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.8, end: isSelected ? 1.1 : 1.0),
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutBack,
          builder: (context, scale, child) {
            return Transform.scale(
              scale: scale,
              child: Container(
                decoration: BoxDecoration(
                  color: markerColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color:
                        isSelected
                            ? Colors.white
                            : Colors.white.withOpacity(0.3),
                    width: isSelected ? 5 : 2, // ✅ Borde más grueso
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isSelected ? 0.6 : 0.3),
                      blurRadius: isSelected ? 16 : 6,
                      spreadRadius: isSelected ? 2 : 0,
                      offset: const Offset(0, 2),
                    ),
                    // ✅ Sombra blanca adicional para resaltar más
                    if (isSelected)
                      BoxShadow(
                        color: Colors.white.withOpacity(0.5),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                  ],
                ),
                child: Icon(
                  Icons.recycling, // ✅ Single icon for all articles
                  color: Colors.white,
                  size: isSelected ? 28 : 24, // ✅ Icono más grande
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ✅ Marcador de cluster colapsado
  Marker _buildClusterMarker(MarkerCluster cluster) {
    return Marker(
      point: cluster.center,
      width: 70,
      height: 70,
      child: GestureDetector(
        onTap: () => _onClusterTap(cluster),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Círculo exterior animado
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: const Color(0xFF2D8A8A).withOpacity(0.3),
                shape: BoxShape.circle,
              ),
            ),
            // Círculo principal
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: const Color(0xFF2D8A8A),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
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
                    'items',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            // Icono de expandir
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.unfold_more,
                  size: 16,
                  color: Color(0xFF2D8A8A),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ Marcadores de cluster expandido (en círculo)
  List<Marker> _buildExpandedClusterMarkers(MarkerCluster cluster) {
    List<Marker> markers = [];
    final itemCount = cluster.items.length;
    const double radius = 0.0015; // ✅ AUMENTADO: aprox 170 metros - más visible

    for (int i = 0; i < itemCount; i++) {
      // Calcular posición en círculo alrededor del centro
      double angle = (2 * pi * i) / itemCount;
      double offsetLat = radius * cos(angle);
      double offsetLng = radius * sin(angle);

      LatLng position = LatLng(
        cluster.center.latitude + offsetLat,
        cluster.center.longitude + offsetLng,
      );

      final item = cluster.items[i];
      final isSelected =
          _showArticleNavigation &&
          _myItems[_currentArticleIndex].id == item.id;

      markers.add(
        Marker(
          point: position,
          width: isSelected ? 60 : 50,
          height: isSelected ? 60 : 50,
          child: GestureDetector(
            onTap: () => _onMarkerTap(item),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: Duration(milliseconds: 300 + (i * 50)),
              curve: Curves.elasticOut,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value * (isSelected ? 1.1 : 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: CategoryUtils.getCategoryColor(item.categoryName),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color:
                            isSelected
                                ? Colors.white
                                : Colors.white.withOpacity(0.7),
                        width: isSelected ? 5 : 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(
                            isSelected ? 0.6 : 0.3,
                          ),
                          blurRadius: isSelected ? 12 : 6,
                          spreadRadius: isSelected ? 2 : 0,
                          offset: const Offset(0, 2),
                        ),
                        if (isSelected)
                          BoxShadow(
                            color: Colors.white.withOpacity(0.5),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                      ],
                    ),
                    child: Icon(
                      CategoryUtils.getCategoryIcon(item.categoryName),
                      color: Colors.white,
                      size: isSelected ? 28 : 24,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
    }

    // Agregar marcador central para colapsar
    markers.add(_buildCollapseMarker(cluster));

    return markers;
  }

  // ✅ Marcador central para colapsar cluster
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
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF2D8A8A), width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(Icons.close, size: 20, color: Color(0xFF2D8A8A)),
        ),
      ),
    );
  }

  // ✅ Manejar tap en marcador individual
  void _onMarkerTap(RecyclingItem item) {
    final index = _myItems.indexWhere((i) => i.id == item.id);

    // ✅ Buscar artículos cercanos (dentro de 300 metros)
    final nearbyItems = _findNearbyArticles(item, maxDistance: 300.0);

    // ✅ Actualizar índice y ACTIVAR navegación para mostrar borde blanco
    setState(() {
      _currentArticleIndex = index;
      _showArticleNavigation = true;
    });

    // ✅ Centrar mapa en el marcador con zoom consistente
    if (_mapService.isMapReady(_mapController)) {
      _mapController.move(LatLng(item.latitude, item.longitude), 15.0);
    }

    // ✅ Si hay artículos cercanos, mostrar navegación. Si no, modal simple
    if (nearbyItems.length > 1) {
      // Crear cluster virtual para navegación
      final virtualCluster = MarkerCluster(
        center: LatLng(item.latitude, item.longitude),
        items: nearbyItems,
      );
      _showClusterNavigationModal(virtualCluster);
      print(
        '📍 Mostrando navegación de ${nearbyItems.length} artículos cercanos',
      );
    } else {
      // Artículo aislado, mostrar modal simple
      _showSingleArticleModal(item);
      print('📍 Mostrando modal de artículo individual aislado');
    }
  }

  // ✅ Encontrar artículos cercanos al artículo dado
  List<RecyclingItem> _findNearbyArticles(
    RecyclingItem item, {
    required double maxDistance,
  }) {
    List<RecyclingItem> nearbyItems = [item]; // Incluir el artículo actual

    for (var otherItem in _myItems) {
      if (otherItem.id == item.id) continue; // Saltar el mismo artículo

      final distance = _calculateDistance(
        item.latitude,
        item.longitude,
        otherItem.latitude,
        otherItem.longitude,
      );

      if (distance <= maxDistance) {
        nearbyItems.add(otherItem);
      }
    }

    return nearbyItems;
  }

  // ✅ Calcular distancia entre dos puntos en metros (Haversine formula)
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371000; // metros

    double dLat = _toRadians(lat2 - lat1);
    double dLon = _toRadians(lon2 - lon1);

    double a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  double _toRadians(double degrees) {
    return degrees * pi / 180;
  }

  // ✅ Modal simple para artículo individual (sin botones de navegación)
  void _showSingleArticleModal(RecyclingItem item) async {
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      builder:
          (context) => _SingleArticleModalContent(
            item: item,
            mediaDatabase: _mediaDatabase,
            onShowDetails: _showItemDetails,
          ),
    ).then((_) {
      // Desactivar navegación al cerrar modal
      if (mounted) {
        setState(() {
          _showArticleNavigation = false;
        });
      }
    });
  }

  // ✅ Manejar tap en cluster - Mostrar navegación de artículos
  void _onClusterTap(MarkerCluster cluster) {
    // Encontrar el índice del primer artículo del cluster
    final firstItem = cluster.items[0];
    final index = _myItems.indexWhere((i) => i.id == firstItem.id);

    // Activar navegación y actualizar índice
    setState(() {
      _currentArticleIndex = index;
      _showArticleNavigation = true;
    });

    // ✅ Centrar mapa en el cluster con zoom cercano (como la ubicación del usuario)
    if (_mapService.isMapReady(_mapController)) {
      _mapController.move(cluster.center, 15.0); // ✅ Zoom consistente y cercano
    }

    // Mostrar modal con navegación entre los artículos del cluster
    _showClusterNavigationModal(cluster);

    print('📦 Cluster tocado - ${cluster.count} artículos para navegar');
  }

  // ✅ Modal de navegación para artículos en un cluster
  void _showClusterNavigationModal(MarkerCluster cluster) {
    if (!mounted) return;

    // Crear una lista filtrada con solo los artículos del cluster
    final clusterItems = cluster.items;
    int clusterIndex = 0; // Índice dentro del cluster

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      builder:
          (context) => _ClusterModalContent(
            clusterItems: clusterItems,
            initialClusterIndex: clusterIndex,
            allItems: _myItems,
            mediaDatabase: _mediaDatabase,
            onIndexChanged: (newClusterIndex) {
              setState(() {
                // Actualizar el índice global basado en el artículo del cluster
                final item = clusterItems[newClusterIndex];
                _currentArticleIndex = _myItems.indexWhere(
                  (i) => i.id == item.id,
                );
              });
            },
            onCenterMap: (lat, lng) {
              if (_mapService.isMapReady(_mapController)) {
                _mapController.move(
                  LatLng(lat, lng),
                  15.0,
                ); // ✅ Zoom consistente al navegar entre artículos
              }
            },
            onShowDetails: _showItemDetails,
          ),
    ).then((_) {
      // Desactivar navegación al cerrar modal
      if (mounted) {
        setState(() {
          _showArticleNavigation = false;
        });
      }
    });
  }

  // Other _HomeScreenState methods continue below...
} // Temporary close of _HomeScreenState - will be moved to end

// ============================================================================
// Separate modal widget class for article navigation
// ============================================================================

// ✅ Stateful modal widget to handle navigation properly
class _ArticleModalContent extends StatefulWidget {
  final RecyclingItem initialItem;
  final List<RecyclingItem> myItems;
  final int currentArticleIndex;
  final MediaDatabase mediaDatabase;
  final Function(int) onIndexChanged;
  final Function(double, double) onCenterMap;
  final Function(RecyclingItem) onShowDetails;

  const _ArticleModalContent({
    required this.initialItem,
    required this.myItems,
    required this.currentArticleIndex,
    required this.mediaDatabase,
    required this.onIndexChanged,
    required this.onCenterMap,
    required this.onShowDetails,
  });

  @override
  State<_ArticleModalContent> createState() => _ArticleModalContentState();
}

class _ArticleModalContentState extends State<_ArticleModalContent> {
  late int currentModalIndex;
  late RecyclingItem currentItem;
  Multimedia? currentPhoto;
  bool isLoadingPhoto = false;

  @override
  void initState() {
    super.initState();
    currentModalIndex = widget.currentArticleIndex;
    currentItem = widget.initialItem;
    _loadPhoto();
  }

  Future<void> _loadPhoto() async {
    setState(() {
      isLoadingPhoto = true;
    });

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
      print('❌ Error fetching photo: $e');
      if (mounted) {
        setState(() {
          currentPhoto = null;
          isLoadingPhoto = false;
        });
      }
    }
  }

  void navigateToNext() {
    if (widget.myItems.length <= 1) return;

    setState(() {
      currentModalIndex = (currentModalIndex + 1) % widget.myItems.length;
      currentItem = widget.myItems[currentModalIndex];
    });

    widget.onIndexChanged(currentModalIndex);
    widget.onCenterMap(currentItem.latitude, currentItem.longitude);
    _loadPhoto();

    print(
      '➡️ Navegando a artículo ${currentModalIndex + 1}: ${currentItem.title}',
    );
  }

  void navigateToPrevious() {
    if (widget.myItems.length <= 1) return;

    setState(() {
      currentModalIndex =
          (currentModalIndex - 1 + widget.myItems.length) %
          widget.myItems.length;
      currentItem = widget.myItems[currentModalIndex];
    });

    widget.onIndexChanged(currentModalIndex);
    widget.onCenterMap(currentItem.latitude, currentItem.longitude);
    _loadPhoto();

    print(
      '⬅️ Navegando a artículo ${currentModalIndex + 1}: ${currentItem.title}',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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

          // Content - Horizontal layout
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Navigation arrow - Previous
                if (widget.myItems.length > 1)
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: navigateToPrevious,
                    color: const Color(0xFF2D8A8A),
                    iconSize: 32,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),

                if (widget.myItems.length > 1) const SizedBox(width: 8),

                // Image on left
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child:
                      currentPhoto?.url != null
                          ? CachedNetworkImage(
                            imageUrl: currentPhoto!.url!,
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                            placeholder:
                                (context, url) => Container(
                                  width: 100,
                                  height: 100,
                                  color: Colors.grey[300],
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color(0xFF2D8A8A),
                                    ),
                                  ),
                                ),
                            errorWidget:
                                (context, url, error) =>
                                    _buildCompactPlaceholder(currentItem),
                          )
                          : _buildCompactPlaceholder(currentItem),
                ),

                const SizedBox(width: 12),

                // Text content on right
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Article counter (if multiple)
                      if (widget.myItems.length > 1)
                        Text(
                          'Artículo ${currentModalIndex + 1} de ${widget.myItems.length}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                            fontWeight: FontWeight.w500,
                          ),
                        ),

                      if (widget.myItems.length > 1) const SizedBox(height: 4),

                      // Title
                      Text(
                        currentItem.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D8A8A),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),

                      const SizedBox(height: 8),

                      // Location
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              currentItem.address,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Ver detalles button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            widget.onShowDetails(currentItem);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2D8A8A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Ver detalles',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                if (widget.myItems.length > 1) const SizedBox(width: 8),

                // Navigation arrow - Next
                if (widget.myItems.length > 1)
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: navigateToNext,
                    color: const Color(0xFF2D8A8A),
                    iconSize: 32,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildCompactPlaceholder(RecyclingItem item) {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: CategoryUtils.getCategoryColor(
          item.categoryName,
        ).withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Icon(
          CategoryUtils.getCategoryIcon(item.categoryName),
          size: 40,
          color: CategoryUtils.getCategoryColor(item.categoryName),
        ),
      ),
    );
  }
}

// ============================================================================
// Cluster navigation modal widget
// ============================================================================

// ✅ Modal widget for navigating through clustered articles
class _ClusterModalContent extends StatefulWidget {
  final List<RecyclingItem> clusterItems; // Solo los artículos del cluster
  final int initialClusterIndex;
  final List<RecyclingItem> allItems; // Todos los artículos (para referencia)
  final MediaDatabase mediaDatabase;
  final Function(int) onIndexChanged;
  final Function(double, double) onCenterMap;
  final Function(RecyclingItem) onShowDetails;

  const _ClusterModalContent({
    required this.clusterItems,
    required this.initialClusterIndex,
    required this.allItems,
    required this.mediaDatabase,
    required this.onIndexChanged,
    required this.onCenterMap,
    required this.onShowDetails,
  });

  @override
  State<_ClusterModalContent> createState() => _ClusterModalContentState();
}

class _ClusterModalContentState extends State<_ClusterModalContent> {
  late int currentClusterIndex;
  late RecyclingItem currentItem;
  Multimedia? currentPhoto;
  bool isLoadingPhoto = false;

  @override
  void initState() {
    super.initState();
    currentClusterIndex = widget.initialClusterIndex;
    currentItem = widget.clusterItems[currentClusterIndex];
    _loadPhoto();
  }

  Future<void> _loadPhoto() async {
    setState(() {
      isLoadingPhoto = true;
    });

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
      print('❌ Error fetching photo: $e');
      if (mounted) {
        setState(() {
          currentPhoto = null;
          isLoadingPhoto = false;
        });
      }
    }
  }

  void navigateToNext() {
    if (widget.clusterItems.length <= 1) return;

    setState(() {
      currentClusterIndex =
          (currentClusterIndex + 1) % widget.clusterItems.length;
      currentItem = widget.clusterItems[currentClusterIndex];
    });

    widget.onIndexChanged(currentClusterIndex);
    widget.onCenterMap(currentItem.latitude, currentItem.longitude);
    _loadPhoto();

    print(
      '➡️ Navegando a artículo ${currentClusterIndex + 1}/${widget.clusterItems.length}: ${currentItem.title}',
    );
  }

  void navigateToPrevious() {
    if (widget.clusterItems.length <= 1) return;

    setState(() {
      currentClusterIndex =
          (currentClusterIndex - 1 + widget.clusterItems.length) %
          widget.clusterItems.length;
      currentItem = widget.clusterItems[currentClusterIndex];
    });

    widget.onIndexChanged(currentClusterIndex);
    widget.onCenterMap(currentItem.latitude, currentItem.longitude);
    _loadPhoto();

    print(
      '⬅️ Navegando a artículo ${currentClusterIndex + 1}/${widget.clusterItems.length}: ${currentItem.title}',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Article counter
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2D8A8A).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${currentClusterIndex + 1} de ${widget.clusterItems.length} artículos',
                    style: const TextStyle(
                      color: Color(0xFF2D8A8A),
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Main content with navigation
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Navigation arrow - Previous
                if (widget.clusterItems.length > 1)
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: navigateToPrevious,
                    color: const Color(0xFF2D8A8A),
                    iconSize: 32,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),

                if (widget.clusterItems.length > 1) const SizedBox(width: 8),

                // Article preview (clickable)
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      widget.onShowDetails(currentItem);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Row(
                        children: [
                          // Photo
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child:
                                isLoadingPhoto
                                    ? Container(
                                      width: 80,
                                      height: 80,
                                      color: Colors.grey[300],
                                      child: const Center(
                                        child: SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      ),
                                    )
                                    : currentPhoto != null &&
                                        currentPhoto!.url != null
                                    ? CachedNetworkImage(
                                      imageUrl: currentPhoto!.url!,
                                      width: 80,
                                      height: 80,
                                      fit: BoxFit.cover,
                                      placeholder:
                                          (context, url) => Container(
                                            width: 80,
                                            height: 80,
                                            color: Colors.grey[300],
                                            child: const Center(
                                              child: SizedBox(
                                                width: 20,
                                                height: 20,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: Color(0xFF2D8A8A),
                                                    ),
                                              ),
                                            ),
                                          ),
                                      errorWidget:
                                          (context, url, error) =>
                                              _buildCompactPlaceholder(
                                                currentItem,
                                              ),
                                    )
                                    : _buildCompactPlaceholder(currentItem),
                          ),
                          const SizedBox(width: 12),

                          // Details
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  currentItem.title,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2D8A8A),
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  currentItem.categoryName,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.location_on,
                                      size: 14,
                                      color: Colors.grey[600],
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        currentItem.address,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Arrow indicator
                          Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                            color: Colors.grey[400],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                if (widget.clusterItems.length > 1) const SizedBox(width: 8),

                // Navigation arrow - Next
                if (widget.clusterItems.length > 1)
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: navigateToNext,
                    color: const Color(0xFF2D8A8A),
                    iconSize: 32,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildCompactPlaceholder(RecyclingItem item) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: CategoryUtils.getCategoryColor(
          item.categoryName,
        ).withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Icon(
          CategoryUtils.getCategoryIcon(item.categoryName),
          size: 32,
          color: CategoryUtils.getCategoryColor(item.categoryName),
        ),
      ),
    );
  }
}

// ============================================================================
// Single article modal widget (no navigation)
// ============================================================================

// ✅ Simple modal for individual marker (no previous/next buttons)
class _SingleArticleModalContent extends StatefulWidget {
  final RecyclingItem item;
  final MediaDatabase mediaDatabase;
  final Function(RecyclingItem) onShowDetails;

  const _SingleArticleModalContent({
    required this.item,
    required this.mediaDatabase,
    required this.onShowDetails,
  });

  @override
  State<_SingleArticleModalContent> createState() =>
      _SingleArticleModalContentState();
}

class _SingleArticleModalContentState
    extends State<_SingleArticleModalContent> {
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
      print('❌ Error fetching photo: $e');
      if (mounted) {
        setState(() {
          currentPhoto = null;
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
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 16),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Article preview (clickable) - NO navigation arrows
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: GestureDetector(
              onTap: () {
                Navigator.pop(context);
                widget.onShowDetails(widget.item);
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Row(
                  children: [
                    // Photo
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child:
                          isLoadingPhoto
                              ? Container(
                                width: 80,
                                height: 80,
                                color: Colors.grey[300],
                                child: const Center(
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                              )
                              : currentPhoto != null &&
                                  currentPhoto!.url != null
                              ? CachedNetworkImage(
                                imageUrl: currentPhoto!.url!,
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                                placeholder:
                                    (context, url) => Container(
                                      width: 80,
                                      height: 80,
                                      color: Colors.grey[300],
                                      child: const Center(
                                        child: SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Color(0xFF2D8A8A),
                                          ),
                                        ),
                                      ),
                                    ),
                                errorWidget:
                                    (context, url, error) =>
                                        _buildCompactPlaceholder(widget.item),
                              )
                              : _buildCompactPlaceholder(widget.item),
                    ),
                    const SizedBox(width: 12),

                    // Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.item.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2D8A8A),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.item.categoryName,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.location_on,
                                size: 14,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  widget.item.address,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Arrow indicator
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: Colors.grey[400],
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildCompactPlaceholder(RecyclingItem item) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: CategoryUtils.getCategoryColor(
          item.categoryName,
        ).withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Icon(
          CategoryUtils.getCategoryIcon(item.categoryName),
          size: 32,
          color: CategoryUtils.getCategoryColor(item.categoryName),
        ),
      ),
    );
  }
}
