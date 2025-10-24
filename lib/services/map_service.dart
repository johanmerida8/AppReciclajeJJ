import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:reciclaje_app/model/recycling_items.dart';

class MapService {
  static const double closeZoomLevel = 18.0;
  static const double farZoomLevel = 11.0;
  static const LatLng cochabambaCenter = LatLng(-17.3895, -66.1568);

  /// Calculate tile coordinates
  int getTileX(double lng, int zoom) {
    return ((lng + 180) / 360 * (1 << zoom)).floor();
  }

  int getTileY(double lat, int zoom) {
    final latRad = lat * pi / 180;
    return ((1 - log(tan(latRad) + 1 / cos(latRad)) / pi) / 2 * (1 << zoom)).floor();
  }

  /// Fit map to show all articles
  void fitMapToShowAllArticles(
    MapController mapController,
    List<RecyclingItem> filteredItems,
    LatLng? currentUserLocation,
    bool hasUserLocation,
  ) {
    // ✅ Verificar si el mapa está listo
    if (!isMapReady(mapController)) {
      print('⚠️ Mapa no está listo todavía, esperando...');
      return;
    }

    if (filteredItems.isEmpty) {
      // Si no hay artículos, centrar en ubicación del usuario o Cochabamba
      if (hasUserLocation && currentUserLocation != null) {
        _safeMove(mapController, currentUserLocation, closeZoomLevel);
      } else {
        _safeMove(mapController, cochabambaCenter, farZoomLevel);
      }
      return;
    }

    // Calcular límites de todos los artículos
    double minLat = filteredItems.first.latitude;
    double maxLat = filteredItems.first.latitude;
    double minLng = filteredItems.first.longitude;
    double maxLng = filteredItems.first.longitude;

    for (var item in filteredItems) {
      minLat = min(minLat, item.latitude);
      maxLat = max(maxLat, item.latitude);
      minLng = min(minLng, item.longitude);
      maxLng = max(maxLng, item.longitude);
    }

    // Incluir ubicación del usuario si está disponible
    if (hasUserLocation && currentUserLocation != null) {
      minLat = min(minLat, currentUserLocation.latitude);
      maxLat = max(maxLat, currentUserLocation.latitude);
      minLng = min(minLng, currentUserLocation.longitude);
      maxLng = max(maxLng, currentUserLocation.longitude);
    }

    // Agregar padding a los límites
    final latPadding = (maxLat - minLat) * 0.1;
    final lngPadding = (maxLng - minLng) * 0.1;

    final bounds = LatLngBounds(
      LatLng(minLat - latPadding, minLng - lngPadding),
      LatLng(maxLat + latPadding, maxLng + lngPadding),
    );

    // Ajustar el mapa para mostrar todos los puntos
    try {
      mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(50),
        ),
      );
      print('✅ Mapa ajustado para mostrar ${filteredItems.length} artículos');
    } catch (e) {
      print('❌ Error ajustando mapa: $e');
    }
  }

  /// Verificar si el MapController está listo para ser usado
  bool isMapReady(MapController mapController) {
    try {
      // Intentar acceder a la cámara del mapa
      mapController.camera;
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Mover el mapa de forma segura
  void _safeMove(MapController mapController, LatLng location, double zoom) {
    try {
      if (isMapReady(mapController)) {
        mapController.move(location, zoom);
        print('✅ Mapa movido a: ${location.latitude}, ${location.longitude}');
      }
    } catch (e) {
      print('❌ Error moviendo mapa: $e');
    }
  }
}