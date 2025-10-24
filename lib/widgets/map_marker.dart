import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:reciclaje_app/model/recycling_items.dart';
import 'package:reciclaje_app/services/marker_cluster.dart';
// import 'package:reciclaje_app/services/marker_cluster_service.dart';
import 'package:reciclaje_app/utils/category_utils.dart';

class MapMarkers {
  /// User location marker "Estás aquí"
  static Marker userLocationMarker(LatLng location) {
    return Marker(
      point: location,
      width: 100,
      height: 100,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // ✅ Círculo de pulso animado (más visible)
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.blue.withOpacity(0.2),
              border: Border.all(
                color: Colors.blue.withOpacity(0.5),
                width: 2,
              ),
            ),
          ),
          // Círculo interno
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.blue,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(
              Icons.person_pin_circle,
              color: Colors.white,
              size: 28,
            ),
          ),
          // ✅ Label "Estás aquí" más visible
          Positioned(
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: const Text(
                'Estás aquí',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Temporary marker for quick registration
  static Marker temporaryMarker(LatLng location) {
    return Marker(
      point: location,
      width: 60,
      height: 60,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.orange,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: const Icon(
          Icons.add_location,
          color: Colors.white,
          size: 30,
        ),
      ),
    );
  }

  /// Clustered article markers
  static List<Marker> clusteredArticleMarkers(
    List<RecyclingItem> items,
    Map<LatLng, bool> expandedClusters,
    Function(RecyclingItem) onItemTap,
    Function(MarkerCluster) onClusterTap,
    double currentZoom,
  ) {
    final clusterService = MarkerClusterService();
    final clusters = clusterService.clusterItems(items, currentZoom);
    
    List<Marker> markers = [];

    for (var cluster in clusters) {
      bool isExpanded = expandedClusters[cluster.center] ?? false;

      if (cluster.isSingleItem) {
        // Marcador simple para un solo artículo
        markers.add(_singleItemMarker(cluster.items[0], onItemTap));
      } else if (isExpanded) {
        // Mostrar todos los marcadores del cluster expandido
        markers.addAll(_expandedClusterMarkers(cluster, onItemTap, onClusterTap));
      } else {
        // Marcador de cluster colapsado
        markers.add(_clusterMarker(cluster, onClusterTap));
      }
    }

    return markers;
  }

  /// Marcador para un solo artículo (pequeño)
  static Marker _singleItemMarker(
    RecyclingItem item,
    Function(RecyclingItem) onTap,
  ) {
    return Marker(
      point: LatLng(item.latitude, item.longitude),
      width: 50,
      height: 50,
      child: GestureDetector(
        onTap: () => onTap(item),
        child: Container(
          decoration: BoxDecoration(
            color: CategoryUtils.getCategoryColor(item.categoryName),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            CategoryUtils.getCategoryIcon(item.categoryName),
            color: Colors.white,
            size: 24,
          ),
        ),
      ),
    );
  }

  /// Marcador de cluster (grande con contador)
  static Marker _clusterMarker(
    MarkerCluster cluster,
    Function(MarkerCluster) onTap,
  ) {
    return Marker(
      point: cluster.center,
      width: 70,
      height: 70,
      child: GestureDetector(
        onTap: () => onTap(cluster),
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

  /// Marcadores expandidos de un cluster
  static List<Marker> _expandedClusterMarkers(
    MarkerCluster cluster,
    Function(RecyclingItem) onItemTap,
    Function(MarkerCluster) onToggle,
  ) {
    List<Marker> markers = [];
    final itemCount = cluster.items.length;
    final radius = 0.0008; // Radio en grados (aprox 90 metros)

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

      markers.add(
        Marker(
          point: position,
          width: 60,
          height: 80,
          child: GestureDetector(
            onTap: () => onItemTap(item),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: Duration(milliseconds: 300 + (i * 50)),
              curve: Curves.elasticOut,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: child,
                );
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ✅ Número del artículo en el cluster
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: CategoryUtils.getCategoryColor(item.categoryName),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Text(
                      '${i + 1}/${itemCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Marcador del artículo
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: CategoryUtils.getCategoryColor(item.categoryName),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      CategoryUtils.getCategoryIcon(item.categoryName),
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Agregar marcador central para colapsar
    markers.add(_collapseClusterMarker(cluster, onToggle));

    return markers;
  }

  /// Marcador central para colapsar cluster
  static Marker _collapseClusterMarker(
    MarkerCluster cluster,
    Function(MarkerCluster) onToggle,
  ) {
    return Marker(
      point: cluster.center,
      width: 40,
      height: 40,
      child: GestureDetector(
        onTap: () {
          // Este se manejará en HomeScreen para colapsar
        },
        child: GestureDetector(
          onTap: () => onToggle(cluster),
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
            child: const Icon(
              Icons.close,
              size: 20,
              color: Color(0xFF2D8A8A),
            ),
          ),
        ),
      ),
    );
  }
}

/// Widget de navegación para clusters expandidos
class ClusterNavigationWidget extends StatefulWidget {
  final MarkerCluster cluster;
  final Function(RecyclingItem) onItemSelected;
  final VoidCallback onClose;

  const ClusterNavigationWidget({
    super.key,
    required this.cluster,
    required this.onItemSelected,
    required this.onClose,
  });

  @override
  State<ClusterNavigationWidget> createState() => _ClusterNavigationWidgetState();
}

class _ClusterNavigationWidgetState extends State<ClusterNavigationWidget> {
  int _currentIndex = 0;

  void _nextItem() {
    setState(() {
      _currentIndex = (_currentIndex + 1) % widget.cluster.items.length;
    });
    widget.onItemSelected(widget.cluster.items[_currentIndex]);
  }

  void _previousItem() {
    setState(() {
      _currentIndex = (_currentIndex - 1 + widget.cluster.items.length) % widget.cluster.items.length;
    });
    widget.onItemSelected(widget.cluster.items[_currentIndex]);
  }

  @override
  Widget build(BuildContext context) {
    final currentItem = widget.cluster.items[_currentIndex];
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Artículo ${_currentIndex + 1} de ${widget.cluster.items.length}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Color(0xFF2D8A8A),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: widget.onClose,
                color: Colors.grey,
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Item info
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: CategoryUtils.getCategoryColor(currentItem.categoryName),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  CategoryUtils.getCategoryIcon(currentItem.categoryName),
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentItem.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      currentItem.categoryName,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Navigation buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Previous
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: widget.cluster.items.length > 1 ? _previousItem : null,
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text('Anterior'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF2D8A8A),
                  ),
                ),
              ),
              
              const SizedBox(width: 12),
              
              // View details
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => widget.onItemSelected(currentItem),
                  icon: const Icon(Icons.visibility, size: 18),
                  label: const Text('Ver'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2D8A8A),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              
              const SizedBox(width: 12),
              
              // Next
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: widget.cluster.items.length > 1 ? _nextItem : null,
                  icon: const Icon(Icons.arrow_forward, size: 18),
                  label: const Text('Siguiente'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF2D8A8A),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}