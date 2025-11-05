import 'package:reciclaje_app/database/article_database.dart';
import 'package:reciclaje_app/database/category_database.dart';
import 'package:reciclaje_app/database/deliver_database.dart';
import 'package:reciclaje_app/database/users_database.dart';
import 'package:reciclaje_app/model/article.dart';
import 'package:reciclaje_app/model/category.dart';
import 'package:reciclaje_app/model/recycling_items.dart';
// import 'package:reciclaje_app/models/recycling_item.dart';

class RecyclingDataService {
  final ArticleDatabase articleDatabase = ArticleDatabase();
  final CategoryDatabase categoryDatabase = CategoryDatabase();
  final DeliverDatabase deliverDatabase = DeliverDatabase();
  final UsersDatabase userDatabase = UsersDatabase();

  /// Load all articles and convert to RecyclingItems
  Future<List<RecyclingItem>> loadRecyclingItems() async {
    final articles = await articleDatabase.getAllArticles();
    final categories = await categoryDatabase.getAllCategories();
    
    List<RecyclingItem> items = [];

    for (Article article in articles) {
      if (article.state == 1 && 
          article.id != null && 
          article.name != null && 
          article.deliverID != null) {
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
      final deliver = await deliverDatabase.getDeliverById(article.deliverID!);
      if (deliver == null || 
          deliver.lat == null || 
          deliver.lng == null || 
          deliver.address == null) {
        return null;
      }

      // Get user info
      final user = article.userId != null 
          ? await userDatabase.getUserById(article.userId!)
          : null;

      String userName = user?.names ?? 'Usuario desconocido';
      String userEmail = user?.email ?? 'Email no disponible';

      return RecyclingItem(
        id: article.id!,
        title: article.name!,
        deliverID: article.deliverID,
        description: article.description,
        categoryID: article.categoryID,
        categoryName: category.name ?? 'Sin categoria',
        condition: article.condition ?? 'Sin estado',
        ownerUserId: article.userId,
        userName: userName,
        userEmail: userEmail,
        latitude: deliver.lat!,
        longitude: deliver.lng!,
        address: deliver.address!,
        availableDays: article.availableDays ?? '',
        availableTimeStart: article.availableTimeStart ?? '',
        availableTimeEnd: article.availableTimeEnd ?? '',
        createdAt: DateTime.now(),
        workflowStatus: article.workflowStatus,
      );
    } catch (e) {
      print('Error converting article to RecyclingItem: $e');
      return null;
    }
  }
}