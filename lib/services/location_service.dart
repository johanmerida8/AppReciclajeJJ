// ✅ Servicio para manejo de ubicación y GPS
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart' as loc;

class LocationService {
  static final _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  final loc.Location _location = loc.Location();
  static const LatLng _defaultLocation = LatLng(-17.3895, -66.1568); // Cochabamba

  LatLng? _lastKnownLocation;
  /// Getter público para acceder a la última ubicación conocida
  LatLng? get lastKnownLocation => _lastKnownLocation;


  /// Obtener ubicación actual del usuario (optimizada y más rápida)
  Future<LatLng?> getCurrentLocation() async {
    try {
      print('📡 [LocationService] Solicitando ubicación...');

      // 1️⃣ Verificar servicio de ubicación primero
      bool serviceEnabled = await _location.serviceEnabled();
      if (!serviceEnabled) {
        print('❌ GPS no activado');
        _lastKnownLocation = null; // ✅ Limpiar caché si GPS está desactivado
        return null;
      }

      // 2️⃣ Verificar permisos
      loc.PermissionStatus permissionGranted = await _location.hasPermission();
      if (permissionGranted == loc.PermissionStatus.denied) {
        print('⚠️ Permisos de ubicación no otorgados');
        _lastKnownLocation = null;
        return null;
      }

      if (permissionGranted == loc.PermissionStatus.deniedForever) {
        print('❌ Permisos denegados permanentemente');
        _lastKnownLocation = null;
        return null;
      }

      // 3️⃣ Si tenemos caché reciente Y el GPS está activo, usar esa primero
      if (_lastKnownLocation != null) {
        print('⚡ Usando ubicación en caché: '
            '${_lastKnownLocation!.latitude}, ${_lastKnownLocation!.longitude}');
        // Actualizar en segundo plano para obtener ubicación más precisa
        _updateLocationInBackground();
        return _lastKnownLocation!;
      }

      // 4️⃣ Obtener ubicación nueva con timeout extendido
      print('🔍 Obteniendo ubicación GPS nueva...');
      final locationData = await _location.getLocation().timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          print('⏱️ Timeout obteniendo ubicación (15s)');
          throw Exception('Timeout obteniendo ubicación');
        },
      );

      if (locationData.latitude != null && locationData.longitude != null) {
        final userLocation = LatLng(locationData.latitude!, locationData.longitude!);
        _lastKnownLocation = userLocation;
        print('✅ Ubicación GPS obtenida: ${userLocation.latitude}, ${userLocation.longitude}');
        return userLocation;
      }

