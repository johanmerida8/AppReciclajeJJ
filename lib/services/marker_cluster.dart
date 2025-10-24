import 'dart:math';
import 'package:latlong2/latlong.dart';
import 'package:reciclaje_app/model/recycling_items.dart';

class MarkerCluster {
  final LatLng center;
  final List<RecyclingItem> items;
  final bool isExpanded;

  MarkerCluster({
    required this.center,
    required this.items,
    this.isExpanded = false,
  });

  int get count => items.length;
  bool get isSingleItem => items.length == 1;
  bool get hasMultipleItems => items.length > 1;
  
  // ✅ Copiar con nuevo estado de expansión
  MarkerCluster copyWith({bool? isExpanded}) {
    return MarkerCluster(
      center: center,
      items: items,
      isExpanded: isExpanded ?? this.isExpanded,
    );
  }
}

class MarkerClusterService {
  // ✅ Distancia dinámica según el zoom
  static double getClusterDistance(double zoom) {
    if (zoom >= 16) return 0;     // ❌ NO clustering - mostrar separados
    if (zoom >= 14) return 0;     // ❌ NO clustering - mostrar separados
    if (zoom >= 12) return 300;   // 300 metros - zoom medio
    if (zoom >= 10) return 500;   // 500 metros - zoom lejano
    return 1000;                  // 1 km - zoom muy lejano
  }

  /// Agrupar artículos cercanos en clusters según el zoom
  List<MarkerCluster> clusterItems(List<RecyclingItem> items, double zoom) {
    if (items.isEmpty) return [];
    
    // ✅ Si hay un solo artículo, siempre mostrar como marcador individual
    if (items.length == 1) {
      return [
        MarkerCluster(
          center: LatLng(items[0].latitude, items[0].longitude),
          items: items,
        )
      ];
    }

    final clusterDistance = getClusterDistance(zoom);
    
    // ✅ Si el zoom es cercano (≥14), NO agrupar - mostrar todos separados
    if (clusterDistance == 0) {
      print('🔍 Zoom cercano ($zoom) - Mostrando ${items.length} marcadores individuales');
      return items.map((item) {
        return MarkerCluster(
          center: LatLng(item.latitude, item.longitude),
          items: [item],
        );
      }).toList();
    }

    // ✅ Zoom lejano - agrupar artículos cercanos
    print('🗺️ Zoom lejano ($zoom) - Agrupando con distancia $clusterDistance metros');
    List<MarkerCluster> clusters = [];
    List<RecyclingItem> processed = [];

    for (var item in items) {
      if (processed.contains(item)) continue;

      // Buscar artículos cercanos
      List<RecyclingItem> nearbyItems = [item];
      processed.add(item);

      for (var otherItem in items) {
        if (processed.contains(otherItem)) continue;

        double distance = _calculateDistance(
          item.latitude,
          item.longitude,
          otherItem.latitude,
          otherItem.longitude,
        );

        if (distance <= clusterDistance) {
          nearbyItems.add(otherItem);
          processed.add(otherItem);
        }
      }

      // Calcular centro del cluster
      LatLng center = _calculateClusterCenter(nearbyItems);

      clusters.add(MarkerCluster(
        center: center,
        items: nearbyItems,
      ));
    }

    print('✅ Creados ${clusters.length} clusters desde ${items.length} artículos');
    return clusters;
  }

  /// Calcular distancia entre dos puntos en metros
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000; // metros
    
    double dLat = _toRadians(lat2 - lat1);
    double dLon = _toRadians(lon2 - lon1);
    
    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) *
        sin(dLon / 2) * sin(dLon / 2);
    
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    
    return earthRadius * c;
  }

  /// Calcular centro geográfico de un cluster
  LatLng _calculateClusterCenter(List<RecyclingItem> items) {
    if (items.length == 1) {
      return LatLng(items[0].latitude, items[0].longitude);
    }

    double totalLat = 0;
    double totalLng = 0;

    for (var item in items) {
      totalLat += item.latitude;
      totalLng += item.longitude;
    }

    return LatLng(
      totalLat / items.length,
      totalLng / items.length,
    );
  }

  double _toRadians(double degrees) {
    return degrees * pi / 180;
  }
}