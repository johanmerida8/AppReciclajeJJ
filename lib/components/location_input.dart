import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';

class LocationInput extends StatefulWidget {
  final void Function(double lat, double lng, {bool fromMap}) onSelectLocation;
  final LatLng initialLocation;

  const LocationInput({
    super.key,
    required this.onSelectLocation,
    required this.initialLocation,
  });

  @override
  State<LocationInput> createState() => _LocationInputState();
}

class _LocationInputState extends State<LocationInput> {
  LocationData? _pickedLocation;
  bool _isGettingLocation = false;
  final Location _location = Location(); // Create instance at class level

  @override
  void initState() {
    super.initState();
    _initializeLocationService(); // Initialize GPS service when widget loads
  }

  // Initialize location service in advance
  Future<void> _initializeLocationService() async {
    try {
      await _location.serviceEnabled();
      await _location.hasPermission();
    } catch (e) {
      print('Location service initialization: $e');
    }
  }

  Future<void> _getUserLocation() async {
    setState(() {
      _isGettingLocation = true;
    });

    try {
      // Check service availability
      bool serviceEnabled = await _location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await _location.requestService();
        if (!serviceEnabled) {
          _showErrorSnackBar('El servicio de ubicación está deshabilitado. Por favor, actívalo en la configuración del dispositivo.');
          return;
        }
      }

      // Check permissions
      PermissionStatus permissionGranted = await _location.hasPermission();
      if (permissionGranted == PermissionStatus.denied) {
        permissionGranted = await _location.requestPermission();
        if (permissionGranted != PermissionStatus.granted) {
          _showErrorSnackBar('Permisos de ubicación denegados. Por favor, permite el acceso a la ubicación.');
          return;
        }
      }

      // Show loading message for first-time GPS initialization
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: 12),
                Text('Obteniendo ubicación GPS...'),
              ],
            ),
            backgroundColor: Color(0xFF2D8A8A),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      // Get location with longer timeout for first-time GPS lock
      final locationData = await _location.getLocation().timeout(
        const Duration(seconds: 15), // Increased timeout for GPS initialization
        onTimeout: () => throw Exception('Tiempo de espera agotado. Intenta nuevamente.'),
      );

      // Check if location is the same as before
      bool isSameLocation = _pickedLocation != null &&
          _pickedLocation!.latitude == locationData.latitude &&
          _pickedLocation!.longitude == locationData.longitude;
      
      setState(() {
        _pickedLocation = locationData;
      });

      if (isSameLocation) {
        if (mounted) {
          _showErrorSnackBar('Ya tienes esta ubicación seleccionada.');
        }
      } else if (locationData.latitude != null && locationData.longitude != null) {
        // Successfully got location
        widget.onSelectLocation(locationData.latitude!, locationData.longitude!, fromMap: false);
      } else {
        _showErrorSnackBar('No se pudo obtener la ubicación actual. Verifica que el GPS esté activo.');
      }
    } catch (e) {
      print('GPS Error: $e');
      String errorMessage = 'No se pudo obtener la ubicación.';
      
      if (e.toString().contains('Tiempo de espera agotado')) {
        errorMessage = 'GPS tardando mucho. Asegúrate de estar al aire libre e intenta nuevamente.';
      } else if (e.toString().contains('denied')) {
        errorMessage = 'Permisos de ubicación denegados.';
      } else if (e.toString().contains('disabled')) {
        errorMessage = 'Servicio de ubicación deshabilitado.';
      }
      
      _showErrorSnackBar(errorMessage);
    } finally {
      setState(() {
        _isGettingLocation = false;
      });
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red.shade600,
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Reintentar',
            textColor: Colors.white,
            onPressed: _getUserLocation,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      heroTag: "location_input",
      onPressed: _isGettingLocation ? null : _getUserLocation,
      backgroundColor: const Color(0xFF2D8A8A),
      elevation: 6,
      child: _isGettingLocation 
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
          : const Icon(Icons.my_location, color: Colors.white),
    );
  }
}