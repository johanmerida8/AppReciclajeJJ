import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
// import 'package:reciclaje_app/screen/distribuidor/map_picker_screen.dart';

class LocationSelector extends StatelessWidget {
  final LatLng? selectedLocation;
  final String? selectedAddress;
  final VoidCallback onPickLocation;
  final bool isRequired;
  final String labelText;

  const LocationSelector({
    super.key,
    this.selectedLocation,
    this.selectedAddress,
    required this.onPickLocation,
    this.isRequired = false,
    this.labelText = 'Preferencia de entrega',
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          labelText,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2D8A8A),
          ),
        ),
        const SizedBox(height: 8),
        
        GestureDetector(
          onTap: onPickLocation,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(
                color: selectedLocation == null 
                    ? Colors.grey 
                    : const Color(0xFF2D8A8A),
                width: 2,
              ),
              borderRadius: BorderRadius.circular(8),
              color: selectedLocation == null 
                  ? Colors.grey.shade50 
                  : const Color(0xFF2D8A8A).withOpacity(0.1),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.location_on,
                  color: selectedLocation == null 
                      ? Colors.grey 
                      : const Color(0xFF2D8A8A),
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        selectedLocation == null 
                            ? 'Seleccionar ubicación'
                            : 'Ubicación seleccionada',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: selectedLocation == null 
                              ? Colors.grey.shade600 
                              : const Color(0xFF2D8A8A),
                        ),
                      ),
                      if (selectedAddress != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          selectedAddress!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          softWrap: true,
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  selectedLocation == null 
                      ? Icons.add_location_alt 
                      : Icons.edit_location_alt,
                  color: selectedLocation == null 
                      ? Colors.grey 
                      : const Color(0xFF2D8A8A),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}