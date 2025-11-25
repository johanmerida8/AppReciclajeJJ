import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:reciclaje_app/auth/auth_service.dart';
import 'package:reciclaje_app/database/article_database.dart';
import 'package:reciclaje_app/database/media_database.dart';
import 'package:reciclaje_app/database/users_database.dart';
import 'package:reciclaje_app/model/article.dart';
import 'package:reciclaje_app/model/multimedia.dart';
import 'package:reciclaje_app/model/recycling_items.dart';
import 'package:reciclaje_app/model/users.dart';
import 'package:reciclaje_app/screen/distribuidor/detail_recycle_screen.dart';
import 'package:reciclaje_app/screen/distribuidor/edit_profile_screen.dart';
import 'package:reciclaje_app/screen/distribuidor/login_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final authService = AuthService();
  final usersDatabase = UsersDatabase();
  final articleDatabase = ArticleDatabase();
  final mediaDatabase = MediaDatabase();

  Users? currentUser;
  Multimedia? currentUserAvatar; // User's avatar from multimedia table
  List<Article> userArticles = [];
  List<Map<String, dynamic>> completedTasks = []; // Completed tasks with reviews
  Map<int, Multimedia?> articlePhotos = {}; // Cache for article photos
  Map<int, String> categoryNames = {}; // Cache for category names
  bool isLoading = true;
  String selectedFilter = 'Publicados'; // 'Publicados' or 'Finalizados'
  double distributorRating = 0.0; // ✅ Average rating for distributor
  int totalReviews = 0; // ✅ Total number of reviews received

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() => isLoading = true);

    try {
      final email = authService.getCurrentUserEmail();
      if (email != null) {
        // Fetch user details
        currentUser = await usersDatabase.getUserByEmail(email);
        
        print('✅ Loaded user: ${currentUser?.names} (${currentUser?.email})');
        print('✅ User role from DB: ${currentUser?.role}');
        
        // Load user avatar from multimedia table
        if (currentUser?.id != null) {
          final userRole = currentUser!.role?.toLowerCase() ?? 'user';
          
          // ✅ Try new path first (with role)
          String avatarPattern = 'users/$userRole/${currentUser!.id}/avatars/';
          currentUserAvatar = await mediaDatabase.getMainPhotoByPattern(avatarPattern);
          
          // ✅ If not found, try old path (without role) for backward compatibility
          if (currentUserAvatar == null) {
            avatarPattern = 'users/${currentUser!.id}/avatars/';
            currentUserAvatar = await mediaDatabase.getMainPhotoByPattern(avatarPattern);
            print('⚠️ Avatar found using old path structure: $avatarPattern');
          }
          
          print('📸 User avatar: ${currentUserAvatar?.url ?? "No avatar"}');
        }
        
        // Fetch user's articles
        if (currentUser?.id != null) {
          userArticles = await articleDatabase.getArticlesByUserId(currentUser!.id!);
          
          // ✅ Filter out articles with completed workflow status
          final completedArticleIds = <int>{};
          try {
            final completedTasks = await Supabase.instance.client
                .from('tasks')
                .select('articleID')
                .eq('workflowStatus', 'completado');
            
            for (var task in completedTasks) {
              if (task['articleID'] != null) {
                completedArticleIds.add(task['articleID'] as int);
              }
            }
          } catch (e) {
            print('⚠️ Error filtering completed articles: $e');
          }
          
          // Remove completed articles from published list
          userArticles = userArticles.where((article) => 
            article.id != null && !completedArticleIds.contains(article.id!)
          ).toList();
          
          print('📊 Published articles (excluding completed): ${userArticles.length}');
          
          // Load photos and category names for each article
          for (var article in userArticles) {
            if (article.id != null) {
              print('🔍 Buscando foto principal para artículo ID: ${article.id}');
              final urlPattern = 'articles/${article.id}';
              final photo = await mediaDatabase.getMainPhotoByPattern(urlPattern);
              articlePhotos[article.id!] = photo;
              
              // Fetch category name
              if (article.categoryID != null) {
                final category = await Supabase.instance.client
                    .from('category')
                    .select('name')
                    .eq('idCategory', article.categoryID!)
                    .maybeSingle();
                if (category != null) {
                  categoryNames[article.id!] = category['name'] as String;
                }
              }
            }
          }
          
          // Load completed tasks with reviews
          await _loadCompletedTasks();
          
          // ✅ Load distributor rating
          await _loadDistributorRating();
        }
      }
    } catch (e) {
      print('❌ Error loading user data: $e');
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  /// ✅ Load distributor's average rating from reviews
  Future<void> _loadDistributorRating() async {
    if (currentUser?.id == null) return;
    
    try {
      // Get all reviews where current user is the receiver (distributor)
      final reviews = await Supabase.instance.client
          .from('reviews')
          .select('starID')
          .eq('receiverID', currentUser!.id!)
          .eq('state', 1); // Only active reviews
      
      if (reviews.isEmpty) {
        setState(() {
          distributorRating = 0.0;
          totalReviews = 0;
        });
        return;
      }
      
      // Calculate average rating
      int totalStars = 0;
      for (var review in reviews) {
        totalStars += (review['starID'] as int? ?? 0);
      }
      
      final avgRating = totalStars / reviews.length;
      
      setState(() {
        distributorRating = avgRating;
        totalReviews = reviews.length;
      });
      
      print('⭐ Distributor rating: ${avgRating.toStringAsFixed(1)} stars (${reviews.length} reviews)');
    } catch (e) {
      print('❌ Error loading distributor rating: $e');
    }
  }

  /// Load completed tasks with review information
  Future<void> _loadCompletedTasks() async {
    if (currentUser?.id == null) return;
    
    try {
      final tasks = await Supabase.instance.client
          .from('tasks')
          .select('''
            idTask,
            workflowStatus,
            lastUpdate,
            article:articleID(
              idArticle,
              name,
              description,
              categoryID,
              category:categoryID(name)
            ),
            request:requestID(
              scheduledDay,
              scheduledStartTime
            )
          ''')
          .eq('workflowStatus', 'completado')
          .order('lastUpdate', ascending: false);

      // Get reviews for these tasks
      final tasksWithReviews = <Map<String, dynamic>>[];
      for (var task in tasks) {
        final articleId = task['article']?['idArticle'];
        if (articleId != null) {
          // Check if this article belongs to the current user
          final article = await Supabase.instance.client
              .from('article')
              .select('userID')
              .eq('idArticle', articleId)
              .maybeSingle();
          
          if (article != null && article['userID'] == currentUser!.id) {
            // Get reviews for this article
            final reviews = await Supabase.instance.client
                .from('reviews')
                .select('''
                  idReview,
                  starID,
                  comment,
                  senderID,
                  receiverID,
                  created_at,
                  sender:senderID(names),
                  receiver:receiverID(names)
                ''')
                .eq('articleID', articleId)
                .order('created_at', ascending: false);
            
            // Load article photo
            final urlPattern = 'articles/$articleId';
            final photo = await mediaDatabase.getMainPhotoByPattern(urlPattern);
            
            tasksWithReviews.add({
              ...task,
              'reviews': reviews,
              'photo': photo,
            });
          }
        }
      }

      if (mounted) {
        setState(() {
          completedTasks = tasksWithReviews;
        });
      }
    } catch (e) {
      print('❌ Error loading completed tasks: $e');
    }
  }

  void _logout() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar Sesión'),
        content: const Text('¿Estás seguro que deseas cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Cerrar Sesión',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await authService.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  // Navigate to edit profile screen
  void _navigateToEditProfile() async {
    if (currentUser == null) return;
    
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditProfileScreen(user: currentUser!),
      ),
    );

    // Refresh data if profile was updated
    if (result == true) {
      _loadUserData();
    }
  }

  // Convert Article to RecyclingItem for DetailRecycleScreen
  Future<RecyclingItem?> _convertArticleToRecyclingItem(Article article) async {
    try {
      // Fetch deliver info
      // final deliver = await Supabase.instance.client
      //     .from('deliver')
      //     .select('address, lat, lng')
      //     .eq('idDeliver', article.deliverID!)
      //     .single();

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

      return RecyclingItem(
        id: article.id!,
        title: article.name ?? '',
        // deliverID: article.deliverID,
        description: article.description,
        categoryID: article.categoryID,
        categoryName: categoryNames[article.id] ?? '',
        condition: article.condition,
        ownerUserId: article.userId,
        userName: currentUser?.names ?? '',
        userEmail: currentUser?.email ?? '',
        address: article.address!,
        latitude: article.lat!,
        longitude: article.lng!,
        // latitude: (deliver['lat'] as num).toDouble(),
        // longitude: (deliver['lng'] as num).toDouble(),
        // address: deliver['address'] as String,
        availableDays: availableDays,
        availableTimeStart: availableTimeStart,
        availableTimeEnd: availableTimeEnd,
        createdAt: article.lastUpdate ?? DateTime.now(),
      );
    } catch (e) {
      print('❌ Error converting article to recycling item: $e');
      return null;
    }
  }

  // Navigate to detail screen
  void _navigateToDetail(Article article) async {
    final recyclingItem = await _convertArticleToRecyclingItem(article);
    if (recyclingItem != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DetailRecycleScreen(item: recyclingItem),
        ),
      ).then((_) {
        // Refresh data when coming back
        _loadUserData();
      });
    }
  }

  // Show profile menu with edit profile and logout options (from edit icon)
  void _showProfileMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit, color: Color(0xFF2D8A8A)),
              title: const Text('Editar perfil'),
              onTap: () {
                Navigator.pop(context);
                _navigateToEditProfile();
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text(
                'Cerrar sesión',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () {
                Navigator.pop(context);
                _logout();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: const Color(0xFF2D8A8A),
        body: isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : Column(
                children: [
                  // Profile header section
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(25, 20, 25, 30),
                    child: Row(
                      children: [
                        // Avatar on the left
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.white,
                          child: currentUserAvatar?.url != null
                              ? ClipOval(
                                  child: CachedNetworkImage(
                                    imageUrl: currentUserAvatar!.url!,
                                    width: 100,
                                    height: 100,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => const Center(
                                      child: CircularProgressIndicator(
                                        color: Color(0xFF2D8A8A),
                                        strokeWidth: 2,
                                      ),
                                    ),
                                    errorWidget: (context, url, error) => const Icon(
                                      Icons.person,
                                      size: 60,
                                      color: Color(0xFF2D8A8A),
                                    ),
                                  ),
                                )
                              : const Icon(
                                  Icons.person,
                                  size: 60,
                                  color: Color(0xFF2D8A8A),
                                ),
                        ),
                        const SizedBox(width: 20),
                        // Name and role on the right
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // User name with edit icon
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      currentUser?.names ?? 'Usuario',
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: _showProfileMenu,
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.more_vert,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              // User role badge
                              Text(
                                currentUser?.role?.toUpperCase() ?? 'USUARIO',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.white70,
                                ),
                              ),
                              // ✅ Rating display
                              if (totalReviews > 0) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.star,
                                      color: Colors.amber,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      distributorRating.toStringAsFixed(1),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '($totalReviews ${totalReviews == 1 ? 'reseña' : 'reseñas'})',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Stats row
                  // Container(
                  //   margin: const EdgeInsets.symmetric(horizontal: 25),
                  //   padding: const EdgeInsets.all(20),
                  //   decoration: BoxDecoration(
                  //     color: Colors.white,
                  //     borderRadius: BorderRadius.circular(15),
                  //   ),
                  //   child: Row(
                  //     mainAxisAlignment: MainAxisAlignment.spaceAround,
                  //     children: [
                  //       _buildStatItem(
                  //         '${userArticles.length}',
                  //         'Publicados',
                  //         Colors.blue,
                  //       ),
                  //       Container(width: 1, height: 40, color: Colors.grey[300]),
                  //       _buildStatItem(
                  //         '${userArticles.where((a) => a.workflowStatus == 'en_proceso').length}',
                  //         'En Procesos',
                  //         Colors.orange,
                  //       ),
                  //       Container(width: 1, height: 40, color: Colors.grey[300]),
                  //       _buildStatItem(
                  //         '${userArticles.where((a) => a.workflowStatus == 'completado').length}',
                  //         'Recogidos',
                  //         Colors.green,
                  //       ),
                  //     ],
                  //   ),
                  // ),
                  const SizedBox(height: 20),
                  // Publications section
                  Expanded(
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(30),
                          topRight: Radius.circular(30),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.fromLTRB(25, 25, 25, 10),
                            child: Text(
                              'Publicaciones',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2D8A8A),
                              ),
                            ),
                          ),
                          // Search bar
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 25),
                            child: TextField(
                              decoration: InputDecoration(
                                hintText: 'Buscar',
                                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                                filled: true,
                                fillColor: Colors.grey[100],
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          // Filter tabs
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 25),
                            child: Row(
                              children: [
                                _buildFilterTab('Publicados'),
                                const SizedBox(width: 12),
                                _buildFilterTab('Finalizados'),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          // Articles count
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 25),
                            child: Text(
                              selectedFilter == 'Publicados'
                                  ? '${userArticles.length} artículos publicados'
                                  : '${completedTasks.length} tareas finalizadas',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                          const SizedBox(height: 15),
                          // Grid of articles or completed tasks
                          Expanded(
                            child: selectedFilter == 'Publicados'
                                ? _buildPublishedArticlesGrid()
                                : _buildCompletedTasksGrid(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // Build filter tab button
  Widget _buildFilterTab(String filterName) {
    final isSelected = selectedFilter == filterName;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            selectedFilter = filterName;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF2D8A8A) : Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            filterName,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : Colors.grey[700],
            ),
          ),
        ),
      ),
    );
  }

  // Build published articles grid
  Widget _buildPublishedArticlesGrid() {
    if (userArticles.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 80,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              'No tienes publicaciones',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.85,
        ),
        itemCount: userArticles.length,
        itemBuilder: (context, index) {
          final article = userArticles[index];
          return GestureDetector(
            onTap: () => _navigateToDetail(article),
            child: _buildArticleCard(article),
          );
        },
      ),
    );
  }

  // Build completed tasks grid
  Widget _buildCompletedTasksGrid() {
    if (completedTasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 80,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              'No hay tareas finalizadas',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.85,
        ),
        itemCount: completedTasks.length,
        itemBuilder: (context, index) {
          final task = completedTasks[index];
          return GestureDetector(
            onTap: () async {
              // Navigate to detail_recycle_screen instead of dialog
              await _navigateToCompletedTaskDetail(task);
            },
            child: _buildCompletedTaskCard(task),
          );
        },
      ),
    );
  }

  // Navigate to completed task detail screen
  Future<void> _navigateToCompletedTaskDetail(Map<String, dynamic> task) async {
    try {
      final article = task['article'] as Map<String, dynamic>?;
      if (article == null || article['idArticle'] == null) {
        print('❌ No article data in task');
        return;
      }

      final articleId = article['idArticle'] as int;
      
      // Fetch full article data
      final articleData = await articleDatabase.getArticleById(articleId);
      if (articleData == null) {
        print('❌ Article not found');
        return;
      }

      // Convert to RecyclingItem and navigate
      final recyclingItem = await _convertArticleToRecyclingItem(articleData);
      if (recyclingItem != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DetailRecycleScreen(item: recyclingItem),
          ),
        ).then((_) {
          // Refresh data when coming back
          _loadUserData();
        });
      }
    } catch (e) {
      print('❌ Error navigating to completed task detail: $e');
    }
  }

  // Format time from database
  String _formatTime(String timeStr) {
    try {
      final parts = timeStr.split(':');
      if (parts.length >= 2) {
        int hour = int.parse(parts[0]);
        final minute = parts[1].padLeft(2, '0');
        final period = hour >= 12 ? 'PM' : 'AM';
        if (hour > 12) hour -= 12;
        if (hour == 0) hour = 12;
        return '$hour:$minute $period';
      }
    } catch (e) {
      // Return as is if parsing fails
    }
    return timeStr;
  }

  // Build completed task card
  Widget _buildCompletedTaskCard(Map<String, dynamic> task) {
    final article = task['article'] as Map<String, dynamic>?;
    final photo = task['photo'] as Multimedia?;
    final category = article?['category'] as Map<String, dynamic>?;
    final reviews = task['reviews'] as List<dynamic>?;
    
    final articleName = article?['name'] ?? 'Sin título';
    final categoryName = category?['name'] ?? '';
    final imageUrl = photo?.url;
    
    // Calculate average rating
    double avgRating = 0;
    if (reviews != null && reviews.isNotEmpty) {
      final totalStars = reviews.fold<int>(0, (sum, review) => sum + (review['starID'] as int? ?? 0));
      avgRating = totalStars / reviews.length;
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: imageUrl == null ? Colors.grey[300] : null,
      ),
      child: Stack(
        children: [
          // Image
          if (imageUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: Colors.grey[300],
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF2D8A8A),
                      strokeWidth: 2,
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey[300],
                  child: Center(
                    child: Icon(
                      Icons.image_not_supported,
                      size: 40,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ),
            ),
          // Gradient overlay
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.7),
                ],
                stops: const [0.5, 1.0],
              ),
            ),
          ),
          // Completed badge
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Completado',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          // Article info at bottom
          Positioned(
            bottom: 10,
            left: 10,
            right: 10,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  articleName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        color: Colors.black,
                        blurRadius: 2,
                      ),
                    ],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                if (categoryName.isNotEmpty)
                  Text(
                    categoryName,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white70,
                      shadows: [
                        Shadow(
                          color: Colors.black,
                          blurRadius: 2,
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (avgRating > 0) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        avgRating.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(
                              color: Colors.black,
                              blurRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          // Show icon if no image
          if (imageUrl == null)
            Center(
              child: Icon(
                Icons.check_circle,
                size: 40,
                color: Colors.grey[600],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String value, String label, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildArticleCard(Article article) {
    // Simple status based on article state
    Color statusColor;
    String statusText;
    
    if (article.state == 1) {
      statusColor = Colors.green;
      statusText = 'Activo';
    } else if (article.state == 0) {
      statusColor = Colors.grey;
      statusText = 'Inactivo';
    } else {
      statusColor = Colors.orange;
      statusText = 'Desconocido';
    }

    final photo = articlePhotos[article.id];
    final imageUrl = photo?.url;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: imageUrl == null ? Colors.grey[300] : null,
      ),
      child: Stack(
        children: [
          // Image with cached network image
          if (imageUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: Colors.grey[300],
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF2D8A8A),
                      strokeWidth: 2,
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey[300],
                  child: Center(
                    child: Icon(
                      Icons.image_not_supported,
                      size: 40,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ),
            ),
          // Gradient overlay for better text visibility
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.7),
                ],
                stops: const [0.5, 1.0],
              ),
            ),
          ),
          // Status badge at top right
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                statusText,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          // Article title at bottom
          Positioned(
            bottom: 10,
            left: 10,
            right: 10,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  article.name ?? 'Sin título',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        color: Colors.black,
                        blurRadius: 2,
                      ),
                    ],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (article.condition != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    article.condition!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white70,
                      shadows: [
                        Shadow(
                          color: Colors.black,
                          blurRadius: 2,
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          // Show icon if no image
          if (imageUrl == null)
            Center(
              child: Icon(
                Icons.image_not_supported,
                size: 40,
                color: Colors.grey[600],
              ),
            ),
        ],
      ),
    );
  }
}