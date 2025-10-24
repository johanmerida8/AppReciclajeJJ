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

    // Obtener artículos del usuario
    final userArticles = await _articleDatabase.getArticlesByUserId(user!.id!);

    // Contar artículos pendientes o en proceso
    final pendingArticles = userArticles.where((article) {
      final status = article.workflowStatus?.toLowerCase() ?? '';
      return status == 'pendiente' || 
             status == 'en_proceso' ||
             status == 'aceptado';
    }).toList();

    print('📊 Usuario tiene ${pendingArticles.length} artículos pendientes de 3 máximo');

    // ✅ Permitir hasta 3 artículos pendientes
    return pendingArticles.length < 3;

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
      
      // ✅ Obtener TODOS los artículos activos del usuario
      var query = supabase
        .from('article')
        .select('idArticle, categoryID, workflowStatus')
        .eq('userID', currentUser.id!)
        .eq('state', 1); // Solo artículos activos

      // ✅ Si estamos editando, excluir el artículo actual
      if (excludeArticleId != null) {
        query = query.neq('idArticle', excludeArticleId);
      }

      final res = await query;
      
      // ✅ Filtrar por estados pendientes/en proceso
      final pendingArticles = res.where((article) {
        final status = (article['workflowStatus'] as String?)?.toLowerCase() ?? 'pendiente';
        // Incluir cualquier estado que NO sea 'completado' o 'cancelado'
        return status == 'pendiente' || 
               status == 'en_proceso' ||
               status == 'aceptado' ||
               status == 'asignado';
      }).toList();

      final categories = pendingArticles
          .map((e) => e['categoryID'] as int)
          .toSet();

      print('🔍 Categorías usadas en artículos activos del usuario ${currentUser.id}:');
      print('   Total artículos activos: ${res.length}');
      print('   Artículos pendientes/proceso: ${pendingArticles.length}');
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
      final pendingCount = await supabase
          .from('article')
          .count(CountOption.exact)
          .eq('userID', currentUser.id!)
          .eq('state', 1)
          .inFilter('workflowStatus', ['pendiente', 'asignado', 'en_proceso']);
      
      if (pendingCount == 0) {
        return 'can_publish';
      }

      // Buscar el artículo más reciente
      final latestArticle = await supabase
          .from('article')
          .select('*')
          .eq('userID', currentUser.id!)
          .eq('state', 1)
          .inFilter('workflowStatus', ['pendiente', 'asignado', 'en_proceso'])
          .order('lastUpdate', ascending: false)
          .limit(1)
          .maybeSingle();

      return latestArticle?['workflowStatus'] ?? 'unknown';
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
      final latestArticle = await supabase
          .from('article')
          .select('*')
          .eq('userID', currentUser.id!)
          .eq('state', 1)
          .inFilter('workflowStatus', ['pendiente', 'asignado', 'en_proceso'])
          .order('lastUpdate', ascending: false)
          .limit(1)
          .maybeSingle();

      if (latestArticle == null) return null;

      return {
        'id': latestArticle['idArticle'],
        'name': latestArticle['name'],
        'status': latestArticle['workflowStatus'] ?? 'pendiente',
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
      case 'pendiente':
        return 'Tu artículo está esperando revisión';
      case 'asignado':
        return 'Se ha asignado una empresa para tu artículo';
      case 'en_proceso':
        return 'Tu artículo está siendo procesado';
      case 'completado':
        return 'Proceso completado exitosamente';
      case 'can_publish':
        return 'Puedes publicar un nuevo artículo';
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