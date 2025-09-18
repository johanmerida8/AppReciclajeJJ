import 'package:reciclaje_app/model/category.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CategoryDatabase {
  final database = Supabase.instance.client.from('category');

  // Fetch all categories
  Future<List<Category>> getAllCategories() async {
    try {
      final response = await database.select();
      return response.map((map) => Category.fromMap(map)).toList();
    } catch (e) {
      print('Error al obtener categorías: $e');
      rethrow;
    }
  }

  // Get category by name
  Future<Category?> getCategoryByName(String name) async {
    try {
      final response = await database.select().eq('name', name).single();
      return Category.fromMap(response);
    } catch (e) {
      print('Error al obtener categoría por nombre: $e');
      return null;
    }
  }
}
