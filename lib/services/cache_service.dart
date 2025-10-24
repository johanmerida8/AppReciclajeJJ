// ✅ Servicio para manejo de caché inteligente
import 'dart:convert';
import 'package:reciclaje_app/model/recycling_items.dart';
import 'package:shared_preferences/shared_preferences.dart';
// import '../screen/home_screen.dart';

class CacheService {
  static final _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  static const String _cacheKeyArticles = 'cached_articles';
  static const String _cacheKeyCategories = 'cached_categories';
  static const String _cacheKeyTimestamp = 'cache_timestamp';
  static const String _cacheKeyUserId = 'cached_user_id';
  static const Duration _cacheExpiration = Duration(minutes: 15);

  /// Guardar datos en caché
  Future<void> saveCache(List<RecyclingItem> articles, List<String> categories, int? userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Convertir artículos a JSON
      final articlesJson = articles.map((item) => item.toJson()).toList();
      
      await prefs.setString(_cacheKeyArticles, jsonEncode(articlesJson));
      await prefs.setStringList(_cacheKeyCategories, categories);
      await prefs.setString(_cacheKeyTimestamp, DateTime.now().toIso8601String());
      if (userId != null) {
        await prefs.setInt(_cacheKeyUserId, userId);
      }
      
      print('✅ Cache guardado exitosamente: ${articles.length} artículos, ${categories.length} categorías');
    } catch (e) {
      print('❌ Error guardando cache: $e');
    }
  }

  /// Cargar datos desde caché
  Future<Map<String, dynamic>?> loadCache(int? currentUserId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Verificar si existe cache
      if (!prefs.containsKey(_cacheKeyArticles) || 
          !prefs.containsKey(_cacheKeyTimestamp)) {
        print('📭 No hay cache disponible');
        return null;
      }
      
      // Verificar expiración
      final timestampStr = prefs.getString(_cacheKeyTimestamp);
      if (timestampStr == null) return null;
      
      final cacheTime = DateTime.parse(timestampStr);
      final now = DateTime.now();
      
      if (now.difference(cacheTime) > _cacheExpiration) {
        print('⏰ Cache expirado (${now.difference(cacheTime).inMinutes} min)');
        await clearCache();
        return null;
      }
      
      // Verificar usuario (invalidar cache si cambió de usuario)
      final cachedUserId = prefs.getInt(_cacheKeyUserId);
      if (currentUserId != null && cachedUserId != currentUserId) {
        print('👤 Usuario diferente, invalidando cache');
        await clearCache();
        return null;
      }
      
      // Cargar datos
      final articlesJson = prefs.getString(_cacheKeyArticles);
      final categories = prefs.getStringList(_cacheKeyCategories) ?? [];
      
      if (articlesJson == null) return null;
      
      final articlesData = jsonDecode(articlesJson) as List;
      final articles = articlesData
          .map((json) => RecyclingItem.fromJson(json))
          .toList();
      
      final ageInMinutes = now.difference(cacheTime).inMinutes;
      print('📦 Cache cargado exitosamente (${ageInMinutes}min): ${articles.length} artículos');
      
      return {
        'articles': articles,
        'categories': categories,
        'fromCache': true,
      };
      
    } catch (e) {
      print('❌ Error cargando cache: $e');
      await clearCache(); // Limpiar cache corrupto
      return null;
    }
  }

  /// Limpiar caché
  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKeyArticles);
      await prefs.remove(_cacheKeyCategories);
      await prefs.remove(_cacheKeyTimestamp);
      await prefs.remove(_cacheKeyUserId);
      print('🗑️ Cache limpiado');
    } catch (e) {
      print('❌ Error limpiando cache: $e');
    }
  }

  /// Verificar si existe caché válido
  Future<bool> hasCacheData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      if (!prefs.containsKey(_cacheKeyTimestamp)) return false;
      
      final timestampStr = prefs.getString(_cacheKeyTimestamp);
      if (timestampStr == null) return false;
      
      final cacheTime = DateTime.parse(timestampStr);
      final now = DateTime.now();
      
      return now.difference(cacheTime) <= _cacheExpiration;
    } catch (e) {
      return false;
    }
  }
}