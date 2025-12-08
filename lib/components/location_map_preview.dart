import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart';
import 'package:reciclaje_app/screen/distribuidor/map_picker_screen.dart';

class LocationMapPreview extends StatefulWidget {
  final LatLng location;
  final LatLng? originalLocation;
  final String address;
  final bool isEditing;
  final Function(LatLng location, String address)? onLocationChanged;

  const LocationMapPreview({
    super.key,
    required this.location,
    this.originalLocation,
    required this.address,
    this.isEditing = false,
    this.onLocationChanged,
  });

  @override
  State<LocationMapPreview> createState() => _LocationMapPreviewState();
}

class _LocationMapPreviewState extends State<LocationMapPreview> {
  bool _isExpanded = false;
  final MapController _mapController = MapController();
  
  // ✅ Estado local para ubicación temporal mientras se edita en el mapa
  LatLng? _tempLocation;
  bool _isEditingOnMap = false;

  @override
  Widget build(BuildContext context) {
    final displayLocation = _tempLocation ?? widget.location;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              widget.isEditing ? 'Preferencia de entrega' : 'Ubicación de entrega',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D8A8A),
              ),
            ),
            if (!_isExpanded)
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _isExpanded = true;
                  });
                },
                icon: const Icon(Icons.zoom_out_map, size: 18),
                label: const Text('Ver mapa'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF2D8A8A),
                ),
              ),
          ],
        ),

        const SizedBox(height: 8),

        // Mapa
        GestureDetector(
          onTap: widget.isEditing && !_isExpanded
              ? () {
                  setState(() {
                    _isExpanded = true;
                  });
                }
              : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            height: _isExpanded ? 400 : 200,
            decoration: BoxDecoration(
              border: Border.all(
                color: widget.isEditing
                    ? const Color(0xFF2D8A8A)
                    : Colors.grey.shade300,
                width: 2,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                children: [
                  // Mapa
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: displayLocation,
                      initialZoom: _isExpanded ? 15.0 : 14.0,
                      minZoom: 6.0,  // ✅ Prevent zooming out beyond Bolivia
                      maxZoom: 18.0,
                      // ✅ Disable map rotation
                      interactionOptions: InteractionOptions(
                        flags: _isExpanded
                            ? (InteractiveFlag.all & ~InteractiveFlag.rotate)
                            : InteractiveFlag.none,
                      ),
                      // ✅ Restrict map to Bolivia boundaries
                      cameraConstraint: CameraConstraint.contain(
                        bounds: LatLngBounds(
                          const LatLng(-22.9, -69.7), // Southwest corner of Bolivia
                          const LatLng(-9.6, -57.4),   // Northeast corner of Bolivia
                        ),
                      ),
                      onTap: (widget.isEditing && _isExpanded && !_isEditingOnMap)
                          ? (tapPosition, point) {
                              setState(() {
                                _tempLocation = point;
                                _isEditingOnMap = true;
                              });
                              
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('📍 Nueva ubicación seleccionada. Confirma o cancela los cambios.'),
                                  backgroundColor: Color(0xFF2D8A8A),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                          : null,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                        subdomains: const ['a', 'b', 'c'],
                      ),
                      
                      MarkerLayer(
                        markers: [
                          // ✅ Marcador original (SOLO en modo edición y cuando NO está editando en el mapa)
                          if (widget.isEditing && 
                              widget.originalLocation != null && 
                              !_isEditingOnMap &&
                              displayLocation != widget.originalLocation)
                            Marker(
                              point: widget.originalLocation!,
                              width: 50,
                              height: 70, // ✅ Aumentar altura para que no se corte el label
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
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
                                    shadows: [
                                      Shadow(
                                        color: Colors.black.withOpacity(0.3),
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          
                          // ✅ Marcador actual/nuevo
                          Marker(
                            point: displayLocation,
                            width: 50,
                            height: 70, // ✅ Aumentar altura
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (widget.isEditing && _isEditingOnMap)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.orange,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'Nuevo',
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
                                  color: _isEditingOnMap
                                      ? Colors.orange
                                      : (widget.isEditing
                                          ? const Color(0xFF2D8A8A)
                                          : Colors.red),
                                  size: 40,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black.withOpacity(0.3),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Overlay con dirección
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.6),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            color: widget.isEditing
                                ? const Color(0xFF2D8A8A)
                                : Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.address,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                shadows: [
                                  Shadow(
                                    color: Colors.black,
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Botones de acción (expandido)
                  if (_isExpanded)
                    Positioned(
                      bottom: 12,
                      left: 12,
                      right: 12,
                      child: _isEditingOnMap
                          ? _buildEditingButtons()
                          : _buildNormalButtons(),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNormalButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _isExpanded = false;
              });
            },
            icon: const Icon(Icons.zoom_in_map, size: 18),
            label: const Text('Contraer'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.grey.shade700,
              elevation: 4,
            ),
          ),
        ),

        if (widget.isEditing && widget.onLocationChanged != null) ...[
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () async {
                // Abrir MapPickerScreen con la ubicación actual (puede ser diferente a la original)
                final currentLocation = _tempLocation ?? widget.location;
                final res = await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => MapPickerScreen(
                      initialLocation: currentLocation, // ✅ Usar ubicación actual (puede ser temp o widget.location)
                      originalLocation: widget.originalLocation, // ✅ Mostrar ubicación original para comparar
                    ),
                  ),
                );

                if (res != null && res is Map<String, dynamic>) {
                  final LatLng pickedLocation = res['location'];
                  final String pickedAddress = res['address'];
                  widget.onLocationChanged!(pickedLocation, pickedAddress);
                  
                  // ✅ Limpiar estado temporal si existía
                  setState(() {
                    _tempLocation = null;
                    _isEditingOnMap = false;
                  });
                }
              },
              icon: const Icon(Icons.map, size: 18),
              label: const Text('Mapa completo'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2D8A8A),
                foregroundColor: Colors.white,
                elevation: 4,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildEditingButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _tempLocation = null;
                _isEditingOnMap = false;
              });
              
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('❌ Cambios descartados'),
                  backgroundColor: Colors.orange,
                  duration: Duration(seconds: 2),
                ),
              );
            },
            icon: const Icon(Icons.close, size: 18),
            label: const Text('Cancelar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.red,
              elevation: 4,
            ),
          ),
        ),

        const SizedBox(width: 8),

        Expanded(
          child: ElevatedButton.icon(
            onPressed: () async {
              if (_tempLocation != null && widget.onLocationChanged != null) {
                // ✅ Obtener la dirección real usando geocoding
                String address = 'Ubicación seleccionada';
                
                try {
                  List<Placemark> placemarks = await placemarkFromCoordinates(
                    _tempLocation!.latitude,
                    _tempLocation!.longitude,
                  );
                  
                  if (placemarks.isNotEmpty) {
                    final place = placemarks[0];
                    List<String> parts = [];
                    
                    if (place.street?.isNotEmpty == true) parts.add(place.street!);
                    if (place.subThoroughfare?.isNotEmpty == true) parts.add(place.subThoroughfare!);
                    if (place.locality?.isNotEmpty == true) parts.add(place.locality!);
                    
                    address = parts.isNotEmpty ? parts.join(', ') : (place.country ?? 'Bolivia');
                  }
                } catch (e) {
                  print('❌ Error obteniendo dirección: $e');
                  // Si falla el geocoding, usar coordenadas como fallback
                  address = 'Lat: ${_tempLocation!.latitude.toStringAsFixed(4)}, Lng: ${_tempLocation!.longitude.toStringAsFixed(4)}';
                }
                
                widget.onLocationChanged!(_tempLocation!, address);
                
                setState(() {
                  _tempLocation = null;
                  _isEditingOnMap = false;
                });
                
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ Ubicación actualizada'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Confirmar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2D8A8A),
              foregroundColor: Colors.white,
              elevation: 4,
            ),
          ),
        ),
      ],
    );
  }
}