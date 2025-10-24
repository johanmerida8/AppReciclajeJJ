import 'package:flutter/material.dart';

class CategoryUtils {
  static Color getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'plástico':
      case 'plasticos':
        return Colors.blue;
      case 'papel':
      case 'papel carton':
      case 'cartón':
        return Colors.brown;
      case 'vidrio':
        return Colors.green;
      case 'metal':
      case 'metales':
        return Colors.grey;
      case 'electrónicos':
      case 'electronicos':
        return Colors.purple;
      case 'textiles':
        return Colors.pink;
      case 'baterías':
      case 'baterias':
        return Colors.red;
      case 'aceites':
        return Colors.amber;
      case 'residuos peligrosos':
        return Colors.deepOrange;
      case 'orgánicos':
        return Colors.lightGreen;
      case 'mis publicaciones':
        return const Color(0xFF2D8A8A);
      default:
        return const Color(0xFF2D8A8A);
    }
  }

  static IconData getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'plástico':
      case 'plasticos':
        return Icons.local_drink;
      case 'papel':
      case 'papel carton':
      case 'cartón':
        return Icons.description;
      case 'vidrio':
        return Icons.wine_bar;
      case 'metal':
      case 'metales':
        return Icons.build;
      case 'electrónicos':
      case 'electronicos':
        return Icons.devices;
      case 'textiles':
        return Icons.checkroom;
      case 'baterías':
      case 'baterias':
        return Icons.battery_std;
      case 'aceites':
        return Icons.opacity;
      case 'residuos peligrosos':
        return Icons.dangerous;
      case 'orgánicos':
        return Icons.eco;
      case 'mis publicaciones':
        return Icons.person;
      default:
        return Icons.recycling;
    }
  }
}