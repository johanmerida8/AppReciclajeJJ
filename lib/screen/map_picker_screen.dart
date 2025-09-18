import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geocoding/geocoding.dart';
import 'package:latlong2/latlong.dart';
import 'package:reciclaje_app/components/location_input.dart';

class MapPickerScreen extends StatefulWidget {
  final LatLng initialLocation;

  const MapPickerScreen({super.key, required this.initialLocation});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  LatLng? _pickedLocation;
  String? _selectedAddress;
  bool _isLoadingAddress = false;
  
  final MapController _mapController = MapController();

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
    
    _mapController.move(location, 15.0);
    
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
              ? '📍 Ubicación seleccionada en el mapa' 
              : '📍 Ubicación actual obtenida'),
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
              onTap: (tapPosition, point) async {
                await _handleLocationSelection(
                  point.latitude, 
                  point.longitude, 
                  fromMap: true
                );
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                maxZoom: 19,
              ),

              if (_pickedLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _pickedLocation!, 
                      width: 40,
                      height: 40,
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
                child: Row(
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
                            ? 'Toca en el mapa para seleccionar la ubicación de entrega o usa el botón de ubicación actual'
                            : 'Confirma o cancela la ubicación seleccionada',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Current Location FAB - Positioned on the right side
          Positioned(
            top: 100,
            right: 16,
            child: LocationInput(
              initialLocation: widget.initialLocation,
              onSelectLocation: _handleLocationSelection,
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