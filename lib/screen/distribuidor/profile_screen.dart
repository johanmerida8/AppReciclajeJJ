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
  List<Article> filteredArticles = []; // Filtered and sorted articles
  List<Map<String, dynamic>> completedTasks =
      []; // Completed tasks with reviews
  Map<int, Multimedia?> articlePhotos = {}; // Cache for article photos
  Map<int, String> categoryNames = {}; // Cache for category names
  Map<int, String> articleStatuses =
      {}; // Cache for article statuses from tasks
  bool isLoading = true;
  Set<String> selectedStatusFilters =
      {}; // Filter by status: 'publicados', 'en_proceso', 'entregados'
  double distributorRating = 0.0; // ✅ Average rating for distributor
  int totalReviews = 0; // ✅ Total number of reviews received

  // Stats data for Objetos card
  Map<String, int> articleStats = {
    'publicados': 0,
    'enProceso': 0,
    'entregados': 0,
  };

  // Filter and search state
  String searchQuery = '';
  bool sortAscending = false; // false = newest first, true = oldest first

  // Pagination state
  final ScrollController _scrollController = ScrollController();
  int _currentArticlePage = 1;
  final int _articlesPerPage =
      4; // ✅ Reduced from 6 to 4 for better performance
  bool _isLoadingMoreArticles = false;
  bool _hasMoreArticles = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onArticleScroll);
    _loadUserData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    articlePhotos.clear();
    categoryNames.clear();
    articleStatuses.clear();
    userArticles.clear();
    filteredArticles.clear();
    completedTasks.clear();
    super.dispose();
  }

  void _onArticleScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMoreArticles && _hasMoreArticles) {
        _loadMoreArticles();
      }
    }
  }

  Future<void> _loadMoreArticles() async {
    if (_isLoadingMoreArticles || !_hasMoreArticles) return;

    setState(() {
      _isLoadingMoreArticles = true;
    });

    await Future.delayed(const Duration(milliseconds: 500));

    setState(() {
      _currentArticlePage++;
      _isLoadingMoreArticles = false;
    });
  }

  Future<void> _loadUserData() async {
    try {
      final email = authService.getCurrentUserEmail();
      if (email != null) {
        // ✅ Load basic user details first (fast)
        currentUser = await usersDatabase.getUserByEmail(email);

        print('✅ Loaded user: ${currentUser?.names} (${currentUser?.email})');

        // ✅ Show UI immediately with basic data
        if (mounted) {
          setState(() => isLoading = false);
        }

        // ✅ Load user avatar in background
        if (currentUser?.id != null && mounted) {
          final userRole = currentUser!.role?.toLowerCase() ?? 'user';
          String avatarPattern = 'users/$userRole/${currentUser!.id}/avatars/';
          currentUserAvatar = await mediaDatabase.getMainPhotoByPattern(
            avatarPattern,
          );

          if (currentUserAvatar == null) {
            avatarPattern = 'users/${currentUser!.id}/avatars/';
            currentUserAvatar = await mediaDatabase.getMainPhotoByPattern(
              avatarPattern,
            );
          }

          if (mounted) setState(() {});
        }

        // ✅ Fetch user's articles
        if (currentUser?.id != null && mounted) {
          userArticles = await articleDatabase.getArticlesByUserId(
            currentUser!.id!,
          );

          if (!mounted) return; // Early exit if disposed

          print(
            '📦 Found ${userArticles.length} articles - loading progressively',
          );

          // ✅ Load article statuses first (lightweight query)
          await _loadArticleStatuses();

          if (!mounted) return; // Early exit if disposed

          // ✅ Calculate stats and apply filters early
          _calculateStats();
          _applyFilters();

          if (mounted) setState(() {});

          // ✅ Load photos and categories progressively in smaller batches
          const batchSize = 3; // Process 3 articles at a time
          for (var i = 0; i < userArticles.length; i += batchSize) {
            if (!mounted) break;

            final batch = userArticles.skip(i).take(batchSize);

            // Load batch data in parallel
            await Future.wait(
              batch.map((article) async {
                if (article.id != null) {
                  // Load photo
                  final urlPattern = 'articles/${article.id}';
                  final photo = await mediaDatabase.getMainPhotoByPattern(
                    urlPattern,
                  );
                  articlePhotos[article.id!] = photo;

                  // Load category name
                  if (article.categoryID != null &&
                      !categoryNames.containsKey(article.id)) {
                    final category =
                        await Supabase.instance.client
                            .from('category')
                            .select('name')
                            .eq('idCategory', article.categoryID!)
                            .maybeSingle();
                    if (category != null) {
                      categoryNames[article.id!] = category['name'] as String;
                    }
                  }
                }
              }),
            );

            // Update UI after each batch
            if (mounted) {
              setState(() {});
              // Small delay to prevent UI blocking
              await Future.delayed(const Duration(milliseconds: 50));
            }
          }

          // ✅ Load secondary data in background (non-critical)
          if (mounted) {
            _loadDistributorRating();
            _loadCompletedTasks();
          }
        }
      }
    } catch (e) {
      print('❌ Error loading user data: $e');
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  /// Load article statuses from tasks table
  Future<void> _loadArticleStatuses() async {
    if (currentUser?.id == null) return;

    try {
      // Get all tasks for user's articles
      final articleIds = userArticles.map((a) => a.id!).toList();

      if (articleIds.isEmpty) {
        print('⚠️ No articles to check statuses for');
        return;
      }

      final tasks = await Supabase.instance.client
          .from('tasks')
          .select('articleID, workflowStatus')
          .inFilter('articleID', articleIds);

      articleStatuses.clear();

      // Create a map of articleID -> workflowStatus from tasks
      final taskStatusMap = <int, String>{};
      for (var task in tasks) {
        final articleId = task['articleID'] as int?;
        final status = task['workflowStatus'] as String?;

        if (articleId != null && status != null) {
          taskStatusMap[articleId] = status;
        }
      }

      // Determine status for each article
      for (var article in userArticles) {
        if (article.id == null) continue;

        final articleId = article.id!;

        // Check if article has a task
        if (taskStatusMap.containsKey(articleId)) {
          final workflowStatus = taskStatusMap[articleId]!;

          // Map workflowStatus to our filter values
          if (workflowStatus == 'completado') {
            articleStatuses[articleId] = 'entregados';
          } else if (workflowStatus == 'en_proceso' ||
              workflowStatus == 'sin_asignar') {
            articleStatuses[articleId] = 'en_proceso';
          }
        } else {
          // No task found - check article phase
          // If phase is 'publicado' or no task exists, it's considered 'publicados'
          articleStatuses[articleId] = 'publicados';
        }
      }

      print('📊 Article statuses loaded: $articleStatuses');
    } catch (e) {
      print('❌ Error loading article statuses: $e');
      // Default to publicados if error
      for (var article in userArticles) {
        if (article.id != null) {
          articleStatuses[article.id!] = 'publicados';
        }
      }
    }
  }

  /// Calculate article statistics for Objetos card
  void _calculateStats() {
    int publicados = 0;
    int enProceso = 0;
    int entregados = 0;

    for (var article in userArticles) {
      if (article.id != null) {
        final status = articleStatuses[article.id] ?? 'publicados';
        switch (status) {
          case 'publicados':
            publicados++;
            break;
          case 'en_proceso':
            enProceso++;
            break;
          case 'entregados':
            entregados++;
            break;
        }
      }
    }

    articleStats = {
      'publicados': publicados,
      'enProceso': enProceso,
      'entregados': entregados,
    };

    print(
      '📊 Stats: $publicados publicados, $enProceso en proceso, $entregados entregados',
    );
  }

  /// Apply search and sort filters to articles
  void _applyFilters() {
    List<Article> filtered = List.from(userArticles);

    // Apply status filter if any selected
    if (selectedStatusFilters.isNotEmpty) {
      filtered =
          filtered.where((article) {
            if (article.id == null) return false;

            final status = articleStatuses[article.id] ?? 'publicados';
            return selectedStatusFilters.contains(status);
          }).toList();
    }

    // Apply search filter
    if (searchQuery.isNotEmpty) {
      filtered =
          filtered.where((article) {
            final name = article.name?.toLowerCase() ?? '';
            final condition = article.condition?.toLowerCase() ?? '';
            final query = searchQuery.toLowerCase();
            return name.contains(query) || condition.contains(query);
          }).toList();
    }

    // Sort by date (using ID as proxy for creation order)
    filtered.sort((a, b) {
      if (sortAscending) {
        return (a.id ?? 0).compareTo(b.id ?? 0); // Oldest first
      } else {
        return (b.id ?? 0).compareTo(a.id ?? 0); // Newest first
      }
    });

    setState(() {
      filteredArticles = filtered;
      // Reset pagination
      _currentArticlePage = 1;
      _hasMoreArticles = filtered.length > _articlesPerPage;
    });
  }

  /// Refresh all data
  Future<void> _refreshData() async {
    // ✅ Don't show loading spinner on refresh
    _currentArticlePage = 1;
    _hasMoreArticles = true;

    try {
      await _loadUserData();
    } catch (e) {
      print('❌ Error refreshing data: $e');
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

      print(
        '⭐ Distributor rating: ${avgRating.toStringAsFixed(1)} stars (${reviews.length} reviews)',
      );
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
          final article =
              await Supabase.instance.client
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

            tasksWithReviews.add({...task, 'reviews': reviews, 'photo': photo});
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
      builder:
          (context) => AlertDialog(
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
          final dateFormat = [
            'Lunes',
            'Martes',
            'Miércoles',
            'Jueves',
            'Viernes',
            'Sábado',
            'Domingo',
          ];

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
  void _showStatusFilterDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setModalState) => Container(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Filtrar por estado',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D8A8A),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildFilterChip(
                            'Publicados',
                            'publicados',
                            Colors.blue,
                            setModalState,
                          ),
                          _buildFilterChip(
                            'En Proceso',
                            'en_proceso',
                            Colors.orange,
                            setModalState,
                          ),
                          _buildFilterChip(
                            'Entregados',
                            'entregados',
                            Colors.green,
                            setModalState,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: () {
                              setState(() {
                                selectedStatusFilters.clear();
                              });
                              _applyFilters();
                              Navigator.pop(context);
                            },
                            child: const Text('Limpiar filtros'),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2D8A8A),
                            ),
                            child: const Text(
                              'Aplicar',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
          ),
    );
  }

  Widget _buildFilterChip(
    String label,
    String value,
    Color color,
    StateSetter setModalState,
  ) {
    final isSelected = selectedStatusFilters.contains(value);
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setModalState(() {
          if (selected) {
            selectedStatusFilters.add(value);
          } else {
            selectedStatusFilters.remove(value);
          }
        });
        setState(() {});
        _applyFilters();
      },
      selectedColor: color.withOpacity(0.3),
      checkmarkColor: color,
      labelStyle: TextStyle(
        color: isSelected ? color : Colors.grey[700],
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  void _showProfileMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => Container(
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
        body:
            isLoading
                ? const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                )
                : RefreshIndicator(
                  color: const Color(0xFF2D8A8A),
                  onRefresh: _refreshData,
                  child: CustomScrollView(
                    controller: _scrollController,
                    slivers: [
                      // Profile header as collapsible app bar
                      SliverAppBar(
                        expandedHeight: 155,
                        floating: false,
                        pinned: false,
                        backgroundColor: const Color(0xFF2D8A8A),
                        flexibleSpace: FlexibleSpaceBar(
                          background: Column(
                            children: [
                              // Profile header section
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.fromLTRB(
                                  25,
                                  20,
                                  25,
                                  10,
                                ),
                                child: Row(
                                  children: [
                                    // Avatar on the left
                                    CircleAvatar(
                                      radius: 50,
                                      backgroundColor: Colors.white,
                                      child:
                                          currentUserAvatar?.url != null
                                              ? ClipOval(
                                                child: CachedNetworkImage(
                                                  imageUrl:
                                                      currentUserAvatar!.url!,
                                                  width: 100,
                                                  height: 100,
                                                  fit: BoxFit.cover,
                                                  placeholder:
                                                      (
                                                        context,
                                                        url,
                                                      ) => const Center(
                                                        child:
                                                            CircularProgressIndicator(
                                                              color: Color(
                                                                0xFF2D8A8A,
                                                              ),
                                                              strokeWidth: 2,
                                                            ),
                                                      ),
                                                  errorWidget:
                                                      (context, url, error) =>
                                                          const Icon(
                                                            Icons.person,
                                                            size: 60,
                                                            color: Color(
                                                              0xFF2D8A8A,
                                                            ),
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
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // User name with edit icon
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  currentUser?.names ??
                                                      'Usuario',
                                                  style: const TextStyle(
                                                    fontSize: 24,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white,
                                                  ),
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              GestureDetector(
                                                onTap: _showProfileMenu,
                                                child: Container(
                                                  padding: const EdgeInsets.all(
                                                    6,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white
                                                        .withOpacity(0.2),
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
                                            currentUser?.role?.toUpperCase() ??
                                                'USUARIO',
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
                                                  distributorRating
                                                      .toStringAsFixed(1),
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
                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
                      ),
                      // Objetos card - inline between header and publications
                      SliverToBoxAdapter(
                        child: Transform.translate(
                          offset: const Offset(0, 55),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 25),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 15,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(15),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.15),
                                    blurRadius: 15,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Objetos',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF2D8A8A),
                                    ),
                                  ),
                                  const SizedBox(height: 15),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceAround,
                                    children: [
                                      _buildObjectStatItem(
                                        '${articleStats['publicados']}',
                                        'Publicados',
                                        Colors.blue,
                                      ),
                                      _buildObjectStatItem(
                                        '${articleStats['enProceso']}',
                                        'En Procesos',
                                        Colors.orange,
                                      ),
                                      _buildObjectStatItem(
                                        '${articleStats['entregados']}',
                                        'Entregados',
                                        Colors.green,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      // White publications section with rounded top
                      SliverToBoxAdapter(
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
                              const SizedBox(height: 80),
                              const Padding(
                                padding: EdgeInsets.fromLTRB(25, 0, 25, 10),
                                child: Center(
                                  child: Text(
                                    'Publicaciones',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF2D8A8A),
                                    ),
                                  ),
                                ),
                              ),
                              // Search bar
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 25,
                                ),
                                child: TextField(
                                  onChanged: (value) {
                                    setState(() {
                                      searchQuery = value;
                                    });
                                    _applyFilters();
                                  },
                                  decoration: InputDecoration(
                                    hintText: 'Buscar',
                                    prefixIcon: const Icon(
                                      Icons.search,
                                      color: Colors.grey,
                                    ),
                                    filled: true,
                                    fillColor: Colors.grey[100],
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              // Articles count and controls
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 25,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Total ${filteredArticles.length} ${filteredArticles.length == 1 ? 'publicación' : 'publicaciones'}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        // Sort button
                                        IconButton(
                                          icon: Icon(
                                            sortAscending
                                                ? Icons.arrow_upward
                                                : Icons.arrow_downward,
                                            color: const Color(0xFF2D8A8A),
                                            size: 20,
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              sortAscending = !sortAscending;
                                            });
                                            _applyFilters();
                                          },
                                          tooltip:
                                              sortAscending
                                                  ? 'Más antiguos primero'
                                                  : 'Más recientes primero',
                                        ),
                                        // Filter button
                                        IconButton(
                                          icon: Icon(
                                            Icons.filter_list,
                                            color:
                                                selectedStatusFilters.isEmpty
                                                    ? Colors.grey[600]
                                                    : const Color(0xFF2D8A8A),
                                            size: 20,
                                          ),
                                          onPressed: _showStatusFilterDialog,
                                          tooltip: 'Filtrar por estado',
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 15),
                            ],
                          ),
                        ),
                      ),
                      // Grid of articles
                      _buildPublishedArticlesSliverGrid(),
                    ],
                  ),
                ),
      ),
    );
  }

  Widget _buildObjectStatItem(String value, String label, Color color) {
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
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  // Build published articles as sliver grid
  Widget _buildPublishedArticlesSliverGrid() {
    if (filteredArticles.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.inventory_2_outlined,
                size: 60,
                color: Colors.grey[300],
              ),
              const SizedBox(height: 12),
              Text(
                'No hay artículos publicados',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(15, 10, 15, 15),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.85,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final totalToShow = _currentArticlePage * _articlesPerPage;
            final paginatedArticles =
                filteredArticles.take(totalToShow).toList();

            // Show loading indicator at the end
            if (index == paginatedArticles.length) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(color: Color(0xFF2D8A8A)),
                ),
              );
            }

            final article = paginatedArticles[index];
            return GestureDetector(
              onTap: () => _navigateToDetail(article),
              child: _buildArticleCard(article),
            );
          },
          childCount: () {
            final totalToShow = _currentArticlePage * _articlesPerPage;
            final paginatedArticles =
                filteredArticles.take(totalToShow).toList();
            final hasMore = filteredArticles.length > paginatedArticles.length;
            return paginatedArticles.length + (hasMore ? 1 : 0);
          }(),
        ),
      ),
    );
  }

  Widget _buildArticleCard(Article article) {
    // Get status from articleStatuses map
    final status = articleStatuses[article.id] ?? 'publicados';

    Color statusColor;
    String statusText;

    switch (status) {
      case 'publicados':
        statusColor = Colors.blue;
        statusText = 'Publicado';
        break;
      case 'en_proceso':
        statusColor = Colors.orange;
        statusText = 'En Proceso';
        break;
      case 'entregados':
        statusColor = Colors.green;
        statusText = 'Completado';
        break;
      default:
        statusColor = Colors.grey;
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
                placeholder:
                    (context, url) => Container(
                      color: Colors.grey[300],
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF2D8A8A),
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                errorWidget:
                    (context, url, error) => Container(
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
                colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
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
                    shadows: [Shadow(color: Colors.black, blurRadius: 2)],
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
                      shadows: [Shadow(color: Colors.black, blurRadius: 2)],
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
