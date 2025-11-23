// ✅ Servicio para validación de workflow de artículos
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_service.dart';
import '../database/article_database.dart';
import '../database/users_database.dart';

class WorkflowService {
  static final _instance = WorkflowService._internal();
  factory WorkflowService() => _instance;
  WorkflowService._internal();

  final _authService = AuthService();
  final _articleDatabase = ArticleDatabase();
  final _userDatabase = UsersDatabase();

  /// Verificar si el usuario puede publicar nuevos artículos
  Future<bool> canUserPublish() async {
  try {
    final email = _authService.getCurrentUserEmail();
    if (email == null) return false;

    final user = await _userDatabase.getUserByEmail(email);
    if (user?.id == null) return false;

    // Obtener artículos activos del usuario (state = 1)
    final userArticles = await _articleDatabase.getArticlesByUserId(user!.id!);
    
    // ✅ Get completed article IDs from tasks table
    final supabase = Supabase.instance.client;
    final completedTasks = await supabase
        .from('tasks')
        .select('articleID')
        .eq('workflowStatus', 'completado');
    
    final completedArticleIds = completedTasks
        .map((task) => task['articleID'] as int?)
        .where((id) => id != null)
        .cast<int>()
        .toSet();
    
    // ✅ Contar artículos activos (state = 1) que NO están completados
    final activeArticles = userArticles.where((article) => 
      article.state == 1 && 
      (article.id == null || !completedArticleIds.contains(article.id))
    ).toList();

    print('📊 Usuario tiene ${activeArticles.length} artículos activos de 3 máximo (excluyendo completados)');
    print('📊 Total artículos en DB: ${userArticles.length}, Completados: ${completedArticleIds.length}');

    // ✅ Permitir hasta 3 artículos activos
    return activeArticles.length < 3;

  } catch (e) {
    print('❌ Error verificando si usuario puede publicar: $e');
    return false;
  }
}

  Future<Set<int>> getUsedPendingCategoryIds({int? excludeArticleId}) async {
    try {
      final currentUserEmail = _authService.getCurrentUserEmail();
      if (currentUserEmail == null) return {};

      final currentUser = await _userDatabase.getUserByEmail(currentUserEmail);
      if (currentUser == null) return {};

      final supabase = Supabase.instance.client;
      
      // ✅ Get completed article IDs first
      final completedTasks = await supabase
          .from('tasks')
          .select('articleID')
          .eq('workflowStatus', 'completado');
      
      final completedArticleIds = completedTasks
          .map((task) => task['articleID'] as int?)
          .where((id) => id != null)
          .cast<int>()
          .toSet();
      
      // ✅ Obtener TODOS los artículos activos del usuario
      var query = supabase
        .from('article')
        .select('idArticle, categoryID')
        .eq('userID', currentUser.id!)
        .eq('state', 1); // Solo artículos activos

      // ✅ Si estamos editando, excluir el artículo actual
      if (excludeArticleId != null) {
        query = query.neq('idArticle', excludeArticleId);
      }

      final res = await query;
      
      // ✅ Filter out completed articles
      final activeArticles = res.where((article) => 
        !completedArticleIds.contains(article['idArticle'] as int)
      ).toList();
      
      final categories = activeArticles
          .map((e) => e['categoryID'] as int)
          .toSet();

      print('🔍 Categorías usadas en artículos activos (sin completados) del usuario ${currentUser.id}:');
      print('   Total artículos activos: ${res.length}');
      print('   Artículos completados excluidos: ${completedArticleIds.length}');
      print('   Artículos activos válidos: ${activeArticles.length}');
      print('   Categorías bloqueadas: $categories');
      if (excludeArticleId != null) {
        print('   Excluyendo artículo: $excludeArticleId');
      }
      
      return categories;
    } catch (e) {
      print('❌ Error obteniendo categorías pendientes: $e');
      return {};
    }
  }
  

  /// Obtener el estado actual del workflow del usuario
  Future<String> getUserWorkflowStatus() async {
    try {
      final currentUserEmail = _authService.getCurrentUserEmail();
      if (currentUserEmail == null) return 'no_authenticated';
      
      final currentUser = await _userDatabase.getUserByEmail(currentUserEmail);
      if (currentUser == null) return 'user_not_found';
      
      final supabase = Supabase.instance.client;
      
      // ✅ Get completed article IDs
      final completedTasks = await supabase
          .from('tasks')
          .select('articleID')
          .eq('workflowStatus', 'completado');
      
      final completedArticleIds = completedTasks
          .map((task) => task['articleID'] as int?)
          .where((id) => id != null)
          .cast<int>()
          .toSet();
      
      // Get all active articles
      final allActiveArticles = await supabase
          .from('article')
          .select('idArticle')
          .eq('userID', currentUser.id!)
          .eq('state', 1);
      
      // ✅ Filter out completed articles
      final activeCount = allActiveArticles
          .where((article) => !completedArticleIds.contains(article['idArticle'] as int))
          .length;
      
      if (activeCount == 0) {
        return 'can_publish';
      } else if (activeCount < 3) {
        return 'can_publish';
      } else {
        return 'limit_reached';
      }
    } catch (e) {
      print('❌ Error obteniendo estado del workflow: $e');
      return 'error';
    }
  }

  /// Obtener información del artículo en proceso
  Future<Map<String, dynamic>?> getActiveArticleInfo() async {
    try {
      final currentUserEmail = _authService.getCurrentUserEmail();
      if (currentUserEmail == null) return null;
      
      final currentUser = await _userDatabase.getUserByEmail(currentUserEmail);
      if (currentUser == null) return null;
      
      final supabase = Supabase.instance.client;
      
      // Buscar artículos activos del usuario
      final latestArticle = await supabase
          .from('article')
          .select('*')
          .eq('userID', currentUser.id!)
          .eq('state', 1)
          .order('lastUpdate', ascending: false)
          .limit(1)
          .maybeSingle();

      if (latestArticle == null) return null;

      return {
        'id': latestArticle['idArticle'],
        'name': latestArticle['name'],
        'status': 'active',
        'created': latestArticle['lastUpdate'] != null 
            ? DateTime.parse(latestArticle['lastUpdate']) 
            : DateTime.now(),
      };
    } catch (e) {
      print('❌ Error obteniendo info del artículo activo: $e');
      return null;
    }
  }

  /// Obtener mensaje descriptivo del estado del workflow
  String getWorkflowStatusMessage(String status) {
    switch (status) {
      case 'active':
        return 'Artículo activo';
      case 'can_publish':
        return 'Puedes publicar un nuevo artículo';
      case 'limit_reached':
        return 'Has alcanzado el límite de 3 artículos activos';
      case 'no_authenticated':
        return 'Usuario no autenticado';
      case 'user_not_found':
        return 'Usuario no encontrado';
      case 'error':
        return 'Error verificando estado';
      default:
        return 'Estado desconocido';
    }
  }
}