      print('❌ No se pudo obtener coordenadas válidas');
      return null;
    } catch (e) {
      print('❌ Error obteniendo ubicación: $e');
      // Si hay error pero tenemos caché, devolver caché
      if (_lastKnownLocation != null) {
        print('⚠️ Usando última ubicación conocida por error');
        return _lastKnownLocation;
      }
      return null;
    }
  }

  /// ✅ NUEVO: Actualizar ubicación en segundo plano
  void _updateLocationInBackground() {
    _location.getLocation().timeout(
      const Duration(seconds: 8),
    ).then((locationData) {
      if (locationData.latitude != null && locationData.longitude != null) {
        final newLocation = LatLng(locationData.latitude!, locationData.longitude!);
        
        // Solo actualizar si la nueva ubicación es diferente
        if (_lastKnownLocation == null ||
            (_lastKnownLocation!.latitude != newLocation.latitude ||
             _lastKnownLocation!.longitude != newLocation.longitude)) {
          _lastKnownLocation = newLocation;
          print('🔄 Ubicación actualizada en segundo plano: '
              '${newLocation.latitude}, ${newLocation.longitude}');
        }
      }
    }).catchError((e) {
      print('⚠️ Error actualizando ubicación en segundo plano: $e');
    });
  }


  /// ✅ NUEVO: Solicitar permisos de ubicación explícitamente
  Future<bool> requestLocationPermission() async {
    try {
      print('🔐 Solicitando permisos de ubicación...');
      
      loc.PermissionStatus permissionStatus = await _location.hasPermission();
      
      if (permissionStatus == loc.PermissionStatus.denied) {
        permissionStatus = await _location.requestPermission();
      }
      
      final granted = permissionStatus == loc.PermissionStatus.granted;
      
      if (granted) {
        print('✅ Permisos de ubicación otorgados');
      } else {
        print('❌ Permisos de ubicación denegados');
      }
      
      return granted;
    } catch (e) {
      print('❌ Error solicitando permisos de ubicación: $e');
      return false;
    }
  }

  /// ✅ NUEVO: Solicitar activación del servicio de ubicación (GPS)
  Future<bool> requestLocationService() async {
    try {
      print('📍 Solicitando activación del servicio de ubicación...');
      
      bool serviceEnabled = await _location.serviceEnabled();
      
      if (!serviceEnabled) {
        serviceEnabled = await _location.requestService();
      }
      
      if (serviceEnabled) {
        print('✅ Servicio de ubicación activado');
      } else {
        print('❌ Servicio de ubicación no activado');
      }
      
      return serviceEnabled;
    } catch (e) {
      print('❌ Error solicitando servicio de ubicación: $e');
      return false;
    }
  }

  /// Verificar estado de los servicios de ubicación
  Future<Map<String, bool>> checkLocationStatus() async {
    try {
      final serviceEnabled = await _location.serviceEnabled();
      final permission = await _location.hasPermission();
      final hasPermission = permission == loc.PermissionStatus.granted;

      // ✅ Limpiar caché si GPS está desactivado
      if (!serviceEnabled || !hasPermission) {
        _lastKnownLocation = null;
      }

      print('📊 Estado de ubicación:');
      print('   Servicio habilitado: $serviceEnabled');
      print('   Permisos otorgados: $hasPermission');

      return {
        'serviceEnabled': serviceEnabled,
        'hasPermission': hasPermission,
      };
    } catch (e) {
      print('❌ Error verificando estado de ubicación: $e');
      _lastKnownLocation = null;
      return {
        'serviceEnabled': false,
        'hasPermission': false,
      };
    }
  }

  /// ✅ NUEVO: Limpiar caché de ubicación
  void clearLocationCache() {
    _lastKnownLocation = null;
    print('🗑️ Caché de ubicación limpiado');
  }

  /// Verificar si los servicios de ubicación están disponibles
  Future<bool> isLocationServiceEnabled() async {
    try {
      return await _location.serviceEnabled();
    } catch (e) {
      print('❌ Error verificando servicios de ubicación: $e');
      return false;
    }
  }

  /// Verificar permisos de ubicación
  Future<bool> hasLocationPermission() async {
    try {
      final permission = await _location.hasPermission();
      return permission == loc.PermissionStatus.granted;
    } catch (e) {
      print('❌ Error verificando permisos: $e');
      return false;
    }
  }

  /// Obtener ubicación por defecto (Cochabamba)
  LatLng get defaultLocation => _defaultLocation;

  /// Mostrar diálogo para habilitar ubicación
  void showLocationServiceDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.location_off, color: Colors.orange, size: 24),
              ),
              const SizedBox(width: 12),
              const Text('Ubicación Desactivada'),
            ],
          ),
          content: const Text(
            'Para una mejor experiencia, activa los servicios de ubicación en tu dispositivo.\n\n'
            'Esto te permitirá ver tu posición actual en el mapa.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Ahora no'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _location.requestService();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2D8A8A),
                foregroundColor: Colors.white,
              ),
              child: const Text('Activar'),
            ),
          ],
        );
      },
    );
  }

  /// ✅ NUEVO: Mostrar diálogo de permisos denegados
  void showPermissionDeniedDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.location_disabled, color: Colors.red, size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Permiso Denegado',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'No podemos acceder a tu ubicación porque denegaste el permiso.',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 16),
              Text(
                'Para habilitar el acceso:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                '1. Ve a Configuración\n'
                '2. Busca esta aplicación\n'
                '3. Habilita permisos de ubicación\n'
                '4. Reinicia la app',
                style: TextStyle(fontSize: 13, height: 1.4),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2D8A8A),
                foregroundColor: Colors.white,
              ),
              child: const Text('Entendido'),
            ),
          ],
        );
      },
    );
  }
}