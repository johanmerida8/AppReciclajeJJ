import 'package:reciclaje_app/database/article_database.dart';
import 'package:reciclaje_app/database/category_database.dart';
import 'package:reciclaje_app/database/days_available_database.dart';
import 'package:reciclaje_app/database/deliver_database.dart';
import 'package:reciclaje_app/database/users_database.dart';
import 'package:reciclaje_app/model/article.dart';
import 'package:reciclaje_app/model/category.dart';
import 'package:reciclaje_app/model/recycling_items.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// import 'package:reciclaje_app/models/recycling_item.dart';

class RecyclingDataService {
  final ArticleDatabase articleDatabase = ArticleDatabase();
  final CategoryDatabase categoryDatabase = CategoryDatabase();
  final DaysAvailableDatabase daysAvailableDatabase = DaysAvailableDatabase();
  // final DeliverDatabase deliverDatabase = DeliverDatabase();
  final UsersDatabase userDatabase = UsersDatabase();

  /// Load all articles and convert to RecyclingItems
  Future<List<RecyclingItem>> loadRecyclingItems() async {
    final articles = await articleDatabase.getAllArticles();
    final categories = await categoryDatabase.getAllCategories();
    
    List<RecyclingItem> items = [];

    for (Article article in articles) {
      if (article.state == 1 && 
          article.id != null && 
          article.name != null) {
        try {
          final item = await _convertArticleToRecyclingItem(article, categories);
          if (item != null) {
            items.add(item);
          }
        } catch (e) {
          print('Error processing article ${article.id}: $e');
        }
      }
    }

    return items;
  }

  /// Load all categories
  Future<List<String>> loadCategories() async {
    final categories = await categoryDatabase.getAllCategories();
    return categories.map((c) => c.name!).toList();
  }

  /// Convert Article to RecyclingItem
  Future<RecyclingItem?> _convertArticleToRecyclingItem(
    Article article, 
    List<Category> categories
  ) async {
    try {
      // Find category
      Category? category;
      try {
        category = categories.firstWhere((c) => c.id == article.categoryID);
      } catch (e) {
        category = Category(id: 0, name: 'Sin categoria');
      }

      // Get deliver info
      // final deliver = await deliverDatabase.getDeliverById(article.deliverID!);
      // if (deliver == null || 
      //     deliver.lat == null || 
      //     deliver.lng == null || 
      //     deliver.address == null) {
      //   return null;
      // }

      // Get user info
      final user = article.userId != null 
          ? await userDatabase.getUserById(article.userId!)
          : null;

      String userName = user?.names ?? 'Usuario desconocido';
      String userEmail = user?.email ?? 'Email no disponible';

      // Get daysAvailable data for this article
      String availableDays = '';
      String availableTimeStart = '';
      String availableTimeEnd = '';
      
      try {
        final daysAvailableList = await Supabase.instance.client
            .from('daysAvailable')
            .select()
            .eq('articleID', article.id!);
        
        if (daysAvailableList.isNotEmpty) {
          // Extract unique day names from dates
          final dayNames = <String>{};
          final dateFormat = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
          
          for (var record in daysAvailableList) {
            if (record['dateAvailable'] != null) {
              final date = DateTime.parse(record['dateAvailable']);
              final dayName = dateFormat[date.weekday - 1];
              dayNames.add(dayName);
            }
            
            // Get times from first record (assuming all have same times)
            if (availableTimeStart.isEmpty && record['startTime'] != null) {
              availableTimeStart = record['startTime'];
            }
            if (availableTimeEnd.isEmpty && record['endTime'] != null) {
              availableTimeEnd = record['endTime'];
            }
          }
          
          availableDays = dayNames.join(',');
        }
      } catch (e) {
        print('Error fetching daysAvailable for article ${article.id}: $e');
      }

      // ✅ Get workflow status from tasks table
      String? workflowStatus;
      try {
        final task = await Supabase.instance.client
            .from('tasks')
            .select('workflowStatus')
            .eq('articleID', article.id!)
            .maybeSingle();
        
        if (task != null) {
          workflowStatus = task['workflowStatus'] as String?;
        }
      } catch (e) {
        print('Error fetching workflowStatus for article ${article.id}: $e');
      }

      return RecyclingItem(
        id: article.id!,
        title: article.name!,
        // deliverID: article.deliverID,
        description: article.description,
        categoryID: article.categoryID,
        categoryName: category.name ?? 'Sin categoria',
        condition: article.condition ?? 'Sin estado',
        ownerUserId: article.userId,
        userName: userName,
        userEmail: userEmail,
        latitude: article.lat!,
        longitude: article.lng!,
        address: article.address!,
        availableDays: availableDays,
        availableTimeStart: availableTimeStart,
        availableTimeEnd: availableTimeEnd,
        createdAt: DateTime.now(),
        workflowStatus: workflowStatus, // ✅ Include workflow status
      );
    } catch (e) {
      print('Error converting article to RecyclingItem: $e');
      return null;
    }
  }
}