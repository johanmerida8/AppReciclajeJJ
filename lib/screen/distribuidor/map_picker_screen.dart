import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geocoding/geocoding.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart' as loc;

class MapPickerScreen extends StatefulWidget {
  final LatLng initialLocation;
  final LatLng? originalLocation;

  const MapPickerScreen({super.key, required this.initialLocation, this.originalLocation});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> with WidgetsBindingObserver {
  LatLng? _pickedLocation;
  String? _selectedAddress;
  bool _isLoadingAddress = false;
  bool _isGettingInitialLocation = false;
  
  final MapController _mapController = MapController();
  final loc.Location _location = loc.Location();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Don't configure location settings here - wait until user explicitly requests location
    // This prevents crashes if permissions aren't granted yet
  }

  /// Configure location settings for optimal performance (call only when permissions granted)
  Future<void> _configureLocationSettings() async {
    try {
      // Only configure if we have permission
      final permission = await _location.hasPermission();
      if (permission == loc.PermissionStatus.granted ||
          permission == loc.PermissionStatus.grantedLimited) {
        // Request high accuracy mode
        await _location.changeSettings(
          accuracy: loc.LocationAccuracy.high,
          interval: 1000, // Update every 1 second
          distanceFilter: 0, // Get updates for any distance change
        );
      }
    } catch (e) {
      print('Error configuring location settings: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // App has come to the foreground (e.g., after enabling location in settings)
      _checkLocationServiceStatus();
    }
  }

  /// Check if location services are enabled and optionally re-request location
  Future<void> _checkLocationServiceStatus() async {
    try {
      final serviceEnabled = await _location.serviceEnabled();
      if (!serviceEnabled && mounted) {
        // Location was disabled, now it might be enabled
        final enabled = await _location.requestService();
        if (enabled) {
          // Service now enabled, optionally get location again
          // Uncomment if you want to auto-center when location is re-enabled
          // _getInitialUserLocation();
        }
      }
    } catch (e) {
      print('Error checking location service: $e');
    }
  }

  /// Get user's current location when user clicks the button (GPS should already be enabled)
  Future<void> _getInitialUserLocation() async {
    if (_isGettingInitialLocation) return;

    setState(() {
      _isGettingInitialLocation = true;
    });

    try {
      // Step 1: Check if location service is enabled
      bool serviceEnabled = await _location.serviceEnabled();
      
      if (!serviceEnabled) {
        // GPS not enabled
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ GPS desactivado. Por favor, actívalo desde la pantalla principal'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      // Step 2: Check permission status
      loc.PermissionStatus permissionGranted = await _location.hasPermission();
      
      if (permissionGranted == loc.PermissionStatus.denied ||
          permissionGranted == loc.PermissionStatus.deniedForever) {
        // Permission not granted
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ Permiso de ubicación no concedido. Por favor, concédelo desde la pantalla principal'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      // Step 3: Configure location settings now that we have permission
      await _configureLocationSettings();

      // Step 4: Get location with timeout (loading indicator already shown in UI)
      final locationData = await _location.getLocation().timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception('Tiempo de espera agotado. El GPS puede estar inicializándose.');
        },
      );

      if (locationData.latitude != null && locationData.longitude != null) {
        await _handleLocationSelection(
          locationData.latitude!,
          locationData.longitude!,
          fromMap: false,
        );
        // ✅ No mostrar snackbar adicional aquí - _handleLocationSelection ya muestra uno
      }
    } on TimeoutException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⏱️ El GPS está tardando. Intenta de nuevo o selecciona manualmente.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      print('Error getting initial location: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGettingInitialLocation = false;
        });
      }
    }
  }

  Future<String> _getAddressFromCoordinates(LatLng location) async {
    try {
      setState(() {
        _isLoadingAddress = true;
      });

      List<Placemark> placemarks = await placemarkFromCoordinates(
        location.latitude,
        location.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        
        String address = '';
        
        if (place.street != null && place.street!.isNotEmpty) {
          address += place.street!;
        }
        
        if (place.subThoroughfare != null && place.subThoroughfare!.isNotEmpty) {
          address += ' ${place.subThoroughfare!}';
        }
        
        if (place.locality != null && place.locality!.isNotEmpty) {
          if (address.isNotEmpty) address += ', ';
          address += place.locality!;
        }
        
        if (place.administrativeArea != null && place.administrativeArea!.isNotEmpty) {
          if (address.isNotEmpty) address += ', ';
          address += place.administrativeArea!;
        }
        
        if (place.country != null && place.country!.isNotEmpty) {
          if (address.isNotEmpty) address += ', ';
          address += place.country!;
        }

        return address.isNotEmpty ? address : 'Dirección no encontrada';
      }
      
      return 'Dirección no encontrada';
    } catch (e) {
      print('Error getting address: $e');
      return 'Error obteniendo dirección';
    } finally {
      setState(() {
        _isLoadingAddress = false;
      });
    }
  }

  Future<void> _handleLocationSelection(double lat, double lng, {bool fromMap = false}) async {
    final location = LatLng(lat, lng);
    
    // ✅ Solo centrar sin cambiar el zoom si fue desde el mapa
    // Si es desde GPS, hacer zoom para que el usuario vea mejor
    if (fromMap) {
      // Mantener el zoom actual del usuario
      _mapController.move(location, _mapController.camera.zoom);
    } else {
      // Desde GPS, zoom a 15 para ver la ubicación claramente
      _mapController.move(location, 17.0);
    }
    
    setState(() {
      _pickedLocation = location;
      _selectedAddress = null;
    });

    final address = await _getAddressFromCoordinates(location);
    setState(() {
      _selectedAddress = address;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(fromMap 
              ? '📍 Ubicación seleccionada' 
              : '✅ Ubicación obtenida'),
          backgroundColor: const Color(0xFF2D8A8A),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.only(bottom: 200, left: 16, right: 16),
        ),
      );
    }
  }

  // Confirm location selection
  void _confirmLocation() {
    Navigator.of(context).pop({
      'location': _pickedLocation,
      'address': _selectedAddress,
    });
  }

  // Cancel/Clear location selection
  void _cancelLocation() {
    setState(() {
      _pickedLocation = null;
      _selectedAddress = null;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('❌ Ubicación cancelada. Selecciona otra ubicación.'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  double _currentZoom = 13.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Seleccionar Ubicación',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF2D8A8A),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: widget.initialLocation,
              initialZoom: 13.0,
              minZoom: 6.0,  // ✅ Prevent zooming out beyond Bolivia
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
              onTap: (tapPosition, point) async {
                await _handleLocationSelection(
                  point.latitude, 
                  point.longitude, 
                  fromMap: true
                );
              },
              onPositionChanged: (MapCamera position, bool hasGesture) {
                _currentZoom = position.zoom;
                if (position.zoom >= 14 || position.zoom < 12) {
                  FocusScope.of(context).unfocus();
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                maxZoom: 19,
              ),

              MarkerLayer(
                markers: [
                  // ✅ Marcador de ubicación original
                  if (widget.originalLocation != null)
                    Marker(
                      point: widget.originalLocation!,
                      width: 50,
                      height: 65, // ✅ Aumentado de 50 a 65 para evitar overflow (label + icon)
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade700,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Original',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Icon(
                            Icons.location_on,
                            color: Colors.grey.shade600,
                            size: 40,
                          ),
                        ],
                      ),
                    ),
                  
                  // Marcador seleccionado
                  if (_pickedLocation != null)
                    Marker(
                      point: _pickedLocation!,
                      width: 50,
                      height: 50,
                      child: const Icon(
                        Icons.location_on,
                        size: 50,
                        color: Color(0xFF2D8A8A),
                      ),
                    ),
                ],
              ),
            ],
          ),

          // Instructions card at the top
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: Color(0xFF2D8A8A),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _pickedLocation == null 
                                ? 'Toca el mapa o usa tu ubicación actual'
                                : 'Confirma o cancela la ubicación',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black87,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_pickedLocation == null && !_isGettingInitialLocation) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton.icon(
                              onPressed: _getInitialUserLocation,
                              icon: const Icon(Icons.my_location, size: 16),
                              label: const Text(
                                'Usar mi ubicación',
                                style: TextStyle(fontSize: 13),
                              ),
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFF2D8A8A),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                backgroundColor: const Color(0xFF2D8A8A).withOpacity(0.1),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Row(
                        children: [
                          Icon(Icons.tips_and_updates, size: 12, color: Colors.grey),
                          SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Asegúrate de tener GPS activado para mejor precisión',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (_isGettingInitialLocation) ...[
                      const SizedBox(height: 8),
                      const Row(
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF2D8A8A),
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Obteniendo tu ubicación...',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // Location info card with inline actions
          if (_pickedLocation != null)
            Positioned(
              bottom: 20,
              left: 16,
              right: 16,
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header with title and action buttons
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on,
                            color: Color(0xFF2D8A8A),
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Ubicación Seleccionada',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2D8A8A),
                                fontSize: 16,
                              ),
                            ),
                          ),
                          
                          // Action buttons
                          Row(
                            children: [
                              // Cancel button
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.red.shade200),
                                ),
                                child: IconButton(
                                  onPressed: _cancelLocation,
                                  icon: Icon(
                                    Icons.close,
                                    color: Colors.red.shade600,
                                    size: 20,
                                  ),
                                  padding: const EdgeInsets.all(8),
                                  constraints: const BoxConstraints(
                                    minWidth: 36,
                                    minHeight: 36,
                                  ),
                                  tooltip: 'Cancelar ubicación',
                                ),
                              ),
                              const SizedBox(width: 8),
                              
                              // Confirm button
                              Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2D8A8A).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFF2D8A8A).withOpacity(0.3)),
                                ),
                                child: IconButton(
                                  onPressed: (_selectedAddress != null && !_isLoadingAddress) 
                                      ? _confirmLocation 
                                      : null,
                                  icon: const Icon(
                                    Icons.check,
                                    color: Color(0xFF2D8A8A),
                                    size: 20,
                                  ),
                                  padding: const EdgeInsets.all(8),
                                  constraints: const BoxConstraints(
                                    minWidth: 36,
                                    minHeight: 36,
                                  ),
                                  tooltip: 'Confirmar ubicación',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // Address display
                      if (_isLoadingAddress)
                        const Row(
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF2D8A8A),
                              ),
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Obteniendo dirección...',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        )
                      else if (_selectedAddress != null)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2D8A8A).withOpacity(0.05),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFF2D8A8A).withOpacity(0.2),
                            ),
                          ),
                          child: Text(
                            _selectedAddress!,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                              fontWeight: FontWeight.w500,
                              height: 1.3,
                            ),
                          ),
                        ),
                      
                      const SizedBox(height: 8),
                      
                      // Coordinates
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Lat: ${_pickedLocation!.latitude.toStringAsFixed(6)}',
                              style: TextStyle(
                                fontSize: 11, 
                                color: Colors.grey.shade600,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              'Lng: ${_pickedLocation!.longitude.toStringAsFixed(6)}',
                              style: TextStyle(
                                fontSize: 11, 
                                color: Colors.grey.shade600,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}